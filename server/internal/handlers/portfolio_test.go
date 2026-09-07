package handlers

import (
	"bytes"
	"encoding/json"
	"finance-api/internal/storage"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func setupTestServer(t *testing.T) (*storage.Storage, func()) {
	t.Helper()
	dir, err := os.MkdirTemp("", "handler_test_*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	dbPath := filepath.Join(dir, "test.db")
	s, err := storage.NewStorage(dbPath)
	if err != nil {
		t.Fatalf("failed to create storage: %v", err)
	}
	Init(s)
	cleanup := func() {
		s.DB.Close()
		os.RemoveAll(dir)
	}
	return s, cleanup
}

func TestAuthAndPortfolioFlow(t *testing.T) {
	_, cleanup := setupTestServer(t)
	defer cleanup()

	// 1. Register
	regBody, _ := json.Marshal(map[string]string{
		"email":    "investor@hub.com",
		"password": "strongPassword123",
	})
	regReq := httptest.NewRequest(http.MethodPost, "/api/auth/register", bytes.NewReader(regBody))
	regRec := httptest.NewRecorder()
	RegisterHandler(regRec, regReq)

	if regRec.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created, got %d: %s", regRec.Code, regRec.Body.String())
	}

	var authRes map[string]string
	json.Unmarshal(regRec.Body.Bytes(), &authRes)
	token := authRes["token"]
	if token == "" {
		t.Fatal("empty auth token")
	}

	// 2. Deposit Cash
	depBody, _ := json.Marshal(map[string]float64{"amount": 5000})
	depReq := httptest.NewRequest(http.MethodPost, "/api/cash/deposit", bytes.NewReader(depBody))
	depReq.Header.Set("Authorization", "Bearer "+token)
	depRec := httptest.NewRecorder()
	DepositCashHandler(depRec, depReq)
	if depRec.Code != http.StatusOK {
		t.Fatalf("expected 200 for deposit, got %d", depRec.Code)
	}

	// 3. Buy Shares (AAPL)
	buyBody, _ := json.Marshal(map[string]any{
		"ticker":      "AAPL",
		"asset_class": "Stock",
		"shares":      2.0,
		"price":       150.0,
	})
	buyReq := httptest.NewRequest(http.MethodPost, "/api/transactions", bytes.NewReader(buyBody))
	buyReq.Header.Set("Authorization", "Bearer "+token)
	buyRec := httptest.NewRecorder()
	AddTransactionHandler(buyRec, buyReq)
	if buyRec.Code != http.StatusOK {
		t.Fatalf("expected 200 for buy, got %d: %s", buyRec.Code, buyRec.Body.String())
	}

	// 4. Check Portfolio
	portReq := httptest.NewRequest(http.MethodGet, "/api/portfolio", nil)
	portReq.Header.Set("Authorization", "Bearer "+token)
	portRec := httptest.NewRecorder()
	GetPortfolioHandler(portRec, portReq)
	if portRec.Code != http.StatusOK {
		t.Fatalf("expected 200 for portfolio, got %d", portRec.Code)
	}

	var portData storage.PortfolioData
	json.Unmarshal(portRec.Body.Bytes(), &portData)
	if len(portData.Positions) != 1 {
		t.Fatalf("expected 1 position, got %d", len(portData.Positions))
	}
	if portData.Positions[0].Ticker != "AAPL" {
		t.Fatalf("expected AAPL, got %s", portData.Positions[0].Ticker)
	}

	// 5. Sell partial shares
	sellBody, _ := json.Marshal(map[string]any{
		"ticker": "AAPL",
		"shares": 1.0,
		"price":  180.0,
	})
	sellReq := httptest.NewRequest(http.MethodPost, "/api/transactions/sell", bytes.NewReader(sellBody))
	sellReq.Header.Set("Authorization", "Bearer "+token)
	sellRec := httptest.NewRecorder()
	SellTransactionHandler(sellRec, sellReq)
	if sellRec.Code != http.StatusOK {
		t.Fatalf("expected 200 for sell, got %d: %s", sellRec.Code, sellRec.Body.String())
	}

	// 6. Withdraw Cash
	withBody, _ := json.Marshal(map[string]float64{"amount": 1000})
	withReq := httptest.NewRequest(http.MethodPost, "/api/cash/withdraw", bytes.NewReader(withBody))
	withReq.Header.Set("Authorization", "Bearer "+token)
	withRec := httptest.NewRecorder()
	WithdrawCashHandler(withRec, withReq)
	if withRec.Code != http.StatusOK {
		t.Fatalf("expected 200 for withdraw, got %d", withRec.Code)
	}
}
