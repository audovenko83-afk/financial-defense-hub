package models

import (
	"time"
)

// User — головний профіль інвестора
type User struct {
	ID                  string    `json:"id"`
	Email               string    `json:"email"`
	PasswordHash        string    `json:"-"`                    // Пароль ніколи не передається на клієнт (захист)
	SubscriptionPlan    string    `json:"subscription_plan"`    // Значення: "FREE", "MONTHLY", "ANNUAL"
	OnboardingCompleted bool      `json:"onboarding_completed"` // true — пропускаємо "Машину часу"
	CreatedAt           time.Time `json:"created_at"`
	UpdatedAt           time.Time `json:"updated_at"`
}

// IBKRConnection — налаштування синхронізації з Interactive Brokers (Read-Only)
type IBKRConnection struct {
	ID             string    `json:"id"`
	UserID         string    `json:"user_id"`
	FlexQueryToken string    `json:"flex_query_token"` // Зашифрований токен доступу
	QueryID        string    `json:"query_id"`         // ID звіту для отримання даних
	LastSyncAt     time.Time `json:"last_sync_at"`     // Час останнього успішного оновлення
}

// AuditSettings — налаштування модуля автоматичного аудиту та оптимізації
type AuditSettings struct {
	ID             string `json:"id"`
	UserID         string `json:"user_id"`
	DetectedTariff string `json:"detected_tariff"` // "FIXED", "TIERED" або "UNKNOWN"
	IdleCashLimit  int    `json:"idle_cash_limit"` // Ліміт вільного кешу, після якого система радить SGOV (наприклад, 1000)
	AlertsEnabled  bool   `json:"alerts_enabled"`  // Чи дозволяє користувач отримувати поради з економії
}
