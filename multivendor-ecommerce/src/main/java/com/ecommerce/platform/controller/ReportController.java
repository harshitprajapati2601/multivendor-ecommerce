package com.ecommerce.platform.controller;

import com.ecommerce.platform.dto.CategoryRevenueResponse;
import com.ecommerce.platform.dto.ProductSalesResponse;
import com.ecommerce.platform.dto.SellerSalesResponse;
import com.ecommerce.platform.service.ReportService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/reports")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class ReportController {

    private final ReportService reportService;

    @GetMapping("/revenue-by-category")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<CategoryRevenueResponse>> revenueByCategory() {
        return ResponseEntity.ok(reportService.revenueByCategory());
    }

    @GetMapping("/top-selling-products")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<ProductSalesResponse>> topSellingProducts(
            @RequestParam(defaultValue = "10") int limit) {
        return ResponseEntity.ok(reportService.topSellingProducts(limit));
    }

    @GetMapping("/top-sellers")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<SellerSalesResponse>> topSellers(
            @RequestParam(defaultValue = "10") int limit) {
        return ResponseEntity.ok(reportService.topSellers(limit));
    }
}
