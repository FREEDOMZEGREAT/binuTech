package service

import (
	"context"

	"github.com/FREEDOMZEGREAT/binuTech/api/internal/models"
	"github.com/FREEDOMZEGREAT/binuTech/api/internal/repository"
)

type CartService struct {
	Repo *repository.CartRepo
}

func (s *CartService) Validate(ctx context.Context, items []models.ValidateCartItem) (models.ValidateCartResponse, error) {
	return s.Repo.Validate(ctx, items)
}
