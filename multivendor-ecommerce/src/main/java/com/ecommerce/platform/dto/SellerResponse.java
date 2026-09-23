package com.ecommerce.platform.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SellerResponse {
    private Long id;
    private Long userId;
    private String fullName;
    private String email;
    private String shopName;
    private String shopDescription;
    private boolean approved;
}
