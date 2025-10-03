package billing

type CreateOrderRequest struct {
	ProductID string `json:"productId" binding:"required"`
	Amount    int    `json:"amount" binding:"required"`
	Currency  string `json:"currency" binding:"required"`
}

type CreatePaymentRequest struct {
	OrderID string `json:"orderId" binding:"required"`
	Method  string `json:"method" binding:"required"`
}
