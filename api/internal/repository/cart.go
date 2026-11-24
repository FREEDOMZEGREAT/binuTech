package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/FREEDOMZEGREAT/binuTech/api/internal/models"
)

type CartRepo struct {
	DB *pgxpool.Pool
}

// Validate — checks live stock for every line and reports issues.
// Does not mutate stock; only the order transaction does that.
func (r *CartRepo) Validate(ctx context.Context, items []models.ValidateCartItem) (models.ValidateCartResponse, error) {
	resp := models.ValidateCartResponse{OK: true}

	for _, it := range items {
		var stock int
		var label string
		err := r.DB.QueryRow(ctx, `
			SELECT i.quantity, COALESCE(v.attributes->>'label', v.sku)
			FROM product_variants v
			JOIN inventory i ON i.variant_id = v.id
			WHERE v.sku=$1 AND v.is_active
		`, it.VariantID).Scan(&stock, &label)
		if err != nil {
			resp.OK = false
			resp.Issues = append(resp.Issues, models.CartIssue{
				VariantID: it.VariantID,
				Problem:   "not_found",
			})
			continue
		}
		if it.Qty <= 0 {
			resp.OK = false
			resp.Issues = append(resp.Issues, models.CartIssue{
				VariantID: it.VariantID, Problem: "invalid_qty",
			})
			continue
		}
		if it.Qty > stock {
			resp.OK = false
			resp.Issues = append(resp.Issues, models.CartIssue{
				VariantID: it.VariantID,
				Problem:   "insufficient_stock",
				Available: stock,
			})
		}
	}
	return resp, nil
}
