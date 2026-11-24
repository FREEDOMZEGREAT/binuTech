package handler

import (
	"encoding/json"
	"net/http"

	"github.com/FREEDOMZEGREAT/binuTech/api/internal/models"
	"github.com/FREEDOMZEGREAT/binuTech/api/internal/service"
)

type CartHandler struct {
	Svc *service.CartService
}

func (h *CartHandler) Validate(w http.ResponseWriter, r *http.Request) {
	var in models.ValidateCartRequest
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeErr(w, 400, "invalid json")
		return
	}
	resp, err := h.Svc.Validate(r.Context(), in.Items)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, resp)
}
