package services

import (
	"time"
)

// Моделі даних для передачі на клієнт (Flutter)

type Position struct {
	Ticker       string  `json:"ticker"`
	AssetClass   string  `json:"asset_class"`
	Shares       float64 `json:"shares"`
	AveragePrice float64 `json:"average_price"`
	CurrentPrice float64 `json:"current_price"`
	TotalValue   float64 `json:"total_value"`
	Currency     string  `json:"currency"`
}

type Dividend struct {
	Date     string  `json:"date"`
	Ticker   string  `json:"ticker"`
	Amount   float64 `json:"amount"`
	Currency string  `json:"currency"`
}

type PortfolioSummary struct {
	TotalValue float64    `json:"total_value"`
	Cash       float64    `json:"cash"`
	Positions  []Position `json:"positions"`
	Dividends  []Dividend `json:"dividends"`
}

// GetMockPortfolio повертає жорстко зашитий фіктивний портфель для демо-режиму.
// Цей портфель змодельовано для демонстрації стратегії пасивного доходу та безпеки.
func GetMockPortfolio() PortfolioSummary {
	// Динамічно генеруємо дати дивідендів, щоб вони завжди виглядали "свіжими" у застосунку
	now := time.Now()

	return PortfolioSummary{
		TotalValue: 102500.00,
		Cash:       2500.00, // Спеціально залишено 2.5k кешу для спрацьовування пуш-сповіщення (аудит вільного кешу)
		Positions: []Position{
			{Ticker: "VOO", AssetClass: "ETF", Shares: 88.23, AveragePrice: 410.50, CurrentPrice: 510.00, TotalValue: 45000.00, Currency: "USD"},
			{Ticker: "SCHD", AssetClass: "ETF", Shares: 375.00, AveragePrice: 70.00, CurrentPrice: 80.00, TotalValue: 30000.00, Currency: "USD"},
			{Ticker: "O", AssetClass: "REIT", Shares: 250.00, AveragePrice: 55.00, CurrentPrice: 60.00, TotalValue: 15000.00, Currency: "USD"},
			{Ticker: "SGOV", AssetClass: "Bonds", Shares: 100.00, AveragePrice: 100.10, CurrentPrice: 100.25, TotalValue: 10000.00, Currency: "USD"},
		},
		Dividends: []Dividend{
			{Date: now.AddDate(0, 0, -15).Format("2006-01-02"), Ticker: "O", Amount: 64.12, Currency: "USD"},
			{Date: now.AddDate(0, -1, 0).Format("2006-01-02"), Ticker: "SCHD", Amount: 245.50, Currency: "USD"},
			{Date: now.AddDate(0, -2, -10).Format("2006-01-02"), Ticker: "VOO", Amount: 150.30, Currency: "USD"},
		},
	}
}
