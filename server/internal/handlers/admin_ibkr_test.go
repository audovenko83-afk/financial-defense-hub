package handlers

import (
	"bytes"
	"encoding/json"
	"finance-api/internal/storage"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestAdminAndIBKRFlow(t *testing.T) {
	_, cleanup := setupTestServer(t)
	defer cleanup()

	// 1. Register normal user
	normalBody, _ := json.Marshal(map[string]string{
		"email":    "user@example.com",
		"password": "password123",
	})
	regReq := httptest.NewRequest(http.MethodPost, "/api/auth/register", bytes.NewReader(normalBody))
	regRec := httptest.NewRecorder()
	RegisterHandler(regRec, regReq)

	var normalAuth map[string]string
	json.Unmarshal(regRec.Body.Bytes(), &normalAuth)
	normalToken := normalAuth["token"]

	// 2. Normal user tries to access admin endpoint -> 403 Forbidden
	adminReq := httptest.NewRequest(http.MethodGet, "/api/admin/users", nil)
	adminReq.Header.Set("Authorization", "Bearer "+normalToken)
	adminRec := httptest.NewRecorder()
	AdminStatsHandler(adminRec, adminReq)

	if adminRec.Code != http.StatusForbidden {
		t.Fatalf("expected 403 Forbidden for non-admin, got %d", adminRec.Code)
	}

	// 3. Register another user (even with audovenko83@gmail.com)
	adminBody, _ := json.Marshal(map[string]string{
		"email":    "audovenko83@gmail.com",
		"password": "adminPassword123",
	})
	adminRegReq := httptest.NewRequest(http.MethodPost, "/api/auth/register", bytes.NewReader(adminBody))
	adminRegRec := httptest.NewRecorder()
	RegisterHandler(adminRegRec, adminRegReq)

	var adminAuth map[string]any
	json.Unmarshal(adminRegRec.Body.Bytes(), &adminAuth)
	adminToken := adminAuth["token"].(string)

	// User should NOT have admin rights just because of their email!
	adminReqBeforePromote := httptest.NewRequest(http.MethodGet, "/api/admin/users", nil)
	adminReqBeforePromote.Header.Set("Authorization", "Bearer "+adminToken)
	adminRecBeforePromote := httptest.NewRecorder()
	AdminStatsHandler(adminRecBeforePromote, adminReqBeforePromote)
	if adminRecBeforePromote.Code != http.StatusForbidden {
		t.Fatalf("expected 403 Forbidden before DB promotion, got %d", adminRecBeforePromote.Code)
	}

	// 4. Promote user to admin in the database
	adminUserID, err := store.UserIDForSession(adminToken)
	if err != nil {
		t.Fatalf("failed to get user ID: %v", err)
	}
	if err := store.SetUserRole(adminUserID, "admin"); err != nil {
		t.Fatalf("failed to set user role: %v", err)
	}

	// 5. Admin accesses admin stats -> 200 OK with 2 users
	adminReq2 := httptest.NewRequest(http.MethodGet, "/api/admin/users", nil)
	adminReq2.Header.Set("Authorization", "Bearer "+adminToken)
	adminRec2 := httptest.NewRecorder()
	AdminStatsHandler(adminRec2, adminReq2)

	if adminRec2.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for admin, got %d: %s", adminRec2.Code, adminRec2.Body.String())
	}

	var stats storage.AdminStatsResponse
	if err := json.Unmarshal(adminRec2.Body.Bytes(), &stats); err != nil {
		t.Fatalf("failed to unmarshal admin stats: %v", err)
	}
	if stats.TotalUsers != 2 {
		t.Errorf("expected 2 users, got %d", stats.TotalUsers)
	}
	if len(stats.Users) != 2 {
		t.Errorf("expected 2 users in list, got %d", len(stats.Users))
	}

	// 5. Test Portfolio Mode switcher (demo -> real -> demo)
	modeReq := httptest.NewRequest(http.MethodGet, "/api/portfolio/mode", nil)
	modeReq.Header.Set("Authorization", "Bearer "+normalToken)
	modeRec := httptest.NewRecorder()
	PortfolioModeHandler(modeRec, modeReq)
	if modeRec.Code != http.StatusOK {
		t.Fatalf("expected 200 for get mode, got %d", modeRec.Code)
	}
	var modeRes map[string]string
	json.Unmarshal(modeRec.Body.Bytes(), &modeRes)
	if modeRes["mode"] != "demo" {
		t.Errorf("default mode should be demo, got %s", modeRes["mode"])
	}

	// Switch to real
	setModeBody, _ := json.Marshal(map[string]string{"mode": "real"})
	setModeReq := httptest.NewRequest(http.MethodPost, "/api/portfolio/mode", bytes.NewReader(setModeBody))
	setModeReq.Header.Set("Authorization", "Bearer "+normalToken)
	setModeRec := httptest.NewRecorder()
	PortfolioModeHandler(setModeRec, setModeReq)
	if setModeRec.Code != http.StatusOK {
		t.Fatalf("expected 200 for set mode, got %d", setModeRec.Code)
	}

	// 6. Test IBKR Config & Sync using DEMO_IBKR token
	saveIbkrBody, _ := json.Marshal(map[string]string{
		"flex_token": "DEMO_IBKR",
		"query_id":   "DEMO",
	})
	saveIbkrReq := httptest.NewRequest(http.MethodPost, "/api/ibkr/config", bytes.NewReader(saveIbkrBody))
	saveIbkrReq.Header.Set("Authorization", "Bearer "+normalToken)
	saveIbkrRec := httptest.NewRecorder()
	SaveIBKRConfigHandler(saveIbkrRec, saveIbkrReq)
	if saveIbkrRec.Code != http.StatusOK {
		t.Fatalf("expected 200 for save ibkr config, got %d: %s", saveIbkrRec.Code, saveIbkrRec.Body.String())
	}

	// 7. Get Portfolio in Real mode -> should have positions from IBKR sync
	portReq := httptest.NewRequest(http.MethodGet, "/api/portfolio", nil)
	portReq.Header.Set("Authorization", "Bearer "+normalToken)
	portRec := httptest.NewRecorder()
	GetPortfolioHandler(portRec, portReq)
	if portRec.Code != http.StatusOK {
		t.Fatalf("expected 200 for real portfolio, got %d", portRec.Code)
	}
	var portData storage.PortfolioData
	json.Unmarshal(portRec.Body.Bytes(), &portData)
	if portData.Mode != "real" {
		t.Errorf("expected mode real, got %s", portData.Mode)
	}
	if !portData.IBKRConfigured {
		t.Error("expected IBKRConfigured to be true")
	}
	if len(portData.Positions) == 0 {
		t.Error("expected synced IBKR positions, got 0")
	}
	if portData.Cash <= 0 {
		t.Errorf("expected positive cash, got %f", portData.Cash)
	}

	// 8. Admin accesses Audit Logs -> 200 OK with logged events
	logsReq := httptest.NewRequest(http.MethodGet, "/api/admin/audit-logs", nil)
	logsReq.Header.Set("Authorization", "Bearer "+adminToken)
	logsRec := httptest.NewRecorder()
	AdminAuditLogsHandler(logsRec, logsReq)
	if logsRec.Code != http.StatusOK {
		t.Fatalf("expected 200 for audit logs, got %d: %s", logsRec.Code, logsRec.Body.String())
	}
	var logsResp map[string][]storage.AuditLog
	if err := json.Unmarshal(logsRec.Body.Bytes(), &logsResp); err != nil {
		t.Fatalf("failed to unmarshal logs: %v", err)
	}
	logs := logsResp["logs"]
	if len(logs) == 0 {
		t.Fatal("expected at least 1 audit log, got 0")
	}
	hasModeSwitch := false
	hasIBKRConfig := false
	for _, l := range logs {
		if l.EventType == "MODE_SWITCH" {
			hasModeSwitch = true
		}
		if l.EventType == "IBKR_CONFIG_SAVE" {
			hasIBKRConfig = true
			if l.Status != "SUCCESS" {
				t.Errorf("expected IBKR_CONFIG_SAVE status SUCCESS, got %s", l.Status)
			}
			if l.TokenMasked == "" {
				t.Error("expected masked token in audit log")
			}
		}
	}
	if !hasModeSwitch {
		t.Error("expected audit log for MODE_SWITCH")
	}
	if !hasIBKRConfig {
		t.Error("expected audit log for IBKR_CONFIG_SAVE")
	}

}

