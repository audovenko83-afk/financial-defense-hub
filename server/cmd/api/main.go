package main

import (
	"finance-api/internal/handlers"
	"finance-api/internal/storage"
	"log"
	"net/http"
	"os"
)

func main() {
	dbPath := os.Getenv("DB_PATH")
	if dbPath == "" {
		dbPath = "app.db"
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	store, err := storage.NewStorage(dbPath)
	if err != nil {
		log.Fatalf("Помилка ініціалізації бази даних: %v", err)
	}
	handlers.Init(store)

	mux := http.NewServeMux()
	mux.HandleFunc("/api/portfolio", handlers.GetPortfolioHandler)
	mux.HandleFunc("/api/auth/register", handlers.RegisterHandler)
	mux.HandleFunc("/api/auth/login", handlers.LoginHandler)
	mux.HandleFunc("/api/auth/account", handlers.DeleteAccountHandler)
	mux.HandleFunc("/api/auth/google", handlers.GoogleAuthHandler)
	mux.HandleFunc("/api/auth/github", handlers.GitHubAuthHandler)

	mux.HandleFunc("/api/transactions", handlers.AddTransactionHandler)
	mux.HandleFunc("/api/transactions/sell", handlers.SellTransactionHandler)
	mux.HandleFunc("/api/cash/deposit", handlers.DepositCashHandler)
	mux.HandleFunc("/api/cash/withdraw", handlers.WithdrawCashHandler)
	mux.HandleFunc("/api/history", handlers.GetTransactionsHandler)
	mux.HandleFunc("/api/dividends", handlers.GetDividendsHandler)
	mux.HandleFunc("/api/dividends/add", handlers.AddDividendHandler)
	mux.HandleFunc("/api/simulator", handlers.SimulateHandler)
	mux.HandleFunc("/api/strategy/invest-plan", handlers.InvestPlanHandler)
	mux.HandleFunc("/api/market/quote", handlers.MarketQuoteHandler)
	mux.HandleFunc("/api/market/history", handlers.MarketHistoryHandler)
	mux.HandleFunc("/api/portfolio/mode", handlers.PortfolioModeHandler)
	mux.HandleFunc("/api/ibkr/config", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			handlers.SaveIBKRConfigHandler(w, r)
		} else {
			handlers.GetIBKRConfigHandler(w, r)
		}
	})
	mux.HandleFunc("/api/ibkr/sync", handlers.SyncIBKRHandler)
	mux.HandleFunc("/api/admin/users", handlers.AdminStatsHandler)
	mux.HandleFunc("/api/ping", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})


	log.Printf("--- СЕРВЕР ЗАПУЩЕНО НА ПОРТУ %s (БД: %s) ---", port, dbPath)

	corsHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept")
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		mux.ServeHTTP(w, r)
	})

	if err := http.ListenAndServe(":"+port, corsHandler); err != nil {
		log.Fatalf("Помилка роботи сервера: %v", err)
	}
}

