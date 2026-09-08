package storage

import (
	"finance-api/internal/services"
	"os"
	"path/filepath"
	"testing"
)

func setupTestDB(t *testing.T) (*Storage, func()) {
	t.Helper()
	dir, err := os.MkdirTemp("", "testdb_*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	dbPath := filepath.Join(dir, "test.db")
	s, err := NewStorage(dbPath)
	if err != nil {
		t.Fatalf("failed to initialize db: %v", err)
	}
	cleanup := func() {
		s.DB.Close()
		os.RemoveAll(dir)
	}
	return s, cleanup
}

func TestCompositePrimaryKeyPositions(t *testing.T) {
	s, cleanup := setupTestDB(t)
	defer cleanup()

	u1, err := s.CreateUser("user1@example.com", "password123")
	if err != nil {
		t.Fatalf("failed to create user 1: %v", err)
	}
	u2, err := s.CreateUser("user2@example.com", "password123")
	if err != nil {
		t.Fatalf("failed to create user 2: %v", err)
	}

	// User 1 buys 10 AAPL @ 150
	if err := s.AddTransaction(u1.ID, "AAPL", "Stock", 10, 150); err != nil {
		t.Fatalf("user 1 buy failed: %v", err)
	}
	// User 2 buys 5 AAPL @ 200 (must succeed without primary key conflict!)
	if err := s.AddTransaction(u2.ID, "AAPL", "Stock", 5, 200); err != nil {
		t.Fatalf("user 2 buy failed: %v", err)
	}

	p1, err := s.GetPortfolio(u1.ID)
	if err != nil {
		t.Fatalf("get portfolio 1 failed: %v", err)
	}
	if len(p1.Positions) != 1 || p1.Positions[0].Shares != 10 {
		t.Fatalf("user 1 unexpected positions: %+v", p1.Positions)
	}

	p2, err := s.GetPortfolio(u2.ID)
	if err != nil {
		t.Fatalf("get portfolio 2 failed: %v", err)
	}
	if len(p2.Positions) != 1 || p2.Positions[0].Shares != 5 {
		t.Fatalf("user 2 unexpected positions: %+v", p2.Positions)
	}
}

func TestCashDepositAndWithdraw(t *testing.T) {
	s, cleanup := setupTestDB(t)
	defer cleanup()

	u, err := s.CreateUser("cash@example.com", "password123")
	if err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	if err := s.DepositCash(u.ID, 500); err != nil {
		t.Fatalf("deposit failed: %v", err)
	}
	p, err := s.GetPortfolio(u.ID)
	if err != nil {
		t.Fatalf("get portfolio failed: %v", err)
	}
	if p.Cash != 10500 {
		t.Fatalf("expected 10500 cash, got %f", p.Cash)
	}

	if err := s.WithdrawCash(u.ID, 2000); err != nil {
		t.Fatalf("withdraw failed: %v", err)
	}
	p, _ = s.GetPortfolio(u.ID)
	if p.Cash != 8500 {
		t.Fatalf("expected 8500 cash, got %f", p.Cash)
	}

	// Withdraw more than balance must fail
	if err := s.WithdrawCash(u.ID, 999999); err == nil {
		t.Fatal("expected error withdrawing more than cash balance")
	}
}

func TestBuyAndSellTransaction(t *testing.T) {
	s, cleanup := setupTestDB(t)
	defer cleanup()

	u, err := s.CreateUser("trader@example.com", "password123")
	if err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	// Reject <= 0 values
	if err := s.AddTransaction(u.ID, "VOO", "ETF", -1, 100); err == nil {
		t.Fatal("expected error on negative shares")
	}
	if err := s.AddTransaction(u.ID, "VOO", "ETF", 1, -100); err == nil {
		t.Fatal("expected error on negative price")
	}

	// Buy 2 VOO @ 400 = 800
	if err := s.AddTransaction(u.ID, "VOO", "ETF", 2, 400); err != nil {
		t.Fatalf("buy 1 failed: %v", err)
	}
	// Buy 2 VOO @ 500 = 1000, new avg price = (800+1000)/4 = 450
	if err := s.AddTransaction(u.ID, "VOO", "ETF", 2, 500); err != nil {
		t.Fatalf("buy 2 failed: %v", err)
	}

	p, err := s.GetPortfolio(u.ID)
	if err != nil {
		t.Fatalf("get portfolio failed: %v", err)
	}
	if len(p.Positions) != 1 {
		t.Fatalf("expected 1 position, got %d", len(p.Positions))
	}
	pos := p.Positions[0]
	if pos.Shares != 4 {
		t.Fatalf("expected 4 shares, got %f", pos.Shares)
	}
	if pos.AverageBuyPrice != 450 {
		t.Fatalf("expected avg price 450, got %f", pos.AverageBuyPrice)
	}

	// Sell 1 VOO @ 550
	if err := s.SellTransaction(u.ID, "VOO", 1, 550); err != nil {
		t.Fatalf("sell failed: %v", err)
	}

	p, _ = s.GetPortfolio(u.ID)
	pos = p.Positions[0]
	if pos.Shares != 3 {
		t.Fatalf("expected 3 shares, got %f", pos.Shares)
	}

	// Sell remaining 3
	if err := s.SellTransaction(u.ID, "VOO", 3, 550); err != nil {
		t.Fatalf("sell all failed: %v", err)
	}
	p, _ = s.GetPortfolio(u.ID)
	if len(p.Positions) != 0 {
		t.Fatalf("expected 0 positions after selling all, got %d", len(p.Positions))
	}

	// Selling non-existent stock must fail
	if err := s.SellTransaction(u.ID, "VOO", 1, 550); err == nil {
		t.Fatal("expected error selling non-existent position")
	}
}

func TestEmptyIBKRSnapshotProtection(t *testing.T) {
	s, cleanup := setupTestDB(t)
	defer cleanup()

	u, err := s.CreateUser("snapshot_user@example.com", "password123")
	if err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	// 1. First sync has positions
	initialPositions := []services.IBKRPosition{
		{Ticker: "AAPL", CompanyName: "Apple", AssetClass: "Stock", Shares: 10, AverageBuyPrice: 150, CurrentPrice: 160, TotalValue: 1600, Currency: "USD"},
	}
	if err := s.SaveIBKRSyncSuccess(u.ID, "U12345", 5000, initialPositions); err != nil {
		t.Fatalf("initial sync failed: %v", err)
	}

	// Verify position exists in DB
	var count int
	s.DB.QueryRow("SELECT COUNT(*) FROM ibkr_positions WHERE user_id = ?", u.ID).Scan(&count)
	if count != 1 {
		t.Fatalf("expected 1 position, got %d", count)
	}

	// 2. An empty report comes in (malformed or IBKR glitch) -> MUST be rejected to protect data!
	err = s.SaveIBKRSyncSuccess(u.ID, "U12345", 5000, []services.IBKRPosition{})
	if err == nil {
		t.Fatal("expected error on empty IBKR snapshot when user has existing positions")
	}

	// Verify position is STILL in DB, was NOT wiped out!
	s.DB.QueryRow("SELECT COUNT(*) FROM ibkr_positions WHERE user_id = ?", u.ID).Scan(&count)
	if count != 1 {
		t.Fatalf("expected 1 position retained after empty snapshot attempt, got %d", count)
	}
}

func TestInvestPlanRejectsZeroPrice(t *testing.T) {
	s, cleanup := setupTestDB(t)
	defer cleanup()

	u, err := s.CreateUser("plan_user@example.com", "password123")
	if err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	// Invest plan with 0 price -> must fail without falling back to $100!
	_, _, err = s.InvestPlan(u.ID, 50, []StockPlanItem{
		{Ticker: "AAPL", Price: 0, Name: "Apple", AssetClass: "Stock"},
	})
	if err == nil {
		t.Fatal("expected error for invest plan item with 0 price")
	}
}

