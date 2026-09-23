package com.ecommerce.platform.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ProductSalesResponse {
    private Long productId;
    private String productName;
    private Long totalQuantitySold;
}
