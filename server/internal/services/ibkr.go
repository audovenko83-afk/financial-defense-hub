package services

import (
	"encoding/xml"
	"errors"
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
	FlexStatement FlexStatementData `xml:"FlexStatement"`
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
	AccountID string         `json:"account_id"`
	Cash      float64        `json:"cash"`
	Positions []IBKRPosition `json:"positions"`
	SyncAt    time.Time      `json:"sync_at"`
}

// FetchFlexReport pulls open positions and cash balance from IBKR Flex Web Service
func (s *IBKRService) FetchFlexReport(token, queryID string) (*IBKRReportData, error) {
	token = strings.TrimSpace(token)
	queryID = strings.TrimSpace(queryID)

	if token == "" || queryID == "" {
		return nil, errors.New("токен та Query ID є обов'язковими для підключення до IBKR")
	}

	if strings.EqualFold(token, "DEMO_IBKR") || strings.EqualFold(queryID, "DEMO") {
		return s.getMockIBKRReport(), nil
	}

	sendURL := fmt.Sprintf(IBKRSendRequestURL, token, queryID)
	req, err := http.NewRequest(http.MethodGet, sendURL, nil)
	if err != nil {
		return nil, fmt.Errorf("помилка формування запиту: %w", err)
	}
	req.Header.Set("User-Agent", "MillionDollarWay/1.0 (FinanceApp)")

	res, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("помилка з'єднання з сервером IBKR: %w", err)
	}
	defer res.Body.Close()

	bodyBytes, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, fmt.Errorf("не вдалося прочитати відповідь IBKR: %w", err)
	}

	var initResp FlexStatementResponse
	if err := xml.Unmarshal(bodyBytes, &initResp); err != nil {
		return nil, fmt.Errorf("некоректна відповідь сервісу IBKR (XML error): %w", err)
	}

	if !strings.EqualFold(initResp.Status, "Success") {
		errMsg := initResp.ErrorMessage
		if errMsg == "" {
			errMsg = fmt.Sprintf("Код помилки IBKR: %s", initResp.ErrorCode)
		}
		return nil, fmt.Errorf("IBKR відхилив запит: %s", errMsg)
	}

	refCode := initResp.ReferenceCode
	if refCode == "" {
		return nil, errors.New("IBKR не надав ReferenceCode для звіту")
	}

	var reportData *IBKRReportData
	maxAttempts := 4
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		time.Sleep(time.Duration(attempt) * 1500 * time.Millisecond)

		getURL := fmt.Sprintf(IBKRGetStatementURL, refCode, token)
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

		var checkResp FlexStatementResponse
		if err := xml.Unmarshal(rawReport, &checkResp); err == nil && checkResp.ErrorCode != "" {
			if checkResp.ErrorCode == "1019" && attempt < maxAttempts {
				log.Printf("[IBKR] Звіт ще генерується (1019), спроба %d/%d...", attempt, maxAttempts)
				continue
			}
			return nil, fmt.Errorf("помилка завантаження звіту IBKR: %s", checkResp.ErrorMessage)
		}

		var queryResp FlexQueryResponse
		if err := xml.Unmarshal(rawReport, &queryResp); err != nil {
			continue
		}

		reportData = parseFlexStatement(&queryResp.FlexStatements.FlexStatement)
		break
	}

	if reportData == nil {
		return nil, errors.New("не вдалося отримати готовий звіт IBKR за відведений час")
	}

	return reportData, nil
}

func parseFlexStatement(stmt *FlexStatementData) *IBKRReportData {
	data := &IBKRReportData{
		AccountID: stmt.AccountId,
		SyncAt:    time.Now().UTC(),
		Positions: make([]IBKRPosition, 0),
	}

	if len(stmt.CashReport) > 0 {
		for _, cr := range stmt.CashReport {
			if cr.Currency == "BASE_SUMMARY" || cr.Currency == "USD" || cr.EndingCash > 0 {
				data.Cash = cr.EndingCash
				break
			}
		}
	}
	if data.Cash == 0 && len(stmt.EquitySummary) > 0 {
		data.Cash = stmt.EquitySummary[0].Cash
	}

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
