package com.ecommerce.platform.service;

import com.ecommerce.platform.dto.ReviewRequest;
import com.ecommerce.platform.dto.ReviewResponse;
import com.ecommerce.platform.dto.UpdateReviewRequest;
import com.ecommerce.platform.entity.Product;
import com.ecommerce.platform.entity.Review;
import com.ecommerce.platform.entity.Role;
import com.ecommerce.platform.entity.User;
import com.ecommerce.platform.exception.ResourceNotFoundException;
import com.ecommerce.platform.repository.OrderItemRepository;
import com.ecommerce.platform.repository.ProductRepository;
import com.ecommerce.platform.repository.ReviewRepository;
import com.ecommerce.platform.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ReviewService {

    private final ReviewRepository reviewRepository;
    private final ProductRepository productRepository;
    private final OrderItemRepository orderItemRepository;
    private final SecurityUtils securityUtils;

    @Transactional(readOnly = true)
    public Page<ReviewResponse> getByProduct(Long productId, Pageable pageable) {
        return reviewRepository.findByProductId(productId, pageable)
                .map(this::toResponse);
    }

    @Transactional
    public ReviewResponse create(ReviewRequest request) {
        User customer = securityUtils.getCurrentUser();
        Product product = productRepository.findById(request.getProductId())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Product not found with id: " + request.getProductId()));

        if (!orderItemRepository.existsDeliveredPurchase(customer.getId(), product.getId())) {
            throw new AccessDeniedException(
                    "You can only review products from orders that have been delivered to you");
        }

        if (reviewRepository.existsByCustomerIdAndProductId(customer.getId(), product.getId())) {
            throw new IllegalStateException("You have already reviewed this product");
        }

        Review review = Review.builder()
                .customer(customer)
                .product(product)
                .rating(request.getRating())
                .comment(request.getComment())
                .build();
        review = reviewRepository.save(review);

        recalculateAverageRating(product.getId());

        return toResponse(review);
    }

    @Transactional
    public ReviewResponse update(Long id, UpdateReviewRequest request) {
        Review review = getReviewOrThrow(id);
        assertOwner(review);

        review.setRating(request.getRating());
        review.setComment(request.getComment());
        review = reviewRepository.save(review);

        recalculateAverageRating(review.getProduct().getId());

        return toResponse(review);
    }

    @Transactional
    public void delete(Long id) {
        Review review = getReviewOrThrow(id);
        assertOwnerOrAdmin(review);

        Long productId = review.getProduct().getId();
        reviewRepository.delete(review);

        recalculateAverageRating(productId);
    }

    private void recalculateAverageRating(Long productId) {
        Double avg = reviewRepository.findAverageRatingByProductId(productId);
        Product product = productRepository.findById(productId)
                .orElseThrow(() -> new ResourceNotFoundException("Product not found with id: " + productId));
        product.setAverageRating(avg != null ? avg : 0.0);
        productRepository.save(product);
    }

    private Review getReviewOrThrow(Long id) {
        return reviewRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Review not found with id: " + id));
    }

    private void assertOwner(Review review) {
        User current = securityUtils.getCurrentUser();
        if (!review.getCustomer().getId().equals(current.getId())) {
            throw new AccessDeniedException("You can only edit your own review");
        }
    }

    private void assertOwnerOrAdmin(Review review) {
        User current = securityUtils.getCurrentUser();
        boolean isOwner = review.getCustomer().getId().equals(current.getId());
        boolean isAdmin = current.getRole() == Role.ADMIN;
        if (!isOwner && !isAdmin) {
            throw new AccessDeniedException("You can only delete your own review");
        }
    }

    private ReviewResponse toResponse(Review review) {
        return ReviewResponse.builder()
                .id(review.getId())
                .productId(review.getProduct().getId())
                .customerId(review.getCustomer().getId())
                .customerName(review.getCustomer().getFullName())
                .rating(review.getRating())
                .comment(review.getComment())
                .createdAt(review.getCreatedAt())
                .build();
    }
}
