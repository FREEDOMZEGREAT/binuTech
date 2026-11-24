package repository

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/FREEDOMZEGREAT/binuTech/api/internal/models"
)

type CatalogRepo struct {
	DB *pgxpool.Pool
}

// ListProducts — FR-02, FR-08, FR-09, FR-10.
// categorySlug and q are both optional.
func (r *CatalogRepo) ListProducts(ctx context.Context, categorySlug, q string) ([]models.Product, error) {
	rows, err := r.DB.Query(ctx, `
		SELECT p.id, p.slug, p.name, b.name, c.slug, p.description,
		       COALESCE(p.icon_key,''), p.is_featured, p.specs
		FROM products p
		JOIN brands b ON b.id = p.brand_id
		JOIN categories c ON c.id = p.category_id
		WHERE p.is_active
		  AND ($1 = '' OR c.slug = $1)
		  AND ($2 = '' OR p.name ILIKE '%'||$2||'%'
		                OR b.name ILIKE '%'||$2||'%'
		                OR p.description ILIKE '%'||$2||'%')
		ORDER BY p.is_featured DESC, p.name ASC
	`, categorySlug, q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Product
	for rows.Next() {
		var p models.Product
		var specsJSON []byte
		if err := rows.Scan(
			&p.ID, &p.Slug, &p.Name, &p.Brand, &p.CategoryID, &p.Tagline,
			&p.Icon, &p.Featured, &specsJSON,
		); err != nil {
			return nil, err
		}
		p.Specs = decodeSpecs(specsJSON)
		out = append(out, p)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	for i := range out {
		if err := r.hydrateVariants(ctx, &out[i]); err != nil {
			return nil, err
		}
	}
	if out == nil {
		out = []models.Product{}
	}
	return out, nil
}

// GetProductBySlug — FR-03, FR-04, FR-05.
func (r *CatalogRepo) GetProductBySlug(ctx context.Context, slug string) (*models.Product, error) {
	row := r.DB.QueryRow(ctx, `
		SELECT p.id, p.slug, p.name, b.name, c.slug, p.description,
		       COALESCE(p.icon_key,''), p.is_featured, p.specs
		FROM products p
		JOIN brands b ON b.id = p.brand_id
		JOIN categories c ON c.id = p.category_id
		WHERE p.is_active AND p.slug = $1
	`, slug)

	var p models.Product
	var specsJSON []byte
	if err := row.Scan(
		&p.ID, &p.Slug, &p.Name, &p.Brand, &p.CategoryID, &p.Tagline,
		&p.Icon, &p.Featured, &specsJSON,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	p.Specs = decodeSpecs(specsJSON)
	if err := r.hydrateVariants(ctx, &p); err != nil {
		return nil, err
	}
	return &p, nil
}

// CORRECTED — hydrateVariants joins on product_id (BIGINT), not slug
func (r *CatalogRepo) hydrateVariants(ctx context.Context, p *models.Product) error {
	rows, err := r.DB.Query(ctx, `
		SELECT v.sku,
		       COALESCE(v.attributes->>'label', v.sku),
		       v.price_etb::float8,
		       v.compare_at_price::float8,
		       i.quantity
		FROM product_variants v
		JOIN inventory i ON i.variant_id = v.id
		WHERE v.product_id = (SELECT id FROM products WHERE slug = $1)
		  AND v.is_active
		ORDER BY v.price_etb DESC
	`, p.Slug)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var v models.Variant
		if err := rows.Scan(&v.ID, &v.Label, &v.Price, &v.CompareAt, &v.Stock); err != nil {
			return err
		}
		p.Variants = append(p.Variants, v)
	}
	return rows.Err()
}

func decodeSpecs(raw []byte) []models.Spec {
	if len(raw) == 0 {
		return []models.Spec{}
	}
	out := make([]models.Spec, 0, 4)
	if err := json.Unmarshal(raw, &out); err != nil {
		return []models.Spec{}
	}
	return out
}

// ListZones — FR-17.
func (r *CatalogRepo) ListZones(ctx context.Context) ([]models.DeliveryZone, error) {
	rows, err := r.DB.Query(ctx, `
		SELECT slug, name, fee_etb::float8, estimated_days
		FROM delivery_zones
		WHERE is_active
		ORDER BY sort_order
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.DeliveryZone
	for rows.Next() {
		var z models.DeliveryZone
		if err := rows.Scan(&z.ID, &z.Name, &z.Fee, &z.Days); err != nil {
			return nil, err
		}
		out = append(out, z)
	}
	if out == nil {
		out = []models.DeliveryZone{}
	}
	return out, rows.Err()
}

var ErrNotFound = errors.New("not found")
