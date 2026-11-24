package config

import (
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	Port        string
	DatabaseURL string
	WebOrigin   string
	AdminEmail  string
}

func Load() Config {
	_ = godotenv.Load(".env") // best-effort; prod uses real env
	return Config{
		Port:        getenv("PORT", "8080"),
		DatabaseURL: getenv("DATABASE_URL", "postgres://biniyam:biniyam@localhost:5432/biniyam?sslmode=disable"),
		WebOrigin:   getenv("WEB_ORIGIN", "http://localhost:3000"),
		AdminEmail:  getenv("ADMIN_EMAIL", "admin@biniyam.local"),
	}
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
