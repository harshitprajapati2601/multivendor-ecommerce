package com.ecommerce.platform.repository;

import com.ecommerce.platform.dto.CategoryRevenueResponse;
import com.ecommerce.platform.dto.ProductSalesResponse;
import com.ecommerce.platform.dto.SellerSalesResponse;
import com.ecommerce.platform.entity.OrderItem;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface OrderItemRepository extends JpaRepository<OrderItem, Long> {

    // Day 22: a customer may only review a product they actually received.
    // Comparing against the enum's name works because Order.status is
    // @Enumerated(EnumType.STRING).
    @Query("SELECT COUNT(oi) > 0 FROM OrderItem oi " +
           "WHERE oi.order.customer.id = :customerId " +
           "AND oi.product.id = :productId " +
           "AND oi.order.status = 'DELIVERED'")
    boolean existsDeliveredPurchase(@Param("customerId") Long customerId, @Param("productId") Long productId);

    // Day 23: revenue grouped by category. CANCELLED orders don't count as revenue.
    @Query("SELECT new com.ecommerce.platform.dto.CategoryRevenueResponse(" +
           "  oi.product.category.id, oi.product.category.name, SUM(oi.priceAtPurchase * oi.quantity)) " +
           "FROM OrderItem oi " +
           "WHERE oi.order.status <> 'CANCELLED' " +
           "GROUP BY oi.product.category.id, oi.product.category.name " +
           "ORDER BY SUM(oi.priceAtPurchase * oi.quantity) DESC")
    List<CategoryRevenueResponse> revenueByCategory();

    // Day 23: top-selling products by total quantity sold.
    @Query("SELECT new com.ecommerce.platform.dto.ProductSalesResponse(" +
           "  oi.product.id, oi.product.name, SUM(oi.quantity)) " +
           "FROM OrderItem oi " +
           "WHERE oi.order.status <> 'CANCELLED' " +
           "GROUP BY oi.product.id, oi.product.name " +
           "ORDER BY SUM(oi.quantity) DESC")
    List<ProductSalesResponse> findTopSellingProducts(Pageable pageable);

    // Day 24: top sellers by revenue, with distinct order count as a secondary metric.
    @Query("SELECT new com.ecommerce.platform.dto.SellerSalesResponse(" +
           "  oi.product.seller.id, oi.product.seller.shopName, " +
           "  SUM(oi.priceAtPurchase * oi.quantity), COUNT(DISTINCT oi.order.id)) " +
           "FROM OrderItem oi " +
           "WHERE oi.order.status <> 'CANCELLED' " +
           "GROUP BY oi.product.seller.id, oi.product.seller.shopName " +
           "ORDER BY SUM(oi.priceAtPurchase * oi.quantity) DESC")
    List<SellerSalesResponse> findTopSellers(Pageable pageable);
}
