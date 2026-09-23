package com.ecommerce.platform.dto;

import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ProductRequest {

    @NotBlank(message = "Product name is required")
    @Size(max = 150, message = "Product name must be under 150 characters")
    private String name;

    @Size(max = 2000, message = "Description must be under 2000 characters")
    private String description;

    @NotNull(message = "Price is required")
    @DecimalMin(value = "0.01", message = "Price must be greater than 0")
    private BigDecimal price;

    @NotNull(message = "categoryId is required")
    private Long categoryId;

    // Only used when creating a product - ignored on update (use the
    // restock endpoint to change stock after creation).
    @Min(value = 0, message = "Initial stock cannot be negative")
    private Integer initialStock;
}
