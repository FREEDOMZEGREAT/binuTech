package main

import (
	"context"
	"log"
	"os"
	"path/filepath"
	"sort"

	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load(findEnvFile())

	directory := "../db/migrations"
	if len(os.Args) > 1 {
		directory = os.Args[1]
	}

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL is not set")
	}

	files, err := filepath.Glob(filepath.Join(directory, "*.sql"))
	if err != nil {
		log.Fatalf("find SQL files: %v", err)
	}
	sort.Strings(files)
	if len(files) == 0 {
		log.Fatalf("no SQL files found in %s", directory)
	}

	ctx := context.Background()
	conn, err := pgx.Connect(ctx, databaseURL)
	if err != nil {
		log.Fatalf("connect to Neon: %v", err)
	}
	defer conn.Close(ctx)

	for _, file := range files {
		sql, err := os.ReadFile(file)
		if err != nil {
			log.Fatalf("read %s: %v", file, err)
		}
		if _, err := conn.Exec(ctx, string(sql)); err != nil {
			log.Fatalf("apply %s: %v", filepath.Base(file), err)
		}
		log.Printf("applied %s", filepath.Base(file))
	}
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
