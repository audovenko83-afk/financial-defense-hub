package services

import (
	"testing"
)

func TestMarketServiceFetchQuote(t *testing.T) {
	service := NewMarketService(0)
	quote, err := service.FetchQuote("VOO")
	if err != nil {
		t.Skipf("Live market test skipped if network unavailable: %v", err)
	}
	if quote.Ticker != "VOO" {
		t.Fatalf("expected VOO, got %s", quote.Ticker)
	}
	if quote.Price <= 0 {
		t.Fatalf("expected positive price, got %f", quote.Price)
	}
	if quote.Currency != "USD" {
		t.Fatalf("expected USD currency, got %s", quote.Currency)
	}
}

func TestMarketServiceFetchHistory(t *testing.T) {
	service := NewMarketService(0)
	points, err := service.FetchHistory("VOO", "1y")
	if err != nil {
		t.Skipf("Live market test skipped if network unavailable: %v", err)
	}
	if len(points) == 0 {
		t.Fatal("expected history points")
	}
}
