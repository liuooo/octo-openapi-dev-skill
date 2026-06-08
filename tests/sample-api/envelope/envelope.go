// Package envelope mimics octo-lib's envelope types for the sample-api fixture.
// Real projects pull these from github.com/Mininglamp-OSS/octo-lib/envelope.
package envelope

// Data wraps a single-object success response: {"data": T}.
type Data[T any] struct {
	Data T `json:"data"`
}

// CursorList wraps a paginated success response (cursor mode).
type CursorList[T any] struct {
	Data       []T                  `json:"data"`
	Pagination CursorPaginationInfo `json:"pagination"`
}

// OffsetList wraps a paginated success response (offset mode).
type OffsetList[T any] struct {
	Data       []T                  `json:"data"`
	Pagination OffsetPaginationInfo `json:"pagination"`
}

// CursorPaginationInfo is the cursor-mode pagination block.
type CursorPaginationInfo struct {
	HasMore    bool   `json:"has_more"`
	NextCursor string `json:"next_cursor,omitempty"`
}

// OffsetPaginationInfo is the offset-mode pagination block.
type OffsetPaginationInfo struct {
	Total    int `json:"total"`
	Page     int `json:"page"`
	PageSize int `json:"page_size"`
}

// Error is the failure envelope used for all 4xx / 5xx responses.
type Error struct {
	Error ErrorPayload `json:"error"`
}

// ErrorPayload is the structured error body.
type ErrorPayload struct {
	Code    string                 `json:"code"`
	Message string                 `json:"message"`
	Details map[string]interface{} `json:"details,omitempty"`
	Hint    string                 `json:"hint,omitempty"`
}

// EmptyResp is the placeholder body for operations that return no data (delete / state-machine actions).
type EmptyResp struct{}
