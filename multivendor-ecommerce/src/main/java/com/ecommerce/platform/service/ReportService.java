package com.ecommerce.platform.service;

import com.ecommerce.platform.dto.CategoryRevenueResponse;
import com.ecommerce.platform.dto.ProductSalesResponse;
import com.ecommerce.platform.dto.SellerSalesResponse;
import com.ecommerce.platform.repository.OrderItemRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ReportService {

    private final OrderItemRepository orderItemRepository;

    public List<CategoryRevenueResponse> revenueByCategory() {
        return orderItemRepository.revenueByCategory();
    }

    public List<ProductSalesResponse> topSellingProducts(int limit) {
        // PageRequest here isn't for pagination in the UI sense - it's just
        // how Spring Data lets a @Query with GROUP BY/ORDER BY be capped to
        // the top N rows without hand-writing a native LIMIT clause.
        return orderItemRepository.findTopSellingProducts(PageRequest.of(0, limit));
    }

    public List<SellerSalesResponse> topSellers(int limit) {
        return orderItemRepository.findTopSellers(PageRequest.of(0, limit));
    }
}
