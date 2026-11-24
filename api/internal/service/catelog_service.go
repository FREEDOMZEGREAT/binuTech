package service

import (
	"context"

	"github.com/FREEDOMZEGREAT/binuTech/api/internal/models"
	"github.com/FREEDOMZEGREAT/binuTech/api/internal/repository"
)

type CatalogService struct {
	Repo *repository.CatalogRepo
}

func (s *CatalogService) ListProducts(ctx context.Context, category, q string) ([]models.Product, error) {
	return s.Repo.ListProducts(ctx, category, q)
}

func (s *CatalogService) GetProduct(ctx context.Context, slug string) (*models.Product, error) {
	return s.Repo.GetProductBySlug(ctx, slug)
}

func (s *CatalogService) ListZones(ctx context.Context) ([]models.DeliveryZone, error) {
	return s.Repo.ListZones(ctx)
}
