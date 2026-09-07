package storage

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"finance-api/internal/services"
	"fmt"
	"log"
	"math"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
	_ "modernc.org/sqlite"
)

const LegacyUserID = "legacy"

type Storage struct {
	DB *sql.DB
}

type User struct {
	ID           string
	Email        string
	PasswordHash string
}

type Position struct {
	Ticker               string  `json:"ticker"`
	CompanyName          string  `json:"company_name"`
	AssetClass           string  `json:"asset_class"`
	Shares               float64 `json:"shares"`
	AverageBuyPrice      float64 `json:"average_buy_price"`
	CurrentPrice         float64 `json:"current_price"`
	TotalValue           float64 `json:"total_value"`
	UnrealizedPnL        float64 `json:"unrealized_pnl"`
	UnrealizedPnLPercent float64 `json:"unrealized_pnl_percent"`
	DayChangePercent     float64 `json:"day_change_percent"`
	Currency             string  `json:"currency"`
}

type Transaction struct {
	ID          int     `json:"id"`
	Type        string  `json:"type"`
	Ticker      string  `json:"ticker"`
	AssetClass  string  `json:"asset_class"`
	Shares      float64 `json:"shares"`
	Price       float64 `json:"price"`
	TotalAmount float64 `json:"total_amount"`
	CreatedAt   string  `json:"created_at"`
}

type Dividend struct {
	ID       int     `json:"id"`
	Ticker   string  `json:"ticker"`
	Amount   float64 `json:"amount"`
	Currency string  `json:"currency"`
	PaidAt   string  `json:"paid_at"`
}

type PortfolioData struct {
	TotalValue      float64    `json:"total_value"`
	Cash            float64    `json:"cash"`
	InvestedValue   float64    `json:"invested_value"`
	TotalDividends  float64    `json:"total_dividends"`
	TotalPnL        float64    `json:"total_pnl"`
	TotalPnLPercent float64    `json:"total_pnl_percent"`
	Positions       []Position `json:"positions"`
	Dividends       []Dividend `json:"dividends"`
}

func round2(v float64) float64 {
	return math.Round(v*100) / 100
}

func round6(v float64) float64 {
	return math.Round(v*1000000) / 1000000
}

func cashKey(userID string) string {
	if userID == LegacyUserID {
		return "cash"
	}
	return "cash:" + userID
}

func addColumnIfMissing(db *sql.DB, table string, column string, definition string) error {
	rows, err := db.Query("PRAGMA table_info(" + table + ")")
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var cid int
		var name, colType string
		var notNull, pk int
		var dflt any
		if err := rows.Scan(&cid, &name, &colType, &notNull, &dflt, &pk); err != nil {
			return err
		}
		if name == column {
			return nil
		}
	}
	_, err = db.Exec("ALTER TABLE " + table + " ADD COLUMN " + column + " " + definition)
	return err
}