func TestSavedTokenAndIDPersistence(t *testing.T) {
	_, cleanup := setupTestServer(t)
	defer cleanup()

	// 1. Register user
	userBody, _ := json.Marshal(map[string]string{
		"email":    "user_ibkr@example.com",
		"password": "userPassword123",
	})
	regReq := httptest.NewRequest(http.MethodPost, "/api/auth/register", bytes.NewReader(userBody))
	regRec := httptest.NewRecorder()
	RegisterHandler(regRec, regReq)

	var userAuth map[string]any
	json.Unmarshal(regRec.Body.Bytes(), &userAuth)
	userToken := userAuth["token"].(string)

	// 2. Query /api/ibkr/config directly WITHOUT manual configuration -> must be unconfigured!
	cfgReq := httptest.NewRequest(http.MethodGet, "/api/ibkr/config", nil)
	cfgReq.Header.Set("Authorization", "Bearer "+userToken)
	cfgRec := httptest.NewRecorder()
	GetIBKRConfigHandler(cfgRec, cfgReq)

	if cfgRec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for config, got %d", cfgRec.Code)
	}

	var cfg storage.IBKRConnectionInfo
	if err := json.Unmarshal(cfgRec.Body.Bytes(), &cfg); err != nil {
		t.Fatalf("failed to unmarshal config: %v", err)
	}

	if cfg.Configured {
		t.Error("expected new user to NOT have IBKR configured by default")
	}

	// 3. Post with empty fields -> should be rejected with 400 Bad Request
	emptySaveReq := httptest.NewRequest(http.MethodPost, "/api/ibkr/config", bytes.NewReader([]byte(`{"flex_token":"","query_id":""}`)))
	emptySaveReq.Header.Set("Authorization", "Bearer "+userToken)
	emptySaveRec := httptest.NewRecorder()
	SaveIBKRConfigHandler(emptySaveRec, emptySaveReq)
	if emptySaveRec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 Bad Request for empty credentials, got %d", emptySaveRec.Code)
	}

	// 4. Post valid credentials -> saves and masks token
	saveReq := httptest.NewRequest(http.MethodPost, "/api/ibkr/config", bytes.NewReader([]byte(`{"flex_token":"DEMO_IBKR","query_id":"DEMO"}`)))
	saveReq.Header.Set("Authorization", "Bearer "+userToken)
	saveRec := httptest.NewRecorder()
	SaveIBKRConfigHandler(saveRec, saveReq)
	if saveRec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK on save config, got %d: %s", saveRec.Code, saveRec.Body.String())
	}

	// 5. Verify that GET /api/ibkr/config does NOT return plaintext token
	cfgReq2 := httptest.NewRequest(http.MethodGet, "/api/ibkr/config", nil)
	cfgReq2.Header.Set("Authorization", "Bearer "+userToken)
	cfgRec2 := httptest.NewRecorder()
	GetIBKRConfigHandler(cfgRec2, cfgReq2)

	var rawJson map[string]any
	json.Unmarshal(cfgRec2.Body.Bytes(), &rawJson)
	if _, exists := rawJson["token"]; exists {
		t.Errorf("SECURITY LEAK: plaintext token should NEVER be exposed in API: %v", rawJson["token"])
	}
	if rawJson["token_masked"] == "" {
		t.Error("expected token_masked to be populated")
	}
}

