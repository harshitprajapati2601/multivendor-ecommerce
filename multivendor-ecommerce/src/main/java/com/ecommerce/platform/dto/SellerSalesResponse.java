package com.ecommerce.platform.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class SellerSalesResponse {
    private Long sellerId;
    private String shopName;
    private BigDecimal totalRevenue;
    private Long orderCount;
}
