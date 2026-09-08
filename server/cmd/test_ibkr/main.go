package main

import (
	"fmt"
	"os"

	"finance-api/internal/services"
)

func main() {
	token := "136314107001211183896714"
	queryID := "1630618"

	if len(os.Args) >= 2 {
		token = os.Args[1]
	}
	if len(os.Args) >= 3 {
		queryID = os.Args[2]
	}

	fmt.Printf("=== IBKR Diagnostic Utility ===\n")
	fmt.Printf("Testing Token:    %s\n", token)
	fmt.Printf("Testing Query ID: %s\n\n", queryID)

	report, err := services.DefaultIBKRService.FetchFlexReport(token, queryID)
	if err != nil {
		fmt.Printf("[FAILURE] Flex query returned an error:\n")
		if ibkrErr, ok := err.(*services.IBKRExchangeError); ok {
			fmt.Printf("  Error Code:       %s\n", ibkrErr.ErrorCode)
			fmt.Printf("  Error Message:    %s\n", ibkrErr.ErrorMessage)
			fmt.Printf("  Friendly Message: %s\n", ibkrErr.FriendlyMessage)
			fmt.Printf("  HTTP Status:      %d\n", ibkrErr.HTTPStatus)
			fmt.Printf("  Duration:         %d ms\n", ibkrErr.DurationMs)
			if ibkrErr.RawDetails != "" {
				fmt.Printf("  Raw Details:      %s\n", ibkrErr.RawDetails)
			}
		} else {
			fmt.Printf("  Error: %v\n", err)
		}
		os.Exit(1)
	}

	fmt.Printf("[SUCCESS] Successfully retrieved IBKR portfolio:\n")
	fmt.Printf("  Account ID:      %s\n", report.AccountID)
	fmt.Printf("  Cash Balance:    $%.2f\n", report.Cash)
	fmt.Printf("  Positions Count: %d\n", len(report.Positions))
	fmt.Printf("  Duration:        %d ms\n", report.DurationMs)
	if report.Warning != "" {
		fmt.Printf("  Warning:         %s\n", report.Warning)
	}
	for i, p := range report.Positions {
		fmt.Printf("    %2d) %-6s: %4.0f shares @ $%.2f (Value: $%.2f %s)\n",
			i+1, p.Ticker, p.Shares, p.CurrentPrice, p.TotalValue, p.Currency)
	}
}

