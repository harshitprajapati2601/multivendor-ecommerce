package com.ecommerce.platform.service;

public record PaymentGatewayResult(boolean success, String transactionId, String message) {
}
