package com.ecommerce.platform.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CategoryRevenueResponse {
    private Long categoryId;
    private String categoryName;
    private BigDecimal totalRevenue;
}