func TestOAuthAndSecurityFlows(t *testing.T) {
	_, cleanup := setupTestServer(t)
	defer cleanup()

	// 1. Google OAuth with test token
	googleBody, _ := json.Marshal(map[string]string{
		"email": "google_user@gmail.com",
		"token": "test-google-token",
	})
	gReq := httptest.NewRequest(http.MethodPost, "/api/auth/google", bytes.NewReader(googleBody))
	gRec := httptest.NewRecorder()
	GoogleAuthHandler(gRec, gReq)
	if gRec.Code != http.StatusOK {
		t.Fatalf("expected 200 for Google test auth, got %d: %s", gRec.Code, gRec.Body.String())
	}

	// 2. Google OAuth with missing token should fail with 401
	gEmptyReq := httptest.NewRequest(http.MethodPost, "/api/auth/google", bytes.NewReader([]byte(`{"email":"fake@gmail.com","token":""}`)))
	gEmptyRec := httptest.NewRecorder()
	GoogleAuthHandler(gEmptyRec, gEmptyReq)
	if gEmptyRec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 Unauthorized for empty Google token, got %d", gEmptyRec.Code)
	}

	// 3. GitHub OAuth with test token
	ghBody, _ := json.Marshal(map[string]string{
		"email": "gh_user@example.com",
		"token": "test-github-token",
	})
	ghReq := httptest.NewRequest(http.MethodPost, "/api/auth/github", bytes.NewReader(ghBody))
	ghRec := httptest.NewRecorder()
	GitHubAuthHandler(ghRec, ghReq)
	if ghRec.Code != http.StatusOK {
		t.Fatalf("expected 200 for GitHub test auth, got %d: %s", ghRec.Code, ghRec.Body.String())
	}

	// 4. Password Reset
	resetBody, _ := json.Marshal(map[string]string{
		"email":        "google_user@gmail.com",
		"new_password": "NewSecretPassword2026!",
	})
	rReq := httptest.NewRequest(http.MethodPost, "/api/auth/reset-password", bytes.NewReader(resetBody))
	rRec := httptest.NewRecorder()
	ResetPasswordHandler(rRec, rReq)
	if rRec.Code != http.StatusOK {
		t.Fatalf("expected 200 for password reset, got %d: %s", rRec.Code, rRec.Body.String())
	}

	// Now can login with new password
	loginBody, _ := json.Marshal(map[string]string{
		"email":    "google_user@gmail.com",
		"password": "NewSecretPassword2026!",
	})
	lReq := httptest.NewRequest(http.MethodPost, "/api/auth/login", bytes.NewReader(loginBody))
	lRec := httptest.NewRecorder()
	LoginHandler(lRec, lReq)
	if lRec.Code != http.StatusOK {
		t.Fatalf("expected 200 for login with reset password, got %d", lRec.Code)
	}
}
