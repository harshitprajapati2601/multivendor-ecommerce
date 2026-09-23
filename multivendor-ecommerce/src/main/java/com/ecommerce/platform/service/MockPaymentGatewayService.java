package com.ecommerce.platform.service;

import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Stands in for a real payment provider (Stripe, Razorpay, etc). OrderService
 * only depends on this interface-shaped result, so swapping in a real HTTP
 * client later means changing this one class, not the order flow.
 */
@Service
public class MockPaymentGatewayService {

    public PaymentGatewayResult charge(BigDecimal amount, String paymentToken) {
        // Deterministic forced failure for testing (Day 21).
        if (paymentToken != null && paymentToken.equalsIgnoreCase("fail")) {
            return new PaymentGatewayResult(false, null, "Card declined by issuing bank");
        }

        if (amount == null || amount.signum() <= 0) {
            return new PaymentGatewayResult(false, null, "Invalid charge amount");
        }

        // Simulated success - a real gateway call would happen here instead.
        String transactionId = "MOCK-" + UUID.randomUUID();
        return new PaymentGatewayResult(true, transactionId, "Payment approved");
    }
}
