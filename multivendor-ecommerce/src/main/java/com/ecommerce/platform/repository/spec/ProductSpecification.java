package com.ecommerce.platform.repository.spec;

import com.ecommerce.platform.entity.Product;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.jpa.domain.Specification;

import java.math.BigDecimal;

public class ProductSpecification {

    private ProductSpecification() {
    }

    public static Specification<Product> isActive() {
        return (root, query, cb) -> cb.isTrue(root.get("active"));
    }

    public static Specification<Product> hasCategory(Long categoryId) {
        if (categoryId == null) {
            return null;
        }
        return (root, query, cb) -> cb.equal(root.get("category").get("id"), categoryId);
    }

    public static Specification<Product> hasSeller(Long sellerId) {
        if (sellerId == null) {
            return null;
        }
        return (root, query, cb) -> cb.equal(root.get("seller").get("id"), sellerId);
    }

    public static Specification<Product> priceGreaterThanOrEqualTo(BigDecimal minPrice) {
        if (minPrice == null) {
            return null;
        }
        return (root, query, cb) -> cb.greaterThanOrEqualTo(root.get("price"), minPrice);
    }

    public static Specification<Product> priceLessThanOrEqualTo(BigDecimal maxPrice) {
        if (maxPrice == null) {
            return null;
        }
        return (root, query, cb) -> cb.lessThanOrEqualTo(root.get("price"), maxPrice);
    }

    public static Specification<Product> hasMinRating(Double minRating) {
        if (minRating == null) {
            return null;
        }
        return (root, query, cb) -> cb.greaterThanOrEqualTo(root.get("averageRating"), minRating);
    }

    public static Specification<Product> nameContains(String keyword) {
        if (keyword == null || keyword.isBlank()) {
            return null;
        }
        return (root, query, cb) -> cb.like(cb.lower(root.get("name")), "%" + keyword.toLowerCase() + "%");
    }

    /**
     * Combines every non-null specification with AND. Any filter left null
     * by the caller is simply skipped - this is what makes the filtering
     * "dynamic" instead of needing one method per filter combination.
     */
    public static Specification<Product> build(Long categoryId, Long sellerId, BigDecimal minPrice,
                                                 BigDecimal maxPrice, Double minRating, String keyword,
                                                 boolean activeOnly) {
        Specification<Product> spec = Specification.where(null);

        if (activeOnly) {
            spec = spec.and(isActive());
        }
        spec = spec.and(hasCategory(categoryId));
        spec = spec.and(hasSeller(sellerId));
        spec = spec.and(priceGreaterThanOrEqualTo(minPrice));
        spec = spec.and(priceLessThanOrEqualTo(maxPrice));
        spec = spec.and(hasMinRating(minRating));
        spec = spec.and(nameContains(keyword));

        return spec;
    }
}
