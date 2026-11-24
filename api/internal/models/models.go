package models

// ---------- Catalog ----------

type Spec struct {
	Label string `json:"label"`
	Value string `json:"value"`
}

type Variant struct {
	ID        string   `json:"id"` // sku, e.g. "galaxy-s24-ultra:512-ti"
	Label     string   `json:"label"`
	Price     float64  `json:"price"`
	CompareAt *float64 `json:"compareAt,omitempty"`
	Stock     int      `json:"stock"`
}

type Product struct {
	ID         string    `json:"id"` // slug
	Slug       string    `json:"slug"`
	Name       string    `json:"name"`
	Brand      string    `json:"brand"`
	CategoryID string    `json:"categoryId"`
	Tagline    string    `json:"tagline"`
	Icon       string    `json:"icon"`
	Featured   bool      `json:"featured"`
	Specs      []Spec    `json:"specs"`
	Variants   []Variant `json:"variants"`
}

type DeliveryZone struct {
	ID   string  `json:"id"`
	Name string  `json:"name"`
	Fee  float64 `json:"fee"`
	Days string  `json:"days"`
}

// ---------- Cart validation ----------

type ValidateCartItem struct {
	VariantID string `json:"variantId"`
	Qty       int    `json:"qty"`
}

type ValidateCartRequest struct {
	Items []ValidateCartItem `json:"items"`
}

type CartIssue struct {
	VariantID string `json:"variantId"`
	Problem   string `json:"problem"`
	Available int    `json:"available,omitempty"`
}

type ValidateCartResponse struct {
	OK     bool        `json:"ok"`
	Issues []CartIssue `json:"issues,omitempty"`
}

// ---------- Orders ----------

type CreateOrderItem struct {
	VariantID string `json:"variantId"`
	Qty       int    `json:"qty"`
}

type CreateOrderRequest struct {
	CustomerName  string            `json:"name"`
	CustomerPhone string            `json:"phone"`
	ZoneID        string            `json:"zoneId"`
	Address       string            `json:"address"`
	Note          string            `json:"note,omitempty"`
	PaymentMethod string            `json:"paymentMethod"` // telebirr | chapa | cod
	Items         []CreateOrderItem `json:"items"`
}

type OrderItem struct {
	ProductName  string  `json:"name"`
	VariantLabel string  `json:"variant"`
	Qty          int     `json:"qty"`
	UnitPrice    float64 `json:"unitPrice"`
	LineTotal    float64 `json:"lineTotal"`
}

type Order struct {
	OrderNo       string      `json:"orderNo"`
	Status        string      `json:"status"`
	PaymentMethod string      `json:"paymentMethod"`
	CustomerName  string      `json:"name"`
	CustomerPhone string      `json:"phone"`
	ZoneName      string      `json:"zoneName"`
	Address       string      `json:"address"`
	Note          string      `json:"note,omitempty"`
	ItemsTotal    float64     `json:"itemsTotal"`
	DeliveryFee   float64     `json:"deliveryFee"`
	Total         float64     `json:"total"`
	EtaDays       string      `json:"etaDays"`
	Items         []OrderItem `json:"items"`
	CreatedAt     string      `json:"createdAt"`
}
