package services

import (
	"encoding/xml"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"
)

// IBKR Flex Statement Web Service URLs
const (
	IBKRSendRequestURL  = "https://gdcdp.interactivebrokers.com/Universal/servlet/FlexStatementService.SendRequest?t=%s&q=%s&v=3"
	IBKRGetStatementURL = "https://gdcdp.interactivebrokers.com/Universal/servlet/FlexStatementService.GetStatement?q=%s&t=%s&v=3"
)

type FlexStatementResponse struct {
	XMLName       xml.Name `xml:"FlexStatementResponse"`
	Status        string   `xml:"Status"`
	ReferenceCode string   `xml:"ReferenceCode"`
	Url           string   `xml:"Url"`
	ErrorCode     string   `xml:"ErrorCode"`
	ErrorMessage  string   `xml:"ErrorMessage"`
}

type FlexQueryResponse struct {
	XMLName        xml.Name          `xml:"FlexQueryResponse"`
	QueryName      string            `xml:"queryName,attr"`
	FlexStatements FlexStatementsTag `xml:"FlexStatements"`
}

type FlexStatementsTag struct {
	FlexStatements []FlexStatementData `xml:"FlexStatement"`
}

type FlexStatementData struct {
	AccountId     string                `xml:"accountId,attr"`
	OpenPositions []FlexOpenPosition    `xml:"OpenPositions>OpenPosition"`
	EquitySummary []FlexEquitySummary   `xml:"EquitySummaryByReportDateInBase>EquitySummaryByReportDateInBase"`
	CashReport    []FlexCashReportEntry `xml:"CashReport>CashReportCurrency"`
}

type FlexOpenPosition struct {
	Symbol         string  `xml:"symbol,attr"`
	Description    string  `xml:"description,attr"`
	AssetCategory  string  `xml:"assetCategory,attr"`
	Position       float64 `xml:"position,attr"`
	MarkPrice      float64 `xml:"markPrice,attr"`
	CostBasisPrice float64 `xml:"costBasisPrice,attr"`
	PositionValue  float64 `xml:"positionValue,attr"`
	Currency       string  `xml:"currency,attr"`
}

type FlexEquitySummary struct {
	Cash  float64 `xml:"cash,attr"`
	Stock float64 `xml:"stock,attr"`
	Total float64 `xml:"total,attr"`
}

type FlexCashReportEntry struct {
	Currency   string  `xml:"currency,attr"`
	EndingCash float64 `xml:"endingCash,attr"`
}

type IBKRPosition struct {
	Ticker          string  `json:"ticker"`
	CompanyName     string  `json:"company_name"`
	AssetClass      string  `json:"asset_class"`
	Shares          float64 `json:"shares"`
	AverageBuyPrice float64 `json:"average_buy_price"`
	CurrentPrice    float64 `json:"current_price"`
	TotalValue      float64 `json:"total_value"`
	Currency        string  `json:"currency"`
}

type IBKRReportData struct {
	AccountID  string         `json:"account_id"`
	Cash       float64        `json:"cash"`
	Positions  []IBKRPosition `json:"positions"`
	SyncAt     time.Time      `json:"sync_at"`
	DurationMs int64          `json:"duration_ms"`
	RawDetails string         `json:"raw_details,omitempty"`
	Warning    string         `json:"warning,omitempty"`
	IsDemo     bool           `json:"is_demo,omitempty"`
}

type IBKRExchangeError struct {
	ErrorCode       string `json:"error_code"`
	ErrorMessage    string `json:"error_message"`
	FriendlyMessage string `json:"friendly_message"`
	RawDetails      string `json:"raw_details"`
	HTTPStatus      int    `json:"http_status"`
	DurationMs      int64  `json:"duration_ms"`
}

func (e *IBKRExchangeError) Error() string {
	if e.FriendlyMessage != "" {
		return e.FriendlyMessage
	}
	if e.ErrorMessage != "" {
		return e.ErrorMessage
	}
	return fmt.Sprintf("Помилка IBKR (код %s)", e.ErrorCode)
}

