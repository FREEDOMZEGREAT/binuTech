package main

import (
	"context"
	"log"
	"net/http"
	"time"

	"github.com/FREEDOMZEGREAT/binuTech/api/internal/config"
	"github.com/FREEDOMZEGREAT/binuTech/api/internal/handler"
	"github.com/FREEDOMZEGREAT/binuTech/api/internal/repository"
	"github.com/FREEDOMZEGREAT/binuTech/api/internal/service"
	"github.com/FREEDOMZEGREAT/binuTech/api/internal/store"
)

func main() {
	cfg := config.Load()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	db, err := store.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("database unavailable: %v", err)
	}
	defer db.Close()

	router := handler.NewRouter(handler.Deps{
		Catalog: &handler.CatalogHandler{
			Svc: &service.CatalogService{Repo: &repository.CatalogRepo{DB: db}},
		},
		Cart: &handler.CartHandler{
			Svc: &service.CartService{Repo: &repository.CartRepo{DB: db}},
		},
		Checkout: &handler.CheckoutHandler{
			Svc: &service.OrderService{Repo: &repository.OrderRepo{DB: db}},
		},
		WebOrigin: cfg.WebOrigin,
	})

	log.Printf("API listening on :%s", cfg.Port)
	server := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
	}
	if err := server.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}
