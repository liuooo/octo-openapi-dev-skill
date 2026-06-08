// Package matter contains sample handlers for the "matter" resource.
package matter

// CreateMatterReq is the request body for POST /v1/matters.
type CreateMatterReq struct {
	Title       string   `json:"title"                     binding:"required,max=200"`
	Description string   `json:"description,omitempty"`
	AssigneeIDs []string `json:"assignee_ids,omitempty"`
	DueAt       *string  `json:"due_at,omitempty"          swaggertype:"string,date-time"`
	IsUrgent    bool     `json:"is_urgent,omitempty"`
}

// MatterResp is the response body for matter endpoints.
type MatterResp struct {
	MatterID    string   `json:"matter_id"`
	Title       string   `json:"title"`
	Description string   `json:"description"`
	AssigneeIDs []string `json:"assignee_ids"`
	DueAt       *string  `json:"due_at,omitempty"`
	IsUrgent    bool     `json:"is_urgent"`
	CreatedAt   string   `json:"created_at"                swaggertype:"string,date-time"`
	UpdatedAt   string   `json:"updated_at"                swaggertype:"string,date-time"`
}
