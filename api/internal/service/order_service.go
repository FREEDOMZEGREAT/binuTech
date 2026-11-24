package service

import (
	"context"
	"errors"
	"regexp"
	"strings"

	"github.com/FREEDOMZEGREAT/binuTech/api/internal/models"
	"github.com/FREEDOMZEGREAT/binuTech/api/internal/repository"
)

type OrderService struct {
	Repo *repository.OrderRepo
}

// +251 Ethiopian mobile validation — FR-16
var phoneRe = regexp.MustCompile(`^(?:\+251|0)?9\d{8}$`)

func normalizePhone(p string) string {
	return strings.ReplaceAll(strings.ReplaceAll(p, " ", ""), "-", "")
}

func validPhone(p string) bool {
	return phoneRe.MatchString(normalizePhone(p))
}

func validateOrder(in models.CreateOrderRequest) error {
	if strings.TrimSpace(in.CustomerName) == "" {
		return errors.New("name required")
	}
	if !validPhone(in.CustomerPhone) {
		return errors.New("valid Ethiopian mobile number required")
	}
	if in.ZoneID == "" {
		return errors.New("zone required")
	}
	if strings.TrimSpace(in.Address) == "" {
		return errors.New("address required")
	}
	switch in.PaymentMethod {
	case "telebirr", "chapa", "cod":
	default:
		return errors.New("invalid paymentMethod")
	}
	if len(in.Items) == 0 {
		return errors.New("cart empty")
	}
	return nil
}

func (s *OrderService) Create(ctx context.Context, in models.CreateOrderRequest) (*models.Order, error) {
	if err := validateOrder(in); err != nil {
		return nil, err
	}
	return s.Repo.CreateOrder(ctx, in)
}

func (s *OrderService) Lookup(ctx context.Context, orderNo, phone string) (*models.Order, error) {
	return s.Repo.GetOrderByNoPhone(ctx, orderNo, normalizePhone(phone))
}
