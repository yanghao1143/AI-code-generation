package billing

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"xingzuo/internal/api"
	"xingzuo/internal/middleware"
	"xingzuo/internal/validation"
)

func RegisterRoutes(r *gin.RouterGroup) {
	r.Use(middleware.RequirePermission("billing"))

	r.POST("/orders", func(c *gin.Context) {
		rid := c.GetString("request_id")
		var req CreateOrderRequest
		if !validation.BindJSON(c, &req) {
			return
		}
		orderID := "ord_" + uuid.NewString()
		c.JSON(200, api.OK(rid, gin.H{"orderId": orderID, "productId": req.ProductID, "amount": req.Amount, "currency": req.Currency}))
	})

	r.POST("/payments", func(c *gin.Context) {
		rid := c.GetString("request_id")
		var req CreatePaymentRequest
		if !validation.BindJSON(c, &req) {
			return
		}
		paymentID := "pay_" + uuid.NewString()
		c.JSON(200, api.OK(rid, gin.H{"paymentId": paymentID, "orderId": req.OrderID, "method": req.Method}))
	})

	r.GET("/plans", func(c *gin.Context) {
		rid := c.GetString("request_id")
		c.JSON(200, api.OK(rid, gin.H{"plans": []string{"basic", "pro", "enterprise"}}))
	})

	r.GET("/invoices", func(c *gin.Context) {
		rid := c.GetString("request_id")
		c.JSON(200, api.OK(rid, gin.H{"invoices": []string{"inv_001", "inv_002"}}))
	})
}
