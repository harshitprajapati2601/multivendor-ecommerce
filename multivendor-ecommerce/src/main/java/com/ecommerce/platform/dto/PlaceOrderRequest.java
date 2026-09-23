package com.ecommerce.platform.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class PlaceOrderRequest {

    // Optional. The mock gateway (MockPaymentGatewayService) treats the
    // literal value "fail" as a forced decline, so Day 21's failure-path
    // test doesn't have to rely on randomness. Anything else (or omitted)
    // succeeds.
    private String paymentToken;
}
