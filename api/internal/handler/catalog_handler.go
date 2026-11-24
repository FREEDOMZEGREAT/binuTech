package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/FREEDOMZEGREAT/binuTech/api/internal/service"
)

type CatalogHandler struct {
	Svc *service.CatalogService
}

func (h *CatalogHandler) List(w http.ResponseWriter, r *http.Request) {
	category := r.URL.Query().Get("category")
	q := r.URL.Query().Get("q")
	items, err := h.Svc.ListProducts(r.Context(), category, q)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, items)
}

func (h *CatalogHandler) Get(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	p, err := h.Svc.GetProduct(r.Context(), slug)
	if err != nil {
		writeErr(w, 404, "product not found")
		return
	}
	writeJSON(w, 200, p)
}

func (h *CatalogHandler) Zones(w http.ResponseWriter, r *http.Request) {
	z, err := h.Svc.ListZones(r.Context())
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, z)
}