func NewStorage(dbPath string) (*Storage, error) {
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, err
	}

	createBaseTables := `
	CREATE TABLE IF NOT EXISTS portfolio_meta (key TEXT PRIMARY KEY, value REAL);
	CREATE TABLE IF NOT EXISTS transactions (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id TEXT,
		type TEXT DEFAULT 'BUY',
		ticker TEXT,
		asset_class TEXT,
		shares REAL,
		price REAL,
		total_amount REAL DEFAULT 0,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);
	CREATE TABLE IF NOT EXISTS dividends (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id TEXT,
		ticker TEXT NOT NULL,
		amount REAL NOT NULL,
		currency TEXT NOT NULL DEFAULT 'USD',
		paid_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);
	CREATE TABLE IF NOT EXISTS users (
		id TEXT PRIMARY KEY,
		email TEXT UNIQUE NOT NULL,
		password_hash TEXT NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);
	CREATE TABLE IF NOT EXISTS sessions (
		token TEXT PRIMARY KEY,
		user_id TEXT NOT NULL,
		expires_at DATETIME NOT NULL
	);
	`
	if _, err := db.Exec(createBaseTables); err != nil {
		return nil, err
	}

	var posTableSql string
	err = db.QueryRow("SELECT sql FROM sqlite_master WHERE type='table' AND name='positions'").Scan(&posTableSql)
	if err != nil {
		createPositionsTable := `
		CREATE TABLE positions (
			user_id TEXT NOT NULL,
			ticker TEXT NOT NULL,
			company_name TEXT DEFAULT '',
			asset_class TEXT NOT NULL,
			shares REAL NOT NULL,
			average_buy_price REAL NOT NULL,
			current_price REAL NOT NULL,
			total_value REAL NOT NULL,
			updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
			PRIMARY KEY (user_id, ticker)
		);`
		if _, err := db.Exec(createPositionsTable); err != nil {
			return nil, err
		}
	} else if !strings.Contains(posTableSql, "PRIMARY KEY (user_id, ticker)") && !strings.Contains(posTableSql, "PRIMARY KEY(user_id, ticker)") {
		log.Println("[БАЗА] Міграція таблиці positions на складений ключ (user_id, ticker)...")
		migrationSql := `
		CREATE TABLE positions_new (
			user_id TEXT NOT NULL,
			ticker TEXT NOT NULL,
			company_name TEXT DEFAULT '',
			asset_class TEXT NOT NULL,
			shares REAL NOT NULL,
			average_buy_price REAL NOT NULL,
			current_price REAL NOT NULL,
			total_value REAL NOT NULL,
			updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
			PRIMARY KEY (user_id, ticker)
		);
		INSERT OR IGNORE INTO positions_new (user_id, ticker, company_name, asset_class, shares, average_buy_price, current_price, total_value)
		SELECT COALESCE(user_id, 'legacy'), ticker, '', COALESCE(asset_class, 'Stock'), shares, current_price, current_price, total_value FROM positions;
		DROP TABLE positions;
		ALTER TABLE positions_new RENAME TO positions;
		`
		if _, err := db.Exec(migrationSql); err != nil {
			log.Printf("[БАЗА] Помилка міграції: %v", err)
		}
	}

	_ = addColumnIfMissing(db, "transactions", "type", "TEXT DEFAULT 'BUY'")
	_ = addColumnIfMissing(db, "transactions", "total_amount", "REAL DEFAULT 0")
	_ = addColumnIfMissing(db, "positions", "company_name", "TEXT DEFAULT ''")
	_ = addColumnIfMissing(db, "positions", "average_buy_price", "REAL DEFAULT 0")

	var exists int
	db.QueryRow("SELECT COUNT(*) FROM portfolio_meta WHERE key = 'cash'").Scan(&exists)
	if exists == 0 {
		db.Exec("INSERT INTO portfolio_meta (key, value) VALUES ('cash', 10000.0)")
	}

	return &Storage{DB: db}, nil
}

func (s *Storage) CreateUser(email string, password string) (User, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return User{}, err
	}
	idBytes := make([]byte, 16)
	if _, err := rand.Read(idBytes); err != nil {
		return User{}, err
	}
	user := User{ID: hex.EncodeToString(idBytes), Email: email, PasswordHash: string(hash)}
	_, err = s.DB.Exec("INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)", user.ID, user.Email, user.PasswordHash)
	if err != nil {
		return User{}, err
	}
	// Initial cash for new users: $10,000 to allow realistic simulation immediately
	_, _ = s.DB.Exec("INSERT OR REPLACE INTO portfolio_meta (key, value) VALUES (?, ?)", cashKey(user.ID), 10000.0)
	return user, nil
}
func (s *Storage) GetOrCreateOAuthUser(email string, provider string) (User, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	if email == "" {
		return User{}, errors.New("email не може бути порожнім")
	}

	var user User
	err := s.DB.QueryRow("SELECT id, email, password_hash FROM users WHERE email = ?", email).Scan(&user.ID, &user.Email, &user.PasswordHash)
	if err == nil {
		return user, nil
	}

	idBytes := make([]byte, 16)
	if _, err := rand.Read(idBytes); err != nil {
		return User{}, err
	}
	user = User{
		ID:           hex.EncodeToString(idBytes),
		Email:        email,
		PasswordHash: "oauth:" + provider,
	}
	_, err = s.DB.Exec("INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)", user.ID, user.Email, user.PasswordHash)
	if err != nil {
		return User{}, err
	}
	_, _ = s.DB.Exec("INSERT OR REPLACE INTO portfolio_meta (key, value) VALUES (?, ?)", cashKey(user.ID), 10000.0)
	return user, nil
}


