package services

import "testing"

func TestSimulateIncludesContributionsAndDividends(t *testing.T) {
	result, err := Simulate(SimulationInput{
		StartingCapital:     10000,
		MonthlyContribution: 1000,
		Years:               10,
		AnnualReturn:        7,
		DividendYield:       3,
		ReinvestDividends:   true,
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.TotalContributed != 130000 {
		t.Fatalf("expected contributions to be 130000, got %.2f", result.TotalContributed)
	}
	if result.TotalDividends <= 0 {
		t.Fatal("expected dividends to be positive")
	}
	if result.FinalValue <= result.TotalContributed {
		t.Fatal("expected growth above contributed capital")
	}
	if len(result.Points) != 10 {
		t.Fatalf("expected 10 yearly points, got %d", len(result.Points))
	}
}

func TestStressTestReturnsThreeScenarios(t *testing.T) {
	results, err := StressTest(SimulationInput{
		StartingCapital:     10000,
		MonthlyContribution: 500,
		Years:               20,
		AnnualReturn:        8,
		DividendYield:       2,
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 3 {
		t.Fatalf("expected 3 scenarios, got %d", len(results))
	}
	if results[0].FinalValue <= results[1].FinalValue || results[1].FinalValue <= results[2].FinalValue {
		t.Fatal("expected scenario values to decline from base to crisis")
	}
}

func TestSimulateRejectsInvalidYears(t *testing.T) {
	_, err := Simulate(SimulationInput{Years: 0})
	if err != ErrInvalidSimulationInput {
		t.Fatalf("expected invalid input error, got %v", err)
	}
}