func FriendlyIBKRExplanation(code, rawMsg string) string {
	switch strings.TrimSpace(code) {
	case "1001":
		return "Запит містить невірні або порожні параметри."
	case "1003":
		return "Служба Flex Web Service IBKR тимчасово недоступна. Будь ласка, спробуйте пізніше."
	case "1004":
		return "Перевищено ліміт частоти запитів до IBKR. Зачекайте 2–3 хвилини перед наступною спробою."
	case "1005":
		return "Доступ обмежено за IP-адресою у налаштуваннях вашого акаунта IBKR."
	case "1009":
		return "Сервер IBKR відхилив запит через системну помилку. Спробуйте пізніше."
	case "1012":
		return "Токен ще не активовано в системі Interactive Brokers. Зазвичай активація займає кілька хвилин після створення."
	case "1014":
		return "Термін дії токена Flex Query закінчився (у кабінеті IBKR токен діє до 1 року). Згенеруйте новий токен у розділі Flex Web Service."
	case "1015":
		return "Невірний цифровий токен Flex Query. Перевірте, чи правильно скопійовано всі цифри токена з кабінету IBKR без пробілів."
	case "1016":
		return "Звіт ще генерується серверами IBKR. Будь ласка, зачекайте 1–2 хвилини та натисніть «Синхронізувати зараз»."
	case "1017":
		return "Час очікування генерації звіту в IBKR минув. Спробуйте запустити синхронізацію ще раз."
	case "1018":
		return "Невірний Query ID. Звіт із таким цифровим номером не знайдено у вашому акаунті Interactive Brokers. Перевірте номер у списку Flex Queries."
	case "1019":
		return "Звіт поставлено в чергу на генерацію в IBKR. Зачекайте 1–2 хвилини та оновіть."
	case "1021":
		return "Службу Flex Web Service не увімкнено. Активуйте перемикач Flex Web Service у кабінеті IBKR (Performance & Reports -> Flex Queries)."
	default:
		if strings.Contains(strings.ToLower(rawMsg), "token") {
			return "Помилка токена IBKR: " + rawMsg + ". Перевірте токен у кабінеті IBKR."
		}
		if strings.Contains(strings.ToLower(rawMsg), "query") {
			return "Помилка Query ID: " + rawMsg + ". Перевірте налаштування Flex Query."
		}
		if rawMsg != "" {
			return "Помилка сервісу IBKR: " + rawMsg
		}
		return "Не вдалося отримати звіт від Interactive Brokers. Перевірте цифровий токен і Query ID."
	}
}

