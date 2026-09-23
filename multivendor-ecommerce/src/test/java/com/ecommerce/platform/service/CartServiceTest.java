package com.ecommerce.platform.service;

import com.ecommerce.platform.dto.CartResponse;
import com.ecommerce.platform.entity.*;
import com.ecommerce.platform.exception.ResourceNotFoundException;
import com.ecommerce.platform.repository.CartItemRepository;
import com.ecommerce.platform.repository.CartRepository;
import com.ecommerce.platform.repository.ProductRepository;
import com.ecommerce.platform.security.SecurityUtils;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CartServiceTest {

    @Mock private CartRepository cartRepository;
    @Mock private CartItemRepository cartItemRepository;
    @Mock private ProductRepository productRepository;
    @Mock private SecurityUtils securityUtils;

    @InjectMocks private CartService cartService;

    private User customer;
    private Product product;
    private Cart cart;

    @BeforeEach
    void setUp() {
        customer = User.builder().id(1L).email("buyer@test.com").role(Role.CUSTOMER).build();
        product = Product.builder()
                .id(10L).name("Running Shoe").price(new BigDecimal("250.00")).active(true).build();
        cart = Cart.builder().id(5L).user(customer).items(new ArrayList<>()).build();
    }

    @Test
    @DisplayName("addItem: a new product is inserted as a fresh CartItem")
    void addItem_newProduct() {
        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(cartRepository.findByUserId(1L)).thenReturn(Optional.of(cart));
        when(productRepository.findById(10L)).thenReturn(Optional.of(product));
        when(cartItemRepository.findByCartIdAndProductId(5L, 10L)).thenReturn(Optional.empty());
        when(cartItemRepository.save(any(CartItem.class))).thenAnswer(i -> {
            CartItem saved = i.getArgument(0);
            cart.getItems().add(saved); // simulate the JPA flush
            return saved;
        });

        CartResponse response = cartService.addItem(10L, 3);

        assertThat(response.getItems()).hasSize(1);
        assertThat(response.getTotalAmount()).isEqualByComparingTo("750.00");
    }

    @Test
    @DisplayName("addItem: adding the same product again increments the existing quantity")
    void addItem_existingProductIncrements() {
        CartItem existing = CartItem.builder().id(1L).cart(cart).product(product).quantity(2).build();
        cart.setItems(new ArrayList<>(List.of(existing)));

        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(cartRepository.findByUserId(1L)).thenReturn(Optional.of(cart));
        when(productRepository.findById(10L)).thenReturn(Optional.of(product));
        when(cartItemRepository.findByCartIdAndProductId(5L, 10L)).thenReturn(Optional.of(existing));
        when(cartItemRepository.save(existing)).thenReturn(existing);

        CartResponse response = cartService.addItem(10L, 3);

        assertThat(existing.getQuantity()).isEqualTo(5);
        assertThat(response.getItems()).hasSize(1);
        assertThat(response.getTotalAmount()).isEqualByComparingTo("1250.00");
    }

    @Test
    @DisplayName("addItem: a deactivated (soft-deleted) product cannot be added")
    void addItem_inactiveProductRejected() {
        product.setActive(false);
        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(cartRepository.findByUserId(1L)).thenReturn(Optional.of(cart));
        when(productRepository.findById(10L)).thenReturn(Optional.of(product));

        assertThatThrownBy(() -> cartService.addItem(10L, 1))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("no longer available");

        verify(cartItemRepository, never()).save(any());
    }

    @Test
    @DisplayName("addItem: unknown productId is a 404")
    void addItem_productNotFound() {
        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(cartRepository.findByUserId(1L)).thenReturn(Optional.of(cart));
        when(productRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> cartService.addItem(99L, 1))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    @DisplayName("updateItem: overwrites the quantity instead of adding to it")
    void updateItem_overwritesQuantity() {
        CartItem existing = CartItem.builder().id(1L).cart(cart).product(product).quantity(9).build();
        cart.setItems(new ArrayList<>(List.of(existing)));

        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(cartRepository.findByUserId(1L)).thenReturn(Optional.of(cart));
        when(cartItemRepository.findByCartIdAndProductId(5L, 10L)).thenReturn(Optional.of(existing));
        when(cartItemRepository.save(existing)).thenReturn(existing);

        cartService.updateItem(10L, 2);

        assertThat(existing.getQuantity()).isEqualTo(2);
    }

    @Test
    @DisplayName("removeItem: a product that is not in the cart is a 404")
    void removeItem_notInCart() {
        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(cartRepository.findByUserId(1L)).thenReturn(Optional.of(cart));
        when(cartItemRepository.findByCartIdAndProductId(5L, 10L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> cartService.removeItem(10L))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("not in your cart");
    }

    @Test
    @DisplayName("clearCart: empties the item list and saves the cart")
    void clearCart_success() {
        cart.setItems(new ArrayList<>(List.of(
                CartItem.builder().id(1L).cart(cart).product(product).quantity(2).build())));

        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(cartRepository.findByUserId(1L)).thenReturn(Optional.of(cart));

        cartService.clearCart();

        assertThat(cart.getItems()).isEmpty();
        verify(cartRepository).save(cart);
    }
}