func (s *Storage) AuthenticateUser(email string, password string) (User, error) {
	var user User
	err := s.DB.QueryRow("SELECT id, email, password_hash FROM users WHERE email = ?", email).Scan(&user.ID, &user.Email, &user.PasswordHash)
	if err != nil {
		return User{}, errors.New("невірна електронна пошта або пароль")
	}
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return User{}, errors.New("невірна електронна пошта або пароль")
	}
	return user, nil
}

func (s *Storage) CreateSession(userID string) (string, error) {
	tokenBytes := make([]byte, 32)
	if _, err := rand.Read(tokenBytes); err != nil {
		return "", err
	}
	token := hex.EncodeToString(tokenBytes)
	_, err := s.DB.Exec("INSERT INTO sessions (token, user_id, expires_at) VALUES (?, ?, ?)", token, userID, time.Now().Add(30*24*time.Hour).UTC())
	return token, err
}

func (s *Storage) UserIDForSession(token string) (string, error) {
	var userID string
	err := s.DB.QueryRow("SELECT user_id FROM sessions WHERE token = ? AND expires_at > ?", token, time.Now().UTC()).Scan(&userID)
	if err != nil {
		return "", errors.New("сесія недійсна або завершилася")
	}
	return userID, nil
}

func (s *Storage) DeleteAccount(userID string) error {
	tx, err := s.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Delete user sessions
	if _, err := tx.Exec("DELETE FROM sessions WHERE user_id = ?", userID); err != nil {
		return err
	}
	// Delete user dividends
	if _, err := tx.Exec("DELETE FROM dividends WHERE user_id = ?", userID); err != nil {
		return err
	}
	// Delete user transactions
	if _, err := tx.Exec("DELETE FROM transactions WHERE user_id = ?", userID); err != nil {
		return err
	}
	// Delete user positions
	if _, err := tx.Exec("DELETE FROM positions WHERE user_id = ?", userID); err != nil {
		return err
	}
	// Delete user cash
	if _, err := tx.Exec("DELETE FROM portfolio_meta WHERE key = ?", cashKey(userID)); err != nil {
		return err
	}
	// Delete user
	if _, err := tx.Exec("DELETE FROM users WHERE id = ?", userID); err != nil {
		return err
	}

	return tx.Commit()
}


func (s *Storage) DepositCash(userID string, amount float64) error {
	if amount <= 0 {
		return errors.New("сума поповнення повинна бути більше нуля")
	}
	tx, err := s.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var currentCash float64
	_ = tx.QueryRow("SELECT value FROM portfolio_meta WHERE key = ?", cashKey(userID)).Scan(&currentCash)
	newCash := round2(currentCash + amount)

	_, err = tx.Exec("INSERT INTO portfolio_meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = ?", cashKey(userID), newCash, newCash)
	if err != nil {
		return err
	}

	_, err = tx.Exec(`
		INSERT INTO transactions (user_id, type, ticker, asset_class, shares, price, total_amount, created_at)
		VALUES (?, 'DEPOSIT', 'USD', 'CASH', 1, ?, ?, CURRENT_TIMESTAMP)
	`, userID, amount, amount)
	if err != nil {
		return err
	}

	return tx.Commit()
}

func (s *Storage) WithdrawCash(userID string, amount float64) error {
	if amount <= 0 {
		return errors.New("сума виведення повинна бути більше нуля")
	}
	tx, err := s.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var currentCash float64
	_ = tx.QueryRow("SELECT value FROM portfolio_meta WHERE key = ?", cashKey(userID)).Scan(&currentCash)
	if currentCash < amount {
		return errors.New("недостатньо коштів для виведення")
	}
	newCash := round2(currentCash - amount)

	_, err = tx.Exec("INSERT INTO portfolio_meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = ?", cashKey(userID), newCash, newCash)
	if err != nil {
		return err
	}

	_, err = tx.Exec(`
		INSERT INTO transactions (user_id, type, ticker, asset_class, shares, price, total_amount, created_at)
		VALUES (?, 'WITHDRAW', 'USD', 'CASH', 1, ?, ?, CURRENT_TIMESTAMP)
	`, userID, amount, amount)
	if err != nil {
		return err
	}

	return tx.Commit()
}

