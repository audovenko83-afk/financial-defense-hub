package services

import (
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"strings"
	"sync"
	"time"
)

type Quote struct {
	Ticker           string    `json:"ticker"`
	Name             string    `json:"name"`
	Price            float64   `json:"price"`
	PreviousClose    float64   `json:"previous_close"`
	Change           float64   `json:"change"`
	ChangePercent    float64   `json:"change_percent"`
	DayHigh          float64   `json:"day_high"`
	DayLow           float64   `json:"day_low"`
	FiftyTwoWeekHigh float64   `json:"fifty_two_week_high"`
	FiftyTwoWeekLow  float64   `json:"fifty_two_week_low"`
	Currency         string    `json:"currency"`
	Exchange         string    `json:"exchange"`
	UpdatedAt        time.Time `json:"updated_at"`
}

type HistoricalPoint struct {
	Date  string  `json:"date"`
	Close float64 `json:"close"`
}

type MarketService struct {
	httpClient *http.Client
	cache      map[string]cachedQuote
	mu         sync.RWMutex
	cacheTTL   time.Duration
}

type cachedQuote struct {
	quote     Quote
	expiresAt time.Time
}

var DefaultMarketService = NewMarketService(2 * time.Minute)

func NewMarketService(ttl time.Duration) *MarketService {
	return &MarketService{
		httpClient: &http.Client{Timeout: 10 * time.Second},
		cache:      make(map[string]cachedQuote),
		cacheTTL:   ttl,
	}
}

type yahooResp struct {
	Chart struct {
		Result []struct {
			Meta struct {
				Currency             string  `json:"currency"`
				Symbol               string  `json:"symbol"`
				ExchangeName         string  `json:"exchangeName"`
				LongName             string  `json:"longName"`
				ShortName            string  `json:"shortName"`
				RegularMarketPrice   float64 `json:"regularMarketPrice"`
				ChartPreviousClose   float64 `json:"chartPreviousClose"`
				RegularMarketDayHigh float64 `json:"regularMarketDayHigh"`
				RegularMarketDayLow  float64 `json:"regularMarketDayLow"`
				FiftyTwoWeekHigh     float64 `json:"fiftyTwoWeekHigh"`
				FiftyTwoWeekLow      float64 `json:"fiftyTwoWeekLow"`
			} `json:"meta"`
			Timestamp  []int64 `json:"timestamp"`
			Indicators struct {
				Quote []struct {
					Close []float64 `json:"close"`
				} `json:"quote"`
			} `json:"indicators"`
		} `json:"result"`
	} `json:"chart"`
}

func (m *MarketService) FetchQuote(ticker string) (Quote, error) {
	ticker = strings.ToUpper(strings.TrimSpace(ticker))
	if ticker == "" {
		return Quote{}, errors.New("порожній тікер")
	}

	m.mu.RLock()
	cached, found := m.cache[ticker]
	m.mu.RUnlock()
	if found && time.Now().Before(cached.expiresAt) {
		return cached.quote, nil
	}

	url := fmt.Sprintf("https://query1.finance.yahoo.com/v8/finance/chart/%s?interval=1d&range=1d", ticker)
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return Quote{}, err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0")
	req.Header.Set("Accept", "application/json")

	resp, err := m.httpClient.Do(req)
	if err != nil {
		if found {
			return cached.quote, nil
		}
		return Quote{}, fmt.Errorf("помилка біржі: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		if found {
			return cached.quote, nil
		}
		return Quote{}, fmt.Errorf("біржовий статус %d для %s", resp.StatusCode, ticker)
	}

	var parsed yahooResp
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		if found {
			return cached.quote, nil
		}
		return Quote{}, fmt.Errorf("помилка парсингу: %w", err)
	}

	if len(parsed.Chart.Result) == 0 {
		return Quote{}, fmt.Errorf("тікер %s не знайдено", ticker)
	}

	meta := parsed.Chart.Result[0].Meta
	name := meta.LongName
	if name == "" {
		name = meta.ShortName
	}
	if name == "" {
		name = meta.Symbol
	}

	change := 0.0
	changePercent := 0.0
	if meta.ChartPreviousClose > 0 {
		change = meta.RegularMarketPrice - meta.ChartPreviousClose
		changePercent = (change / meta.ChartPreviousClose) * 100
	}

	q := Quote{
		Ticker:           meta.Symbol,
		Name:             name,
		Price:            roundTwo(meta.RegularMarketPrice),
		PreviousClose:    roundTwo(meta.ChartPreviousClose),
		Change:           roundTwo(change),
		ChangePercent:    roundTwo(changePercent),
		DayHigh:          roundTwo(meta.RegularMarketDayHigh),
		DayLow:           roundTwo(meta.RegularMarketDayLow),
		FiftyTwoWeekHigh: roundTwo(meta.FiftyTwoWeekHigh),
		FiftyTwoWeekLow:  roundTwo(meta.FiftyTwoWeekLow),
		Currency:         meta.Currency,
		Exchange:         meta.ExchangeName,
		UpdatedAt:        time.Now().UTC(),
	}

	m.mu.Lock()
	m.cache[ticker] = cachedQuote{quote: q, expiresAt: time.Now().Add(m.cacheTTL)}
	m.mu.Unlock()

	return q, nil
}

func (m *MarketService) FetchHistory(ticker string, rangeStr string) ([]HistoricalPoint, error) {
	ticker = strings.ToUpper(strings.TrimSpace(ticker))
	if rangeStr == "" {
		rangeStr = "1y"
	}
	interval := "1mo"
	if rangeStr == "1mo" || rangeStr == "5d" || rangeStr == "6mo" {
		interval = "1d"
	} else if rangeStr == "1y" {
		interval = "1wk"
	}

	url := fmt.Sprintf("https://query1.finance.yahoo.com/v8/finance/chart/%s?interval=%s&range=%s", ticker, interval, rangeStr)
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0")

	resp, err := m.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("помилка історії %d", resp.StatusCode)
	}

	var parsed yahooResp
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, err
	}

	if len(parsed.Chart.Result) == 0 {
		return nil, errors.New("немає даних")
	}

	res := parsed.Chart.Result[0]
	timestamps := res.Timestamp
	if len(res.Indicators.Quote) == 0 {
		return nil, errors.New("порожні дані")
	}
	closes := res.Indicators.Quote[0].Close

	points := make([]HistoricalPoint, 0, len(timestamps))
	for i, ts := range timestamps {
		if i < len(closes) && closes[i] > 0 {
			t := time.Unix(ts, 0).UTC()
			points = append(points, HistoricalPoint{
				Date:  t.Format("2006-01-02"),
				Close: roundTwo(closes[i]),
			})
		}
	}
	return points, nil
}

func roundTwo(v float64) float64 {
	return math.Round(v*100) / 100
}
