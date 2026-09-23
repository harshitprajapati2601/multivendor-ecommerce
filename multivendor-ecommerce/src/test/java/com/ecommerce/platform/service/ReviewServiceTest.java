package com.ecommerce.platform.service;

import com.ecommerce.platform.dto.ReviewRequest;
import com.ecommerce.platform.dto.ReviewResponse;
import com.ecommerce.platform.dto.UpdateReviewRequest;
import com.ecommerce.platform.entity.*;
import com.ecommerce.platform.repository.OrderItemRepository;
import com.ecommerce.platform.repository.ProductRepository;
import com.ecommerce.platform.repository.ReviewRepository;
import com.ecommerce.platform.security.SecurityUtils;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;

import java.math.BigDecimal;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ReviewServiceTest {

    @Mock private ReviewRepository reviewRepository;
    @Mock private ProductRepository productRepository;
    @Mock private OrderItemRepository orderItemRepository;
    @Mock private SecurityUtils securityUtils;

    @InjectMocks private ReviewService reviewService;

    private User customer;
    private User otherCustomer;
    private Product product;

    @BeforeEach
    void setUp() {
        customer = User.builder().id(1L).fullName("Ravi").email("ravi@test.com").role(Role.CUSTOMER).build();
        otherCustomer = User.builder().id(2L).fullName("Meera").email("meera@test.com").role(Role.CUSTOMER).build();
        product = Product.builder()
                .id(10L).name("Running Shoe").price(new BigDecimal("250.00"))
                .averageRating(0.0).build();
    }

    private ReviewRequest request(int rating) {
        ReviewRequest r = new ReviewRequest();
        r.setProductId(10L);
        r.setRating(rating);
        r.setComment("Very comfortable");
        return r;
    }

    @Test
    @DisplayName("create: a delivered purchase allows the review and refreshes averageRating")
    void create_success() {
        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(productRepository.findById(10L)).thenReturn(Optional.of(product));
        when(orderItemRepository.existsDeliveredPurchase(1L, 10L)).thenReturn(true);
        when(reviewRepository.existsByCustomerIdAndProductId(1L, 10L)).thenReturn(false);
        when(reviewRepository.save(any(Review.class))).thenAnswer(i -> {
            Review r = i.getArgument(0);
            r.setId(50L);
            return r;
        });
        when(reviewRepository.findAverageRatingByProductId(10L)).thenReturn(4.5);

        ReviewResponse response = reviewService.create(request(5));

        assertThat(response.getId()).isEqualTo(50L);
        assertThat(response.getCustomerName()).isEqualTo("Ravi");
        assertThat(product.getAverageRating()).isEqualTo(4.5);
        verify(productRepository).save(product);
    }

    @Test
    @DisplayName("create: no DELIVERED order for this product means 403")
    void create_noDeliveredPurchase() {
        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(productRepository.findById(10L)).thenReturn(Optional.of(product));
        when(orderItemRepository.existsDeliveredPurchase(1L, 10L)).thenReturn(false);

        assertThatThrownBy(() -> reviewService.create(request(5)))
                .isInstanceOf(AccessDeniedException.class)
                .hasMessageContaining("delivered");

        verify(reviewRepository, never()).save(any());
    }

    @Test
    @DisplayName("create: a second review for the same product is rejected")
    void create_duplicateReview() {
        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(productRepository.findById(10L)).thenReturn(Optional.of(product));
        when(orderItemRepository.existsDeliveredPurchase(1L, 10L)).thenReturn(true);
        when(reviewRepository.existsByCustomerIdAndProductId(1L, 10L)).thenReturn(true);

        assertThatThrownBy(() -> reviewService.create(request(4)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("already reviewed");

        verify(reviewRepository, never()).save(any());
    }

    @Test
    @DisplayName("update: another customer cannot edit someone else's review")
    void update_notOwner_denied() {
        Review review = Review.builder().id(50L).customer(customer).product(product).rating(5).build();
        when(reviewRepository.findById(50L)).thenReturn(Optional.of(review));
        when(securityUtils.getCurrentUser()).thenReturn(otherCustomer);

        UpdateReviewRequest req = new UpdateReviewRequest();
        req.setRating(1);
        req.setComment("hijacked");

        assertThatThrownBy(() -> reviewService.update(50L, req))
                .isInstanceOf(AccessDeniedException.class);

        assertThat(review.getRating()).isEqualTo(5);
        verify(reviewRepository, never()).save(any());
    }

    @Test
    @DisplayName("delete: an ADMIN may remove any review, and the average is recalculated")
    void delete_adminAllowed() {
        User admin = User.builder().id(9L).email("admin@test.com").role(Role.ADMIN).build();
        Review review = Review.builder().id(50L).customer(customer).product(product).rating(1).build();

        when(reviewRepository.findById(50L)).thenReturn(Optional.of(review));
        when(securityUtils.getCurrentUser()).thenReturn(admin);
        when(productRepository.findById(10L)).thenReturn(Optional.of(product));
        // No reviews left -> the aggregate query returns null, not 0.
        when(reviewRepository.findAverageRatingByProductId(10L)).thenReturn(null);

        reviewService.delete(50L);

        verify(reviewRepository).delete(review);
        assertThat(product.getAverageRating()).isEqualTo(0.0); // null coerced to 0.0
    }
}