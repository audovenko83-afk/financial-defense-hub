package services

import (
	"strings"
	"testing"
)

func TestFriendlyIBKRExplanation(t *testing.T) {
	tests := []struct {
		name        string
		code        string
		rawMsg      string
		expectedSub string
	}{
		{
			name:        "1012 Token expired",
			code:        "1012",
			rawMsg:      "Token has expired.",
			expectedSub: "закінчився",
		},
		{
			name:        "1025 Too many failed attempts",
			code:        "1025",
			rawMsg:      "Too many failed attempts. Please review your configuration.",
			expectedSub: "1025",
		},
		{
			name:        "Raw message token expired without code",
			code:        "9999",
			rawMsg:      "Error: token expired on server",
			expectedSub: "закінчився",
		},
		{
			name:        "1013 Token not yet active",
			code:        "1013",
			rawMsg:      "Token not yet active",
			expectedSub: "активується",
		},
		{
			name:        "1018 Invalid Query ID",
			code:        "1018",
			rawMsg:      "Query not found",
			expectedSub: "Query ID",
		},
		{
			name:        "1004 Rate limit",
			code:        "1004",
			rawMsg:      "Too many requests",
			expectedSub: "ліміт",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := FriendlyIBKRExplanation(tt.code, tt.rawMsg)
			if !strings.Contains(strings.ToLower(got), strings.ToLower(tt.expectedSub)) {
				t.Errorf("FriendlyIBKRExplanation(%q, %q) = %q; want substring %q", tt.code, tt.rawMsg, got, tt.expectedSub)
			}
		})
	}
}
