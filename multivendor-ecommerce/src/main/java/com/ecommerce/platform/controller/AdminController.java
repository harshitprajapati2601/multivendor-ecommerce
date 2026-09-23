package com.ecommerce.platform.controller;

import com.ecommerce.platform.dto.OrderResponse;
import com.ecommerce.platform.dto.SellerResponse;
import com.ecommerce.platform.entity.OrderStatus;
import com.ecommerce.platform.service.AdminSellerService;
import com.ecommerce.platform.service.OrderService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminController {

    private final AdminSellerService adminSellerService;
    private final OrderService orderService;

    @GetMapping("/sellers/pending")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<SellerResponse>> getPendingSellers() {
        return ResponseEntity.ok(adminSellerService.getPendingSellers());
    }

    @GetMapping("/sellers/approved")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<SellerResponse>> getApprovedSellers() {
        return ResponseEntity.ok(adminSellerService.getApprovedSellers());
    }

    @PatchMapping("/sellers/{sellerId}/approve")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<SellerResponse> approve(@PathVariable Long sellerId) {
        return ResponseEntity.ok(adminSellerService.approve(sellerId));
    }

    @DeleteMapping("/sellers/{sellerId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> rejectOrCancel(@PathVariable Long sellerId) {
        adminSellerService.rejectOrCancel(sellerId);
        return ResponseEntity.noContent().build();
    }


    @GetMapping("/orders")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Page<OrderResponse>> getAllOrders(
            @RequestParam(required = false) OrderStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());
        return ResponseEntity.ok(orderService.getAllOrders(status, pageable));
    }
}
