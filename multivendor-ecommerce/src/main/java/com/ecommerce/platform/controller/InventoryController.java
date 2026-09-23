package com.ecommerce.platform.controller;

import com.ecommerce.platform.dto.InventoryResponse;
import com.ecommerce.platform.dto.RestockRequest;
import com.ecommerce.platform.entity.Inventory;
import com.ecommerce.platform.entity.Product;
import com.ecommerce.platform.service.InventoryService;
import com.ecommerce.platform.service.ProductService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.transaction.annotation.Transactional;

@RestController
@RequestMapping("/api/products/{productId}/inventory")
@RequiredArgsConstructor
public class InventoryController {

    private final InventoryService inventoryService;
    private final ProductService productService;

    @Transactional(readOnly = true)
    @GetMapping
    @PreAuthorize("hasRole('SELLER')")
    public ResponseEntity<InventoryResponse> getStock(@PathVariable Long productId) {
        Product product = productService.getProductOrThrow(productId);
        productService.assertOwnership(product);

        Inventory inventory = inventoryService.getByProduct(productId);
        return ResponseEntity.ok(toResponse(inventory));
    }

    @Transactional
    @PatchMapping("/restock")
    @PreAuthorize("hasRole('SELLER')")
    public ResponseEntity<InventoryResponse> restock(@PathVariable Long productId,
                                                     @Valid @RequestBody RestockRequest request) {
        Product product = productService.getProductOrThrow(productId);
        productService.assertOwnership(product);

        Inventory inventory = inventoryService.restock(productId, request.getQuantity());
        return ResponseEntity.ok(toResponse(inventory));
    }

    private InventoryResponse toResponse(Inventory inventory) {
        return InventoryResponse.builder()
                .productId(inventory.getProduct().getId())
                .productName(inventory.getProduct().getName())
                .stockQuantity(inventory.getStockQuantity())
                .build();
    }
}
