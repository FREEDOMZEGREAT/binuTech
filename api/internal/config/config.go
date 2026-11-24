package config

import (
	"os"
	"path/filepath"

	"github.com/joho/godotenv"
)

type Config struct {
	Port        string
	DatabaseURL string
	WebOrigin   string
	AdminEmail  string
}

func Load() Config {
	_ = godotenv.Load(findEnvFile())
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

func findEnvFile() string {
	directory, err := os.Getwd()
	if err != nil {
		return ""
	}
	for {
		candidate := filepath.Join(directory, ".env")
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
		parent := filepath.Dir(directory)
		if parent == directory {
			return ""
		}
		directory = parent
	}
}