func (s *Storage) AddTransaction(userID string, ticker string, assetClass string, shares float64, price float64) error {
	ticker = strings.ToUpper(strings.TrimSpace(ticker))
	if ticker == "" {
		return errors.New("тікер не може бути порожнім")
	}
	if shares <= 0 || price <= 0 {
		return errors.New("кількість та ціна мають бути більше нуля")
	}
	if assetClass == "" {
		assetClass = "Stock"
	}

	totalCost := round2(shares * price)

	tx, err := s.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var currentCash float64
	err = tx.QueryRow("SELECT value FROM portfolio_meta WHERE key = ?", cashKey(userID)).Scan(&currentCash)
	if err != nil {
		currentCash = 10000.0
	}
	if currentCash < totalCost {
		return errors.New("недостатньо кешу для покупки")
	}

	var existingShares, existingAvgPrice float64
	err = tx.QueryRow("SELECT shares, average_buy_price FROM positions WHERE user_id = ? AND ticker = ?", userID, ticker).Scan(&existingShares, &existingAvgPrice)

	newShares := round6(existingShares + shares)
	newAvgPrice := price
	if err == nil && existingShares > 0 {
		newAvgPrice = round2((existingShares*existingAvgPrice + totalCost) / newShares)
	}

	_, err = tx.Exec(`
		INSERT INTO positions (user_id, ticker, asset_class, shares, average_buy_price, current_price, total_value, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
		ON CONFLICT(user_id, ticker) DO UPDATE SET
			shares = ?,
			average_buy_price = ?,
			current_price = ?,
			total_value = ?,
			asset_class = ?,
			updated_at = CURRENT_TIMESTAMP
	`, userID, ticker, assetClass, newShares, newAvgPrice, price, round2(newShares*price),
		newShares, newAvgPrice, price, round2(newShares*price), assetClass)
	if err != nil {
		return err
	}

	newCash := round2(currentCash - totalCost)
	_, err = tx.Exec("INSERT INTO portfolio_meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = ?", cashKey(userID), newCash, newCash)
	if err != nil {
		return err
	}

	_, err = tx.Exec(`
		INSERT INTO transactions (user_id, type, ticker, asset_class, shares, price, total_amount, created_at)
		VALUES (?, 'BUY', ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
	`, userID, ticker, assetClass, shares, price, totalCost)
	if err != nil {
		return err
	}

	return tx.Commit()
}

func (s *Storage) SellTransaction(userID string, ticker string, shares float64, price float64) error {
	ticker = strings.ToUpper(strings.TrimSpace(ticker))
	if ticker == "" {
		return errors.New("тікер не може бути порожнім")
	}
	if shares <= 0 || price <= 0 {
		return errors.New("кількість та ціна мають бути більше нуля")
	}

	tx, err := s.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var existingShares, avgPrice float64
	var assetClass string
	err = tx.QueryRow("SELECT shares, average_buy_price, asset_class FROM positions WHERE user_id = ? AND ticker = ?", userID, ticker).Scan(&existingShares, &avgPrice, &assetClass)
	if err != nil || existingShares < shares {
		return errors.New("недостатньо акцій для продажу")
	}

	remainingShares := round6(existingShares - shares)
	if remainingShares <= 0.000001 {
		_, err = tx.Exec("DELETE FROM positions WHERE user_id = ? AND ticker = ?", userID, ticker)
	} else {
		_, err = tx.Exec(`
			UPDATE positions SET shares = ?, current_price = ?, total_value = ?, updated_at = CURRENT_TIMESTAMP
			WHERE user_id = ? AND ticker = ?
		`, remainingShares, price, round2(remainingShares*price), userID, ticker)
	}
	if err != nil {
		return err
	}

	proceeds := round2(shares * price)
	var currentCash float64
	_ = tx.QueryRow("SELECT value FROM portfolio_meta WHERE key = ?", cashKey(userID)).Scan(&currentCash)
	newCash := round2(currentCash + proceeds)
	_, err = tx.Exec("INSERT INTO portfolio_meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = ?", cashKey(userID), newCash, newCash)
	if err != nil {
		return err
	}

	_, err = tx.Exec(`
		INSERT INTO transactions (user_id, type, ticker, asset_class, shares, price, total_amount, created_at)
		VALUES (?, 'SELL', ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
	`, userID, ticker, assetClass, shares, price, proceeds)
	if err != nil {
		return err
	}

	return tx.Commit()
}

