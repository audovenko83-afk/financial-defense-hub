package services

import "math"

type SimulationInput struct {
	StartingCapital     float64 `json:"starting_capital"`
	MonthlyContribution float64 `json:"monthly_contribution"`
	Years               int     `json:"years"`
	AnnualReturn        float64 `json:"annual_return"`
	DividendYield       float64 `json:"dividend_yield"`
	ReinvestDividends   bool    `json:"reinvest_dividends"`
	EmergencyWithdrawal float64 `json:"emergency_withdrawal"`
	WithdrawalYear      int     `json:"withdrawal_year"`
}

type SimulationPoint struct {
	Year           int     `json:"year"`
	PortfolioValue float64 `json:"portfolio_value"`
	Contributions  float64 `json:"contributions"`
	Dividends      float64 `json:"dividends"`
}

type SimulationResult struct {
	Scenario         string            `json:"scenario"`
	FinalValue       float64           `json:"final_value"`
	TotalContributed float64           `json:"total_contributed"`
	TotalDividends   float64           `json:"total_dividends"`
	TargetYear       int               `json:"target_year"`
	Points           []SimulationPoint `json:"points"`
}

func Simulate(input SimulationInput) (SimulationResult, error) {
	if input.Years < 1 || input.Years > 60 || input.StartingCapital < 0 || input.MonthlyContribution < 0 || input.AnnualReturn <= -100 || input.DividendYield < 0 {
		return SimulationResult{}, ErrInvalidSimulationInput
	}
	if input.WithdrawalYear < 0 || input.WithdrawalYear > input.Years || input.EmergencyWithdrawal < 0 {
		return SimulationResult{}, ErrInvalidSimulationInput
	}

	monthlyReturn := math.Pow(1+input.AnnualReturn/100, 1.0/12) - 1
	monthlyDividend := input.DividendYield / 100 / 12
	value := input.StartingCapital
	contributed := input.StartingCapital
	dividends := 0.0
	targetYear := 0
	points := make([]SimulationPoint, 0, input.Years)

	for month := 1; month <= input.Years*12; month++ {
		value += input.MonthlyContribution
		contributed += input.MonthlyContribution
		dividend := value * monthlyDividend
		dividends += dividend
		if input.ReinvestDividends {
			value += dividend
		}
		value *= 1 + monthlyReturn
		currentYear := (month + 11) / 12
		if input.WithdrawalYear > 0 && currentYear == input.WithdrawalYear && month%12 == 1 {
			value = math.Max(0, value-input.EmergencyWithdrawal)
		}
		if targetYear == 0 && value >= 1000000 {
			targetYear = currentYear
		}
		if month%12 == 0 {
			points = append(points, SimulationPoint{
				Year:           currentYear,
				PortfolioValue: round(value),
				Contributions:  round(contributed),
				Dividends:      round(dividends),
			})
		}
	}

	return SimulationResult{
		Scenario:         "Базовий",
		FinalValue:       round(value),
		TotalContributed: round(contributed),
		TotalDividends:   round(dividends),
		TargetYear:       targetYear,
		Points:           points,
	}, nil
}

func StressTest(input SimulationInput) ([]SimulationResult, error) {
	scenarios := []struct {
		name       string
		returnRate float64
	}{
		{"Базовий", input.AnnualReturn},
		{"Спад ринку", input.AnnualReturn - 3},
		{"Криза", input.AnnualReturn - 7},
	}
	results := make([]SimulationResult, 0, len(scenarios))
	for _, scenario := range scenarios {
		caseInput := input
		caseInput.AnnualReturn = scenario.returnRate
		result, err := Simulate(caseInput)
		if err != nil {
			return nil, err
		}
		result.Scenario = scenario.name
		results = append(results, result)
	}
	return results, nil
}

func round(value float64) float64 {
	return math.Round(value*100) / 100
}

type simulationError string

func (e simulationError) Error() string { return string(e) }

var ErrInvalidSimulationInput = simulationError("некоректні параметри симуляції")
