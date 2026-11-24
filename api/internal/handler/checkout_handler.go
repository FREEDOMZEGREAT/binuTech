package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/FREEDOMZEGREAT/binuTech/api/internal/models"
	"github.com/FREEDOMZEGREAT/binuTech/api/internal/service"
)

type CheckoutHandler struct {
	Svc *service.OrderService
}

func (h *CheckoutHandler) CreateOrder(w http.ResponseWriter, r *http.Request) {
	var in models.CreateOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeErr(w, 400, "invalid json")
		return
	}
	o, err := h.Svc.Create(r.Context(), in)
	if err != nil {
		writeErr(w, 400, err.Error())
		return
	}
	writeJSON(w, 201, o)
}

func (h *CheckoutHandler) LookupOrder(w http.ResponseWriter, r *http.Request) {
	orderNo := chi.URLParam(r, "orderNo")
	phone := r.URL.Query().Get("phone")
	if phone == "" {
		writeErr(w, 400, "phone required")
		return
	}
	o, err := h.Svc.Lookup(r.Context(), orderNo, phone)
	if err != nil {
		writeErr(w, 404, "order not found")
		return
	}
	writeJSON(w, 200, o)
}