type StockPlanItem struct {
	Ticker     string  `json:"ticker"`
	Name       string  `json:"name"`
	AssetClass string  `json:"asset_class"`
	Price      float64 `json:"price"`
}

func (s *Storage) InvestPlan(userID string, amountPerStock float64, items []StockPlanItem) (int, float64, error) {
	if amountPerStock <= 0 || len(items) == 0 {
		return 0, 0, errors.New("некоректні параметри плану")
	}
	totalCost := round2(amountPerStock * float64(len(items)))

	tx, err := s.DB.Begin()
	if err != nil {
		return 0, 0, err
	}
	defer tx.Rollback()

	var currentCash float64
	err = tx.QueryRow("SELECT value FROM portfolio_meta WHERE key = ?", cashKey(userID)).Scan(&currentCash)
	if err != nil {
		currentCash = 10000.0
	}
	if currentCash < totalCost {
		return 0, 0, fmt.Errorf("недостатньо кешу (потрібно $%.2f, є $%.2f)", totalCost, currentCash)
	}

	count := 0
	for _, item := range items {
		ticker := strings.ToUpper(strings.TrimSpace(item.Ticker))
		if ticker == "" {
			continue
		}
		price := item.Price
		if price <= 0 {
			price = 100.0
		}
		shares := round6(amountPerStock / price)
		if shares <= 0 {
			shares = 0.000001
		}
		assetClass := item.AssetClass
		if assetClass == "" {
			assetClass = "Stock"
		}

		var existingShares, existingAvgPrice float64
		err = tx.QueryRow("SELECT shares, average_buy_price FROM positions WHERE user_id = ? AND ticker = ?", userID, ticker).Scan(&existingShares, &existingAvgPrice)
		newShares := round6(existingShares + shares)
		newAvgPrice := price
		if err == nil && existingShares > 0 {
			newAvgPrice = round2((existingShares*existingAvgPrice + amountPerStock) / newShares)
		}

		_, err = tx.Exec(`
			INSERT INTO positions (user_id, ticker, company_name, asset_class, shares, average_buy_price, current_price, total_value, updated_at)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
			ON CONFLICT(user_id, ticker) DO UPDATE SET
				company_name = CASE WHEN length(?) > 0 THEN ? ELSE company_name END,
				shares = ?,
				average_buy_price = ?,
				current_price = ?,
				total_value = ?,
				asset_class = ?,
				updated_at = CURRENT_TIMESTAMP
		`, userID, ticker, item.Name, assetClass, newShares, newAvgPrice, price, round2(newShares*price),
			item.Name, item.Name, newShares, newAvgPrice, price, round2(newShares*price), assetClass)
		if err != nil {
			return 0, 0, err
		}

		_, err = tx.Exec(`
			INSERT INTO transactions (user_id, type, ticker, asset_class, shares, price, total_amount, created_at)
			VALUES (?, 'BUY', ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
		`, userID, ticker, assetClass, shares, price, amountPerStock)
		if err != nil {
			return 0, 0, err
		}
		count++
	}

	newCash := round2(currentCash - totalCost)
	_, err = tx.Exec("INSERT INTO portfolio_meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = ?", cashKey(userID), newCash, newCash)
	if err != nil {
		return 0, 0, err
	}

	if err := tx.Commit(); err != nil {
		return 0, 0, err
	}
	return count, totalCost, nil
}

