package repository

import (
	"context"
	"errors"
	"fmt"
	"math/rand"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/FREEDOMZEGREAT/binuTech/api/internal/models"
)

type OrderRepo struct {
	DB *pgxpool.Pool
}

// CreateOrder — FR-16, FR-17, FR-20, FR-21.
// Runs inside a transaction: validates stock, decrements it, snapshots prices.
func (r *OrderRepo) CreateOrder(ctx context.Context, in models.CreateOrderRequest) (*models.Order, error) {
	tx, err := r.DB.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	// 1. Resolve zone
	var zoneID int64
	var zoneName string
	var zoneFee float64
	var etaDays string
	if err := tx.QueryRow(ctx, `
		SELECT id, name, fee_etb::float8, estimated_days
		FROM delivery_zones WHERE slug=$1 AND is_active
	`, in.ZoneID).Scan(&zoneID, &zoneName, &zoneFee, &etaDays); err != nil {
		return nil, fmt.Errorf("zone %q: %w", in.ZoneID, err)
	}

	// 2. Load each variant, decrement stock, compute lines
	var lines []orderLine
	var itemsTotal float64

	for _, it := range in.Items {
		if it.Qty <= 0 {
			return nil, fmt.Errorf("qty must be > 0 for %s", it.VariantID)
		}

		var l orderLine
		l.VariantID = it.VariantID
		l.Qty = it.Qty
		if err := tx.QueryRow(ctx, `
			SELECT p.name,
			       COALESCE(v.attributes->>'label', v.sku),
			       v.price_etb::float8
			FROM product_variants v
			JOIN products p ON p.id = v.product_id
			WHERE v.sku=$1 AND v.is_active
		`, it.VariantID).Scan(&l.ProductName, &l.VariantLabel, &l.UnitPrice); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return nil, fmt.Errorf("variant %q not found", it.VariantID)
			}
			return nil, err
		}

		// Atomic stock decrement — FR-05, FR-15
		var remaining int
		if err := tx.QueryRow(ctx, `
			UPDATE inventory SET quantity = quantity - $1
			WHERE variant_id = (SELECT id FROM product_variants WHERE sku=$2)
			  AND quantity >= $1
			RETURNING quantity
		`, it.Qty, it.VariantID).Scan(&remaining); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return nil, fmt.Errorf("insufficient stock for %q", it.VariantID)
			}
			return nil, err
		}

		itemsTotal += l.UnitPrice * float64(l.Qty)
		lines = append(lines, l)
	}

	total := itemsTotal + zoneFee

	// 3. Insert order — order_no generated here
	orderNo := fmt.Sprintf("BT-%06d", rand.Intn(900000)+100000)
	status := "pending_payment" // FR-19 (telebirr/chapa); FR-20 (COD) sets confirmed below
	if in.PaymentMethod == "cod" {
		status = "confirmed" // COD: confirm immediately
	}

	var orderID int64
	if err := tx.QueryRow(ctx, `
		INSERT INTO orders
		  (order_no, status, payment_method, customer_name, customer_phone,
		   sub_city, delivery_zone_id, address, delivery_note,
		   zone_fee_etb, items_total_etb, total_etb)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
		RETURNING id
	`, orderNo, status, in.PaymentMethod, in.CustomerName, in.CustomerPhone,
		zoneName, zoneID, in.Address, nullIfEmpty(in.Note),
		zoneFee, itemsTotal, total,
	).Scan(&orderID); err != nil {
		return nil, err
	}

	// 4. Insert order_items (price snapshot)
	for _, l := range lines {
		if _, err := tx.Exec(ctx, `
			INSERT INTO order_items
			  (order_id, variant_id, product_name, variant_label,
			   unit_price_etb, quantity, line_total_etb)
			VALUES ($1, (SELECT id FROM product_variants WHERE sku=$2),
			        $3, $4, $5, $6, $7)
		`, orderID, l.VariantID, l.ProductName, l.VariantLabel,
			l.UnitPrice, l.Qty, l.UnitPrice*float64(l.Qty),
		); err != nil {
			return nil, err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	return &models.Order{
		OrderNo:       orderNo,
		Status:        status,
		PaymentMethod: in.PaymentMethod,
		CustomerName:  in.CustomerName,
		CustomerPhone: in.CustomerPhone,
		ZoneName:      zoneName,
		Address:       in.Address,
		Note:          in.Note,
		ItemsTotal:    itemsTotal,
		DeliveryFee:   zoneFee,
		Total:         total,
		EtaDays:       etaDays,
		CreatedAt:     time.Now().UTC().Format(time.RFC3339),
		Items:         toOrderItems(lines),
	}, nil
}

// GetOrderByNoPhone — FR-22 (lookup by order# + phone)
func (r *OrderRepo) GetOrderByNoPhone(ctx context.Context, orderNo, phone string) (*models.Order, error) {
	row := r.DB.QueryRow(ctx, `
		SELECT o.order_no, o.status, o.payment_method::text,
		       o.customer_name, o.customer_phone,
		       dz.name, o.address, COALESCE(o.delivery_note,''),
		       o.items_total_etb::float8, o.zone_fee_etb::float8, o.total_etb::float8,
		       dz.estimated_days, o.placed_at
		FROM orders o
		JOIN delivery_zones dz ON dz.id = o.delivery_zone_id
		WHERE o.order_no=$1 AND o.customer_phone=$2
	`, orderNo, phone)

	var o models.Order
	var placedAt time.Time
	if err := row.Scan(
		&o.OrderNo, &o.Status, &o.PaymentMethod,
		&o.CustomerName, &o.CustomerPhone,
		&o.ZoneName, &o.Address, &o.Note,
		&o.ItemsTotal, &o.DeliveryFee, &o.Total,
		&o.EtaDays, &placedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	o.CreatedAt = placedAt.UTC().Format(time.RFC3339)

	items, err := r.loadItems(ctx, o.OrderNo)
	if err != nil {
		return nil, err
	}
	o.Items = items
	return &o, nil
}

func (r *OrderRepo) loadItems(ctx context.Context, orderNo string) ([]models.OrderItem, error) {
	rows, err := r.DB.Query(ctx, `
		SELECT oi.product_name, oi.variant_label, oi.quantity,
		       oi.unit_price_etb::float8, oi.line_total_etb::float8
		FROM order_items oi
		JOIN orders o ON o.id = oi.order_id
		WHERE o.order_no=$1
		ORDER BY oi.id
	`, orderNo)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.OrderItem
	for rows.Next() {
		var it models.OrderItem
		if err := rows.Scan(&it.ProductName, &it.VariantLabel, &it.Qty,
			&it.UnitPrice, &it.LineTotal); err != nil {
			return nil, err
		}
		out = append(out, it)
	}
	return out, rows.Err()
}

// ---------- helpers ----------

type orderLine = struct {
	VariantID    string
	ProductName  string
	VariantLabel string
	UnitPrice    float64
	Qty          int
}

func toOrderItems(lines []orderLine) []models.OrderItem {
	out := make([]models.OrderItem, len(lines))
	for i, l := range lines {
		out[i] = models.OrderItem{
			ProductName:  l.ProductName,
			VariantLabel: l.VariantLabel,
			Qty:          l.Qty,
			UnitPrice:    l.UnitPrice,
			LineTotal:    l.UnitPrice * float64(l.Qty),
		}
	}
	return out
}

func nullIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}
