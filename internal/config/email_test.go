package config

import (
	"strings"
	"testing"
)

func TestLoadSMTPConfig(t *testing.T) {
	t.Setenv("SMTP_HOST", "smtp.example.com")
	t.Setenv("SMTP_PORT", "2525")
	t.Setenv("SMTP_USERNAME", "AresFeed")
	t.Setenv("SMTP_PASSWORD", "secret")
	t.Setenv("SMTP_FROM", "AresFeed <hello@example.com>")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("load config: %v", err)
	}
	want := EmailConfig{
		SMTPHost:     "smtp.example.com",
		SMTPPort:     "2525",
		SMTPUsername: "AresFeed",
		SMTPPassword: "secret",
		SMTPFrom:     "AresFeed <hello@example.com>",
		SiteURL:      "http://localhost:3000",
	}
	if cfg.Email != want {
		t.Fatalf("email config = %#v, want %#v", cfg.Email, want)
	}
}

func TestValidateRejectsIncompleteSMTPConfig(t *testing.T) {
	cfg := &Config{
		DB:  DatabaseConfig{URL: "postgres://example"},
		JWT: JWTConfig{Secret: "test-secret"},
		Email: EmailConfig{
			SMTPHost: "smtp.example.com",
			SMTPPort: "587",
		},
	}

	err := cfg.Validate()
	if err == nil || !strings.Contains(err.Error(), "SMTP_FROM") {
		t.Fatalf("Validate() error = %v, want SMTP_FROM error", err)
	}
}

func TestValidateRejectsPartialSMTPAuthentication(t *testing.T) {
	cfg := &Config{
		DB:  DatabaseConfig{URL: "postgres://example"},
		JWT: JWTConfig{Secret: "test-secret"},
		Email: EmailConfig{
			SMTPHost:     "smtp.example.com",
			SMTPPort:     "587",
			SMTPFrom:     "hello@example.com",
			SMTPUsername: "AresFeed",
		},
	}

	err := cfg.Validate()
	if err == nil || !strings.Contains(err.Error(), "SMTP_USERNAME and SMTP_PASSWORD") {
		t.Fatalf("Validate() error = %v, want paired credentials error", err)
	}
}
