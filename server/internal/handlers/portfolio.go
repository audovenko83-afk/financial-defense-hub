package handlers

import (
	"encoding/json"
	"errors"
	"finance-api/internal/services"
	"finance-api/internal/storage"
	"fmt"
	"log"
	"net/http"
	"strings"
)

var store *storage.Storage

func Init(s *storage.Storage) {
	store = s
}

func userIDFromRequest(r *http.Request) (string, error) {
	header := r.Header.Get("Authorization")
	if !strings.HasPrefix(header, "Bearer ") {
		return "", errors.New("потрібна авторизація")
	}
	userID, err := store.UserIDForSession(strings.TrimPrefix(header, "Bearer "))
	if err == nil && userID != "" {
		store.TouchUserActivity(userID)
	}
	return userID, err
}

type credentialsRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func RegisterHandler(w http.ResponseWriter, r *http.Request) {
	var req credentialsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Email == "" || len(req.Password) < 8 {
		http.Error(w, "Email і пароль мають бути коректними; пароль — щонайменше 8 символів", http.StatusBadRequest)
		return
	}
	user, err := store.CreateUser(strings.ToLower(strings.TrimSpace(req.Email)), req.Password)
	if err != nil {
		http.Error(w, "Не вдалося створити профіль", http.StatusConflict)
		return
	}
	token, err := store.CreateSession(user.ID)
	if err != nil {
		http.Error(w, "Не вдалося створити сесію", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"token": token, "email": user.Email})
}

func LoginHandler(w http.ResponseWriter, r *http.Request) {
	var req credentialsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Некоректні дані входу", http.StatusBadRequest)
		return
	}
	user, err := store.AuthenticateUser(strings.ToLower(strings.TrimSpace(req.Email)), req.Password)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	token, err := store.CreateSession(user.ID)
	if err != nil {
		http.Error(w, "Не вдалося створити сесію", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"token": token, "email": user.Email})
}

type oauthRequest struct {
	Email    string `json:"email"`
	Name     string `json:"name"`
	Token    string `json:"token"`
	Provider string `json:"provider"`
}

func GoogleAuthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	var req oauthRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || strings.TrimSpace(req.Email) == "" {
		http.Error(w, "Помилка авторизації: відсутній email", http.StatusBadRequest)
		return
	}

	user, err := store.GetOrCreateOAuthUser(req.Email, "google")
	if err != nil {
		http.Error(w, "Не вдалося авторизувати через Google", http.StatusInternalServerError)
		return
	}

	token, err := store.CreateSession(user.ID)
	if err != nil {
		http.Error(w, "Не вдалося створити сесію", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"token": token,
		"email": user.Email,
	})
}

func GitHubAuthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	var req oauthRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || strings.TrimSpace(req.Email) == "" {
		http.Error(w, "Помилка авторизації: відсутній email", http.StatusBadRequest)
		return
	}

	user, err := store.GetOrCreateOAuthUser(req.Email, "github")
	if err != nil {
		http.Error(w, "Не вдалося авторизувати через GitHub", http.StatusInternalServerError)
		return
	}

	token, err := store.CreateSession(user.ID)
	if err != nil {
		http.Error(w, "Не вдалося створити сесію", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"token": token,
		"email": user.Email,
	})
}

func DeleteAccountHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	if err := store.DeleteAccount(userID); err != nil {
		http.Error(w, "Помилка при видаленні акаунту: "+err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"deleted"}`))
}

func SimulateHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	var input services.SimulationInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		http.Error(w, "Некоректні параметри симуляції", http.StatusBadRequest)
		return
	}
	results, err := services.StressTest(input)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"scenarios": results})
}

func GetPortfolioHandler(w http.ResponseWriter, r *http.Request) {
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	data, err := store.GetPortfolio(userID)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

func GetTransactionsHandler(w http.ResponseWriter, r *http.Request) {
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	list, err := store.GetTransactions(userID)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	if list == nil {
		list = []storage.Transaction{}
	}
	json.NewEncoder(w).Encode(list)
}

func GetDividendsHandler(w http.ResponseWriter, r *http.Request) {
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	list, err := store.GetDividends(userID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if list == nil {
		list = []storage.Dividend{}
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

type TransactionRequest struct {
	Ticker     string  `json:"ticker"`
	AssetClass string  `json:"asset_class"`
	Shares     float64 `json:"shares"`
	Price      float64 `json:"price"`
}

type DividendRequest struct {
	Ticker   string  `json:"ticker"`
	Amount   float64 `json:"amount"`
	Currency string  `json:"currency"`
}

func AddDividendHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	var req DividendRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Ticker == "" || req.Amount <= 0 {
		http.Error(w, "Некоректні дані дивідендів", http.StatusBadRequest)
		return
	}
	if req.Currency == "" {
		req.Currency = "USD"
	}
	if err := store.AddDividend(userID, req.Ticker, req.Amount, req.Currency); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
}

func AddTransactionHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	var req TransactionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Ticker == "" || req.Shares <= 0 || req.Price <= 0 {
		http.Error(w, "Некоректні дані транзакції (перевірте тікер, кількість та ціну)", http.StatusBadRequest)
		return
	}

	err = store.AddTransaction(userID, req.Ticker, req.AssetClass, req.Shares, req.Price)
	if err != nil {
		log.Printf("[ПОМИЛКА] %v", err)
		http.Error(w, err.Error(), http.StatusPaymentRequired)
		return
	}

	log.Printf("[API] Оброблено покупку: %s (%.2f шт по %.2f)", req.Ticker, req.Shares, req.Price)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]any{"status": "ok", "bought": req.Ticker, "shares": req.Shares, "price": req.Price})
}

type CashRequest struct {
	Amount float64 `json:"amount"`
}

func DepositCashHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	var req CashRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Amount <= 0 {
		http.Error(w, "Сума поповнення має бути більшою за нуль", http.StatusBadRequest)
		return
	}
	if err := store.DepositCash(userID, req.Amount); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]any{"status": "ok", "deposited": req.Amount})
}

func WithdrawCashHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	var req CashRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Amount <= 0 {
		http.Error(w, "Сума виведення має бути більшою за нуль", http.StatusBadRequest)
		return
	}
	if err := store.WithdrawCash(userID, req.Amount); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]any{"status": "ok", "withdrawn": req.Amount})
}

type SellTransactionRequest struct {
	Ticker string  `json:"ticker"`
	Shares float64 `json:"shares"`
	Price  float64 `json:"price"`
}

func SellTransactionHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	var req SellTransactionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Ticker == "" || req.Shares <= 0 || req.Price <= 0 {
		http.Error(w, "Некоректні параметри продажу (перевірте тікер, кількість та ціну)", http.StatusBadRequest)
		return
	}
	if err := store.SellTransaction(userID, req.Ticker, req.Shares, req.Price); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]any{"status": "ok", "sold": req.Ticker, "shares": req.Shares, "price": req.Price})
}

func MarketQuoteHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	ticker := r.URL.Query().Get("ticker")
	if ticker == "" {
		http.Error(w, "Параметр ticker є обов'язковим", http.StatusBadRequest)
		return
	}
	quote, err := services.DefaultMarketService.FetchQuote(ticker)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(quote)
}

func MarketHistoryHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	ticker := r.URL.Query().Get("ticker")
	if ticker == "" {
		http.Error(w, "Параметр ticker є обов'язковим", http.StatusBadRequest)
		return
	}
	rangeStr := r.URL.Query().Get("range")
	history, err := services.DefaultMarketService.FetchHistory(ticker, rangeStr)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"ticker": ticker, "range": rangeStr, "points": history})
}

type InvestPlanRequest struct {
	AmountPerStock float64                 `json:"amount_per_stock"`
	Stocks         []storage.StockPlanItem `json:"stocks"`
}

func InvestPlanHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	var req InvestPlanRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.AmountPerStock <= 0 || len(req.Stocks) == 0 {
		http.Error(w, "Некоректні параметри плану інвестування", http.StatusBadRequest)
		return
	}
	count, total, err := store.InvestPlan(userID, req.AmountPerStock, req.Stocks)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"status":         "ok",
		"invested_count": count,
		"total_invested": total,
	})
}

func isAdminEmail(email string) bool {
	email = strings.ToLower(strings.TrimSpace(email))
	return email == "audovenko83@gmail.com"
}

func AdminStatsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	email, err := store.GetUserEmail(userID)
	if err != nil || !isAdminEmail(email) {
		http.Error(w, "Доступ заборонено (лише для адміністратора)", http.StatusForbidden)
		return
	}
	stats, err := store.GetAdminStats()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}

func getClientIP(r *http.Request) string {
	if fwd := r.Header.Get("X-Forwarded-For"); fwd != "" {
		parts := strings.Split(fwd, ",")
		return strings.TrimSpace(parts[0])
	}
	return r.RemoteAddr
}

func maskToken(token string) string {
	token = strings.TrimSpace(token)
	if len(token) > 6 {
		return strings.Repeat("*", len(token)-4) + token[len(token)-4:]
	}
	if len(token) > 0 {
		return "******"
	}
	return ""
}

type ModeRequest struct {
	Mode string `json:"mode"`
}

func PortfolioModeHandler(w http.ResponseWriter, r *http.Request) {
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	if r.Method == http.MethodGet {
		mode := store.GetPortfolioMode(userID)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"mode": mode})
		return
	}

	if r.Method == http.MethodPost {
		var req ModeRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Некоректний запит", http.StatusBadRequest)
			return
		}
		if err := store.SetPortfolioMode(userID, req.Mode); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		ip := getClientIP(r)
		userEmail, _ := store.GetUserEmail(userID)
		_ = store.AddAuditLog(storage.AuditLog{
			UserID:    userID,
			UserEmail: userEmail,
			EventType: "MODE_SWITCH",
			Status:    "SUCCESS",
			Message:   fmt.Sprintf("Перемикання режиму портфеля: %s", req.Mode),
			IPAddress: ip,
		})
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok", "mode": req.Mode})
		return
	}

	http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
}

type SaveIBKRConfigRequest struct {
	FlexToken string `json:"flex_token"`
	QueryID   string `json:"query_id"`
}

func GetIBKRConfigHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	info, err := store.GetIBKRConnection(userID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(info)
}

func SaveIBKRConfigHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	var req SaveIBKRConfigRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]any{
			"status":           "error",
			"friendly_message": "Невірний запит налаштувань",
			"error_code":       "INVALID_REQUEST",
		})
		return
	}
	if strings.TrimSpace(req.FlexToken) == "" && strings.TrimSpace(req.QueryID) == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]any{
			"status":           "error",
			"friendly_message": "Введіть Flex Token і Query ID у налаштуваннях IBKR.",
			"error_code":       "MISSING_CREDENTIALS",
		})
		return
	}
	if req.QueryID == "" {
		req.QueryID = storage.DefaultIBKRQueryID
	}
	if req.FlexToken == "" {
		req.FlexToken = storage.DefaultIBKRToken
	}

	actualToken, err := store.SaveIBKRConnection(userID, req.FlexToken, req.QueryID)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]any{
			"status":           "error",
			"friendly_message": "Помилка збереження: " + err.Error(),
			"error_code":       "SAVE_ERROR",
		})
		return
	}

	ip := getClientIP(r)
	userEmail, _ := store.GetUserEmail(userID)
	masked := maskToken(actualToken)

	report, syncErr := services.DefaultIBKRService.FetchFlexReport(actualToken, req.QueryID)
	if syncErr != nil {
		store.SaveIBKRSyncFailure(userID, syncErr)

		errCode := "ERROR"
		rawDetails := syncErr.Error()
		durationMs := int64(0)
		friendlyMsg := syncErr.Error()

		var ibkrErr *services.IBKRExchangeError
		if errors.As(syncErr, &ibkrErr) {
			errCode = ibkrErr.ErrorCode
			rawDetails = ibkrErr.RawDetails
			durationMs = ibkrErr.DurationMs
			friendlyMsg = ibkrErr.FriendlyMessage
		}

		_ = store.AddAuditLog(storage.AuditLog{
			UserID:      userID,
			UserEmail:   userEmail,
			EventType:   "IBKR_CONFIG_SAVE",
			Status:      "ERROR",
			QueryID:     req.QueryID,
			TokenMasked: masked,
			ErrorCode:   errCode,
			Message:     friendlyMsg,
			Details:     rawDetails,
			DurationMs:  durationMs,
			IPAddress:   ip,
		})

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]any{
			"status":           "error",
			"friendly_message": friendlyMsg,
			"error_code":       errCode,
			"error_message":    syncErr.Error(),
			"raw_details":      rawDetails,
			"duration_ms":      durationMs,
			"warning":          "Налаштування збережено, але синхронізація повернула помилку: " + friendlyMsg,
		})
		return
	}

	if err := store.SaveIBKRSyncSuccess(userID, report.AccountID, report.Cash, report.Positions); err != nil {
		store.SaveIBKRSyncFailure(userID, err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]any{
			"status":           "error",
			"friendly_message": "Помилка збереження даних синхронізації: " + err.Error(),
			"error_code":       "DB_SAVE_ERROR",
			"error_message":    err.Error(),
		})
		return
	}

	_ = store.AddAuditLog(storage.AuditLog{
		UserID:      userID,
		UserEmail:   userEmail,
		EventType:   "IBKR_CONFIG_SAVE",
		Status:      "SUCCESS",
		AccountID:   report.AccountID,
		QueryID:     req.QueryID,
		TokenMasked: masked,
		Message:     fmt.Sprintf("Успішно підключено IBKR: рахунок %s, %d позицій, кеш $%.2f", report.AccountID, len(report.Positions), report.Cash),
		Details:     report.RawDetails,
		DurationMs:  report.DurationMs,
		IPAddress:   ip,
	})

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"status":           "ok",
		"account_id":       report.AccountID,
		"positions_count":  len(report.Positions),
		"cash":             report.Cash,
		"friendly_message": "Рахунок IBKR успішно підключено та синхронізовано!",
		"warning":          report.Warning,
		"duration_ms":      report.DurationMs,
		"is_demo":          report.IsDemo,
	})
}

func SyncIBKRHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	token, queryID, err := store.GetIBKRCredentials(userID)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]any{
			"status":           "error",
			"friendly_message": "IBKR ще не налаштовано. Будь ласка, введіть Flex Token та Query ID у налаштуваннях.",
			"error_code":       "NOT_CONFIGURED",
			"error_message":    err.Error(),
		})
		return
	}

	ip := getClientIP(r)
	userEmail, _ := store.GetUserEmail(userID)
	masked := maskToken(token)

	report, syncErr := services.DefaultIBKRService.FetchFlexReport(token, queryID)
	if syncErr != nil {
		store.SaveIBKRSyncFailure(userID, syncErr)

		errCode := "ERROR"
		rawDetails := syncErr.Error()
		durationMs := int64(0)
		friendlyMsg := syncErr.Error()

		var ibkrErr *services.IBKRExchangeError
		if errors.As(syncErr, &ibkrErr) {
			errCode = ibkrErr.ErrorCode
			rawDetails = ibkrErr.RawDetails
			durationMs = ibkrErr.DurationMs
			friendlyMsg = ibkrErr.FriendlyMessage
		}

		_ = store.AddAuditLog(storage.AuditLog{
			UserID:      userID,
			UserEmail:   userEmail,
			EventType:   "IBKR_SYNC",
			Status:      "ERROR",
			QueryID:     queryID,
			TokenMasked: masked,
			ErrorCode:   errCode,
			Message:     friendlyMsg,
			Details:     rawDetails,
			DurationMs:  durationMs,
			IPAddress:   ip,
		})

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]any{
			"status":           "error",
			"friendly_message": friendlyMsg,
			"error_code":       errCode,
			"error_message":    syncErr.Error(),
			"raw_details":      rawDetails,
			"duration_ms":      durationMs,
		})
		return
	}

	if err := store.SaveIBKRSyncSuccess(userID, report.AccountID, report.Cash, report.Positions); err != nil {
		store.SaveIBKRSyncFailure(userID, err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]any{
			"status":           "error",
			"friendly_message": "Помилка збереження даних: " + err.Error(),
			"error_code":       "DB_SAVE_ERROR",
			"error_message":    err.Error(),
		})
		return
	}

	_ = store.AddAuditLog(storage.AuditLog{
		UserID:      userID,
		UserEmail:   userEmail,
		EventType:   "IBKR_SYNC",
		Status:      "SUCCESS",
		AccountID:   report.AccountID,
		QueryID:     queryID,
		TokenMasked: masked,
		Message:     fmt.Sprintf("Синхронізовано IBKR: рахунок %s, %d позицій, кеш $%.2f", report.AccountID, len(report.Positions), report.Cash),
		Details:     report.RawDetails,
		DurationMs:  report.DurationMs,
		IPAddress:   ip,
	})

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"status":           "ok",
		"account_id":       report.AccountID,
		"positions_count":  len(report.Positions),
		"cash":             report.Cash,
		"friendly_message": "Синхронізація з Interactive Brokers успішна!",
		"warning":          report.Warning,
		"duration_ms":      report.DurationMs,
		"is_demo":          report.IsDemo,
	})
}

func AdminAuditLogsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	userID, err := userIDFromRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	email, err := store.GetUserEmail(userID)
	if err != nil || !isAdminEmail(email) {
		http.Error(w, "Доступ заборонено (лише для адміністратора)", http.StatusForbidden)
		return
	}
	status := r.URL.Query().Get("status")
	logs, err := store.GetAuditLogs(100, status)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"logs": logs})
}
