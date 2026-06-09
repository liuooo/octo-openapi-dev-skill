// Package main is the sample-api fixture's entry point.
//
// @title Sample API for octo-openapi-dev-skill
// @version 1.0.0
// @description Minimal fixture used to validate the skill toolchain end-to-end.
// @host api.example.com
// @BasePath /v1
// @tag.name matter
// @tag.description Matter (task) operations — sample resource for testing
// @securityDefinitions.apikey Bearer
// @in header
// @name Authorization
// @externalDocs.description Source repository
// @externalDocs.url https://github.com/liuooo/octo-openapi-dev-skill
// @contact.name octo-openapi-dev-skill maintainers
// @contact.url https://github.com/liuooo/octo-openapi-dev-skill
package main

import "github.com/gin-gonic/gin"

func main() {
	r := gin.Default()
	// Routes are registered by individual modules in real projects.
	_ = r
}
