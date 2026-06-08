package matter

import (
	"github.com/gin-gonic/gin"

	"example.com/sample-api/envelope"
)

// Handler is the matter module's HTTP handler set.
type Handler struct{}

// New returns a new matter Handler.
func New() *Handler { return &Handler{} }

// Create godoc
// @Summary       Create matter
// @Description   Create a new matter resource owned by the caller.
// @Tags          matter
// @ID            matter.create
// @Accept        json
// @Produce       json
// @Security      Bearer
// @Param         body body CreateMatterReq true "Request body"
// @Success       201 {object} envelope.Data[MatterResp] "Matter created"
// @Failure       400 {object} envelope.Error            "VALIDATION_ERROR"
// @Failure       401 {object} envelope.Error            "AUTH_REQUIRED"
// @Failure       403 {object} envelope.Error            "FORBIDDEN"
// @Failure       429 {object} envelope.Error            "RATE_LIMITED"
// @Failure       500 {object} envelope.Error            "INTERNAL_ERROR"
// @Router        /v1/matters [post]
func (h *Handler) Create(c *gin.Context) {
	c.JSON(201, envelope.Data[MatterResp]{Data: MatterResp{}})
}

// List godoc
// @Summary       List matters
// @Description   List matters visible to the caller. Uses cursor pagination.
// @Tags          matter
// @ID            matter.list
// @Produce       json
// @Security      Bearer
// @Param         cursor    query string false "Cursor for next page"
// @Param         page_size query int    false "Page size, default 20, max 100"
// @Success       200 {object} envelope.CursorList[MatterResp]
// @Failure       401 {object} envelope.Error "AUTH_REQUIRED"
// @Failure       403 {object} envelope.Error "FORBIDDEN"
// @Failure       500 {object} envelope.Error "INTERNAL_ERROR"
// @Router        /v1/matters [get]
func (h *Handler) List(c *gin.Context) {
	c.JSON(200, envelope.CursorList[MatterResp]{})
}

// Get godoc
// @Summary       Get matter by id
// @Description   Retrieve a single matter resource.
// @Tags          matter
// @ID            matter.get
// @Produce       json
// @Security      Bearer
// @Param         matter_id path string true "Matter ID"
// @Success       200 {object} envelope.Data[MatterResp]
// @Failure       401 {object} envelope.Error "AUTH_REQUIRED"
// @Failure       403 {object} envelope.Error "FORBIDDEN"
// @Failure       404 {object} envelope.Error "NOT_FOUND"
// @Failure       500 {object} envelope.Error "INTERNAL_ERROR"
// @Router        /v1/matters/{matter_id} [get]
func (h *Handler) Get(c *gin.Context) {
	c.JSON(200, envelope.Data[MatterResp]{Data: MatterResp{}})
}

// Delete godoc
// @Summary       Delete matter
// @Description   Delete a matter the caller owns. Idempotent: returns 200 even if already deleted.
// @Tags          matter
// @ID            matter.delete
// @Produce       json
// @Security      Bearer
// @Param         matter_id path string true "Matter ID"
// @Success       200 {object} envelope.Data[envelope.EmptyResp] "Matter deleted"
// @Failure       401 {object} envelope.Error "AUTH_REQUIRED"
// @Failure       403 {object} envelope.Error "FORBIDDEN"
// @Failure       404 {object} envelope.Error "NOT_FOUND"
// @Failure       429 {object} envelope.Error "RATE_LIMITED"
// @Failure       500 {object} envelope.Error "INTERNAL_ERROR"
// @Router        /v1/matters/{matter_id} [delete]
func (h *Handler) Delete(c *gin.Context) {
	c.JSON(200, envelope.Data[envelope.EmptyResp]{Data: envelope.EmptyResp{}})
}
