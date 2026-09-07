package main

import (
	"encoding/json"
	"finance-api/internal/services"
	"fmt"
	"log"
)

func main() {
	svc := services.DefaultIBKRService
	token := "136314107001211183896714"
	queryID := "1351657"

	log.Printf("Testing IBKR fetch with Token: %s, QueryID: %s", token, queryID)
	data, err := svc.FetchFlexReport(token, queryID)
	if err != nil {
		log.Fatalf("Error: %v", err)
	}

	b, _ := json.MarshalIndent(data, "", "  ")
	fmt.Println(string(b))
}