// FetchFlexReport pulls open positions and cash balance from IBKR Flex Web Service
func (s *IBKRService) FetchFlexReport(token, queryID string) (*IBKRReportData, error) {
	start := time.Now()
	token = strings.TrimSpace(token)
	queryID = strings.TrimSpace(queryID)

	if token == "" || queryID == "" {
		return nil, &IBKRExchangeError{
			ErrorCode:       "EMPTY_PARAMS",
			ErrorMessage:    "Token or QueryID empty",
			FriendlyMessage: "Токен та Query ID є обов'язковими для підключення до IBKR",
			DurationMs:      0,
		}
	}

	if strings.EqualFold(token, "DEMO_IBKR") || strings.EqualFold(queryID, "DEMO") {
		time.Sleep(300 * time.Millisecond)
		report := s.getMockIBKRReport()
		report.DurationMs = time.Since(start).Milliseconds()
		report.IsDemo = true
		return report, nil
	}

	baseURLs := []string{
		"https://ndcdp.interactivebrokers.com",
		"https://gdcdp.interactivebrokers.com",
		"https://www.interactivebrokers.com",
		"https://www.interactivebrokers.co.uk",
	}

	var initResp FlexStatementResponse
	var rawInitialXML string
	var successBaseURL string
	var lastHTTPStatus int

	for _, baseURL := range baseURLs {
		sendURL := fmt.Sprintf("%s/Universal/servlet/FlexStatementService.SendRequest?t=%s&q=%s&v=3", baseURL, token, queryID)
		req, err := http.NewRequest(http.MethodGet, sendURL, nil)
		if err != nil {
			continue
		}
		req.Header.Set("User-Agent", "MillionDollarWay/1.0 (FinanceApp)")

		res, err := s.httpClient.Do(req)
		if err != nil {
			continue
		}

		bodyBytes, err := io.ReadAll(res.Body)
		res.Body.Close()
		if err != nil {
			continue
		}

		lastHTTPStatus = res.StatusCode
		if res.StatusCode == 404 || res.StatusCode >= 500 {
			continue
		}

		rawInitialXML = string(bodyBytes)
		if err := xml.Unmarshal(bodyBytes, &initResp); err == nil && (initResp.Status == "Success" || initResp.ErrorCode != "") {
			successBaseURL = baseURL
			break
		}
	}

	if successBaseURL == "" {
		if rawInitialXML != "" {
			return nil, &IBKRExchangeError{
				ErrorCode:       "XML_PARSE_ERROR",
				ErrorMessage:    "IBKR returned invalid XML or error page",
				FriendlyMessage: "IBKR надіслав некоректну відповідь або сторінку помилки замість XML",
				RawDetails:      rawInitialXML,
				HTTPStatus:      lastHTTPStatus,
				DurationMs:      time.Since(start).Milliseconds(),
			}
		}
		return nil, &IBKRExchangeError{
			ErrorCode:       "NETWORK_ERROR",
			ErrorMessage:    "All IBKR base URLs failed or returned 404",
			FriendlyMessage: "Не вдалося з'єднатися з серверами Interactive Brokers. Перевірте інтернет-з'єднання.",
			HTTPStatus:      lastHTTPStatus,
			DurationMs:      time.Since(start).Milliseconds(),
		}
	}

	if !strings.EqualFold(initResp.Status, "Success") {
		errMsg := initResp.ErrorMessage
		if errMsg == "" {
			errMsg = fmt.Sprintf("Код помилки IBKR: %s", initResp.ErrorCode)
		}
		friendly := FriendlyIBKRExplanation(initResp.ErrorCode, errMsg)
		return nil, &IBKRExchangeError{
			ErrorCode:       initResp.ErrorCode,
			ErrorMessage:    errMsg,
			FriendlyMessage: friendly,
			RawDetails:      rawInitialXML,
			HTTPStatus:      lastHTTPStatus,
			DurationMs:      time.Since(start).Milliseconds(),
		}
	}

	refCode := initResp.ReferenceCode
	if refCode == "" {
		return nil, &IBKRExchangeError{
			ErrorCode:       "NO_REFERENCE_CODE",
			ErrorMessage:    "Missing ReferenceCode",
			FriendlyMessage: "IBKR успішно прийняв запит, але не надав ReferenceCode для завантаження",
			RawDetails:      rawInitialXML,
			DurationMs:      time.Since(start).Milliseconds(),
		}
	}

	var reportData *IBKRReportData
	maxAttempts := 10
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		time.Sleep(time.Duration(attempt) * 2000 * time.Millisecond)

		getURL := initResp.Url
		if getURL == "" {
			getURL = successBaseURL + "/Universal/servlet/FlexStatementService.GetStatement"
		}
		if !strings.Contains(getURL, "?") {
			getURL += fmt.Sprintf("?q=%s&t=%s&v=3", refCode, token)
		} else if !strings.Contains(getURL, "q=") {
			getURL += fmt.Sprintf("&q=%s&t=%s&v=3", refCode, token)
		}

		getReq, _ := http.NewRequest(http.MethodGet, getURL, nil)
		getReq.Header.Set("User-Agent", "MillionDollarWay/1.0 (FinanceApp)")

		getRes, getErr := s.httpClient.Do(getReq)
		if getErr != nil {
			continue
		}

		rawReport, readErr := io.ReadAll(getRes.Body)
		getRes.Body.Close()
		if readErr != nil {
			continue
		}

		rawReportStr := string(rawReport)

		var checkResp FlexStatementResponse
		if err := xml.Unmarshal(rawReport, &checkResp); err == nil && checkResp.ErrorCode != "" {
			if (checkResp.ErrorCode == "1019" || checkResp.ErrorCode == "1016") && attempt < maxAttempts {
				log.Printf("[IBKR] Звіт ще генерується (%s), спроба %d/%d...", checkResp.ErrorCode, attempt, maxAttempts)
				continue
			}
			return nil, &IBKRExchangeError{
				ErrorCode:       checkResp.ErrorCode,
				ErrorMessage:    checkResp.ErrorMessage,
				FriendlyMessage: FriendlyIBKRExplanation(checkResp.ErrorCode, checkResp.ErrorMessage),
				RawDetails:      rawReportStr,
				DurationMs:      time.Since(start).Milliseconds(),
			}
		}

		var queryResp FlexQueryResponse
		if err := xml.Unmarshal(rawReport, &queryResp); err != nil {
			continue
		}

		reportData = parseFlexStatements(queryResp.FlexStatements.FlexStatements)
		reportData.RawDetails = fmt.Sprintf("Query: %s, Account: %s, Positions: %d, Cash: $%.2f",
			queryResp.QueryName, reportData.AccountID, len(reportData.Positions), reportData.Cash)
		break
	}

	if reportData == nil {
		return nil, &IBKRExchangeError{
			ErrorCode:       "TIMEOUT_WAITING_STATEMENT",
			ErrorMessage:    "Statement generation timed out",
			FriendlyMessage: "IBKR ще не завершив формування звіту. Зазвичай це займає 1–3 хвилини (особливо за великий період), спробуйте синхронізацію трохи згодом.",
			DurationMs:      time.Since(start).Milliseconds(),
		}
	}

	reportData.DurationMs = time.Since(start).Milliseconds()

	if reportData.Cash == 0 && len(reportData.Positions) == 0 {
		reportData.Warning = "Звіт успішно отримано, але в ньому немає відкритих позицій або кешу. Перевірте, чи додано секції 'Open Positions' та 'Cash Report' у конфігурації Flex Query в кабінеті IBKR."
	}

	return reportData, nil
}

