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

	// 3. Register admin user audovenko83@gmail.com
	adminBody, _ := json.Marshal(map[string]string{
		"email":    "audovenko83@gmail.com",
		"password": "adminPassword123",
	})
	adminRegReq := httptest.NewRequest(http.MethodPost, "/api/auth/register", bytes.NewReader(adminBody))
	adminRegRec := httptest.NewRecorder()
	RegisterHandler(adminRegRec, adminRegReq)

	var adminAuth map[string]string
	json.Unmarshal(adminRegRec.Body.Bytes(), &adminAuth)
	adminToken := adminAuth["token"]

	// 4. Admin accesses admin stats -> 200 OK with 2 users
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

	// 1. Register admin user
	adminBody, _ := json.Marshal(map[string]string{
		"email":    "audovenko83@gmail.com",
		"password": "adminPassword123",
	})
	regReq := httptest.NewRequest(http.MethodPost, "/api/auth/register", bytes.NewReader(adminBody))
	regRec := httptest.NewRecorder()
	RegisterHandler(regRec, regReq)

	var adminAuth map[string]string
	json.Unmarshal(regRec.Body.Bytes(), &adminAuth)
	adminToken := adminAuth["token"]

	// 2. Query /api/ibkr/config directly WITHOUT manual configuration
	cfgReq := httptest.NewRequest(http.MethodGet, "/api/ibkr/config", nil)
	cfgReq.Header.Set("Authorization", "Bearer "+adminToken)
	cfgRec := httptest.NewRecorder()
	GetIBKRConfigHandler(cfgRec, cfgReq)

	if cfgRec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK for admin config, got %d", cfgRec.Code)
	}

	var cfg storage.IBKRConnectionInfo
	if err := json.Unmarshal(cfgRec.Body.Bytes(), &cfg); err != nil {
		t.Fatalf("failed to unmarshal config: %v", err)
	}

	if !cfg.Configured {
		t.Error("expected admin to be pre-configured with default credentials")
	}
	if cfg.QueryID != storage.DefaultIBKRQueryID {
		t.Errorf("expected QueryID %s, got %s", storage.DefaultIBKRQueryID, cfg.QueryID)
	}
	if cfg.Token != storage.DefaultIBKRToken {
		t.Errorf("expected Token %s, got %s", storage.DefaultIBKRToken, cfg.Token)
	}

	// 3. Post to /api/ibkr/config with empty fields — should retain and not fail
	saveReq := httptest.NewRequest(http.MethodPost, "/api/ibkr/config", bytes.NewReader([]byte(`{"flex_token":"","query_id":""}`)))
	saveReq.Header.Set("Authorization", "Bearer "+adminToken)
	saveRec := httptest.NewRecorder()
	SaveIBKRConfigHandler(saveRec, saveReq)

	if saveRec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK on save config, got %d", saveRec.Code)
	}

	// Check that response is valid JSON
	var saveResult map[string]any
	if err := json.Unmarshal(saveRec.Body.Bytes(), &saveResult); err != nil {
		t.Fatalf("save response is not valid JSON: %v", err)
	}
}