func (s *Storage) GetPortfolio(userID string) (PortfolioData, error) {
	var cash float64
	err := s.DB.QueryRow("SELECT value FROM portfolio_meta WHERE key = ?", cashKey(userID)).Scan(&cash)
	if err != nil {
		cash = 10000.0
		_, _ = s.DB.Exec("INSERT INTO portfolio_meta (key, value) VALUES (?, ?)", cashKey(userID), cash)
	}

	rows, err := s.DB.Query("SELECT ticker, company_name, asset_class, shares, average_buy_price, current_price, total_value FROM positions WHERE user_id = ?", userID)
	if err != nil {
		return PortfolioData{}, err
	}
	defer rows.Close()

	var positions []Position
	var totalAssets float64
	var totalInvestedInPositions float64

	for rows.Next() {
		var p Position
		if err := rows.Scan(&p.Ticker, &p.CompanyName, &p.AssetClass, &p.Shares, &p.AverageBuyPrice, &p.CurrentPrice, &p.TotalValue); err != nil {
			return PortfolioData{}, err
		}

		// Fetch real-time market price
		quote, quoteErr := services.DefaultMarketService.FetchQuote(p.Ticker)
		if quoteErr == nil && quote.Price > 0 {
			p.CurrentPrice = quote.Price
			p.CompanyName = quote.Name
			p.DayChangePercent = quote.ChangePercent
			p.Currency = quote.Currency
			p.TotalValue = round2(p.Shares * quote.Price)
			// Update cached price in background
			_, _ = s.DB.Exec("UPDATE positions SET current_price = ?, total_value = ?, company_name = ? WHERE user_id = ? AND ticker = ?",
				p.CurrentPrice, p.TotalValue, p.CompanyName, userID, p.Ticker)
		}

		costBasis := round2(p.Shares * p.AverageBuyPrice)
		p.UnrealizedPnL = round2(p.TotalValue - costBasis)
		if p.AverageBuyPrice > 0 {
			p.UnrealizedPnLPercent = round2((p.CurrentPrice - p.AverageBuyPrice) / p.AverageBuyPrice * 100)
		}
		if p.Currency == "" {
			p.Currency = "USD"
		}

		totalAssets += p.TotalValue
		totalInvestedInPositions += costBasis
		positions = append(positions, p)
	}

	var totalDividends float64
	_ = s.DB.QueryRow("SELECT COALESCE(SUM(amount), 0) FROM dividends WHERE user_id = ?", userID).Scan(&totalDividends)

	dividends, err := s.GetDividends(userID)
	if err != nil {
		return PortfolioData{}, err
	}

	totalPnL := round2(totalAssets - totalInvestedInPositions)
	totalPnLPercent := 0.0
	if totalInvestedInPositions > 0 {
		totalPnLPercent = round2((totalAssets - totalInvestedInPositions) / totalInvestedInPositions * 100)
	}

	return PortfolioData{
		TotalValue:      round2(cash + totalAssets),
		Cash:            round2(cash),
		InvestedValue:   round2(totalInvestedInPositions),
		TotalDividends:  round2(totalDividends),
		TotalPnL:        totalPnL,
		TotalPnLPercent: totalPnLPercent,
		Positions:       positions,
		Dividends:       dividends,
	}, nil
}

func (s *Storage) AddDividend(userID string, ticker string, amount float64, currency string) error {
	if amount <= 0 {
		return errors.New("сума дивідендів повинна бути більше нуля")
	}
	if currency == "" {
		currency = "USD"
	}
	_, err := s.DB.Exec("INSERT INTO dividends (user_id, ticker, amount, currency) VALUES (?, ?, ?, ?)", userID, strings.ToUpper(ticker), amount, currency)
	return err
}

func (s *Storage) GetDividends(userID string) ([]Dividend, error) {
	rows, err := s.DB.Query("SELECT id, ticker, amount, currency, paid_at FROM dividends WHERE user_id = ? ORDER BY id DESC", userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []Dividend
	for rows.Next() {
		var d Dividend
		if err := rows.Scan(&d.ID, &d.Ticker, &d.Amount, &d.Currency, &d.PaidAt); err != nil {
			return nil, err
		}
		list = append(list, d)
	}
	if list == nil {
		list = []Dividend{}
	}
	return list, rows.Err()
}

func (s *Storage) GetTransactions(userID string) ([]Transaction, error) {
	rows, err := s.DB.Query("SELECT id, COALESCE(type, 'BUY'), ticker, asset_class, shares, price, COALESCE(total_amount, shares * price), created_at FROM transactions WHERE user_id = ? ORDER BY id DESC", userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []Transaction
	for rows.Next() {
		var t Transaction
		if err := rows.Scan(&t.ID, &t.Type, &t.Ticker, &t.AssetClass, &t.Shares, &t.Price, &t.TotalAmount, &t.CreatedAt); err != nil {
			continue
		}
		list = append(list, t)
	}
	if list == nil {
		list = []Transaction{}
	}
	return list, nil
}