func parseFlexStatements(stmts []FlexStatementData) *IBKRReportData {
	data := &IBKRReportData{
		SyncAt:    time.Now().UTC(),
		Positions: make([]IBKRPosition, 0),
	}

	var accIDs []string
	var totalCash float64

	for _, stmt := range stmts {
		accIDs = append(accIDs, stmt.AccountId)

		var stmtCash float64
		if len(stmt.CashReport) > 0 {
			for _, cr := range stmt.CashReport {
				if cr.Currency == "BASE_SUMMARY" || cr.Currency == "USD" || cr.EndingCash > 0 {
					stmtCash = cr.EndingCash
					break
				}
			}
		}
		if stmtCash == 0 && len(stmt.EquitySummary) > 0 {
			stmtCash = stmt.EquitySummary[0].Cash
		}
		totalCash += stmtCash

		for _, p := range stmt.OpenPositions {
			if p.Position <= 0 {
				continue
			}
			assetClass := "Stock"
			if strings.EqualFold(p.AssetCategory, "ETF") {
				assetClass = "ETF"
			} else if strings.EqualFold(p.AssetCategory, "BOND") {
				assetClass = "Bond"
			}

			name := p.Description
			if name == "" {
				name = p.Symbol
			}

			avgPrice := p.CostBasisPrice
			if avgPrice <= 0 && p.Position > 0 && p.PositionValue > 0 {
				avgPrice = p.PositionValue / p.Position
			}

			curPrice := p.MarkPrice
			if curPrice <= 0 && p.Position > 0 {
				curPrice = avgPrice
			}

			val := p.PositionValue
			if val <= 0 {
				val = p.Position * curPrice
			}

			curr := p.Currency
			if curr == "" {
				curr = "USD"
			}

			data.Positions = append(data.Positions, IBKRPosition{
				Ticker:          strings.ToUpper(p.Symbol),
				CompanyName:     name,
				AssetClass:      assetClass,
				Shares:          p.Position,
				AverageBuyPrice: avgPrice,
				CurrentPrice:    curPrice,
				TotalValue:      val,
				Currency:        curr,
			})
		}
	}

	if len(accIDs) > 0 {
		uniqueAccs := make(map[string]bool)
		var finalAccs []string
		for _, a := range accIDs {
			if !uniqueAccs[a] && a != "" {
				uniqueAccs[a] = true
				finalAccs = append(finalAccs, a)
			}
		}
		data.AccountID = strings.Join(finalAccs, ", ")
	}
	data.Cash = totalCash

	return data
}

func (s *IBKRService) getMockIBKRReport() *IBKRReportData {
	return &IBKRReportData{
		AccountID: "U9876543 (IBKR Live)",
		Cash:      3450.00,
		SyncAt:    time.Now().UTC(),
		Positions: []IBKRPosition{
			{Ticker: "VOO", CompanyName: "Vanguard S&P 500 ETF", AssetClass: "ETF", Shares: 35.0, AverageBuyPrice: 480.20, CurrentPrice: 512.40, TotalValue: 17934.00, Currency: "USD"},
			{Ticker: "AAPL", CompanyName: "Apple Inc.", AssetClass: "Stock", Shares: 20.0, AverageBuyPrice: 195.50, CurrentPrice: 224.20, TotalValue: 4484.00, Currency: "USD"},
			{Ticker: "MSFT", CompanyName: "Microsoft Corp.", AssetClass: "Stock", Shares: 15.0, AverageBuyPrice: 410.00, CurrentPrice: 448.50, TotalValue: 6727.50, Currency: "USD"},
			{Ticker: "SCHD", CompanyName: "Schwab US Dividend Equity ETF", AssetClass: "ETF", Shares: 100.0, AverageBuyPrice: 75.00, CurrentPrice: 82.30, TotalValue: 8230.00, Currency: "USD"},
			{Ticker: "SGOV", CompanyName: "iShares 0-3 Month Treasury Bond ETF", AssetClass: "Bond", Shares: 50.0, AverageBuyPrice: 100.20, CurrentPrice: 100.45, TotalValue: 5022.50, Currency: "USD"},
		},
	}
}


type IBKRService struct {
	httpClient *http.Client
}

var DefaultIBKRService = &IBKRService{
	httpClient: &http.Client{Timeout: 25 * time.Second},
}
