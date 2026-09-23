package com.ecommerce.platform.service;

import com.ecommerce.platform.dto.OrderResponse;
import com.ecommerce.platform.entity.*;
import com.ecommerce.platform.exception.InvalidOrderStateException;
import com.ecommerce.platform.exception.PaymentFailedException;
import com.ecommerce.platform.exception.ResourceNotFoundException;
import com.ecommerce.platform.repository.CartRepository;
import com.ecommerce.platform.repository.OrderRepository;
import com.ecommerce.platform.repository.PaymentRepository;
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
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock private OrderRepository orderRepository;
    @Mock private CartRepository cartRepository;
    @Mock private InventoryService inventoryService;
    @Mock private SecurityUtils securityUtils;
    @Mock private MockPaymentGatewayService paymentGatewayService;
    @Mock private PaymentRepository paymentRepository;

    @InjectMocks private OrderService orderService;

    private User customer;
    private User otherCustomer;
    private Product product;
    private Cart cart;

    @BeforeEach
    void setUp() {
        customer = User.builder().id(1L).email("buyer@test.com").role(Role.CUSTOMER).build();
        otherCustomer = User.builder().id(2L).email("other@test.com").role(Role.CUSTOMER).build();

        product = Product.builder()
                .id(10L).name("Running Shoe").price(new BigDecimal("500.00")).build();

        CartItem item = CartItem.builder().id(1L).product(product).quantity(2).build();
        cart = Cart.builder().id(5L).user(customer).items(new ArrayList<>(List.of(item))).build();
    }

    // ---------------- placeOrder ----------------

    @Test
    @DisplayName("placeOrder: deducts stock, charges the gateway, saves order + payment, clears cart")
    void placeOrder_happyPath() {
        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(cartRepository.findByUserId(1L)).thenReturn(Optional.of(cart));
        when(paymentGatewayService.charge(any(BigDecimal.class), eq("tok_ok")))
                .thenReturn(new PaymentGatewayResult(true, "MOCK-123", "Payment approved"));
        when(orderRepository.save(any(Order.class))).thenAnswer(i -> {
            Order o = i.getArgument(0);
            o.setId(77L);
            return o;
        });
        when(paymentRepository.findByOrderId(77L)).thenReturn(Optional.empty());

        OrderResponse response = orderService.placeOrder("tok_ok");

        // 2 units x 500.00
        assertThat(response.getTotalAmount()).isEqualByComparingTo("1000.00");
        assertThat(response.getStatus()).isEqualTo(OrderStatus.PLACED);
        assertThat(response.getItems()).hasSize(1);
        assertThat(response.getItems().get(0).getPriceAtPurchase()).isEqualByComparingTo("500.00");

        verify(inventoryService).deductStock(10L, 2);
        verify(paymentRepository).save(any(Payment.class));
        assertThat(cart.getItems()).isEmpty();   // cart emptied
        verify(cartRepository).save(cart);
    }

    @Test
    @DisplayName("placeOrder: payment decline throws PaymentFailedException and never persists an order")
    void placeOrder_paymentFailed() {
        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(cartRepository.findByUserId(1L)).thenReturn(Optional.of(cart));
        when(paymentGatewayService.charge(any(BigDecimal.class), eq("fail")))
                .thenReturn(new PaymentGatewayResult(false, null, "Card declined by issuing bank"));

        assertThatThrownBy(() -> orderService.placeOrder("fail"))
                .isInstanceOf(PaymentFailedException.class)
                .hasMessageContaining("Card declined");

        // Stock WAS deducted in-memory, but nothing was committed. In the real
        // app @Transactional rolls that deduction back - proven in
        // OrderFlowIntegrationTest, which checks the DB after the call.
        verify(inventoryService).deductStock(10L, 2);
        verify(orderRepository, never()).save(any(Order.class));
        verify(paymentRepository, never()).save(any(Payment.class));
        verify(cartRepository, never()).save(any(Cart.class));
        assertThat(cart.getItems()).hasSize(1); // cart untouched, customer can retry
    }

    @Test
    @DisplayName("placeOrder: stock failure aborts before the gateway is ever called")
    void placeOrder_insufficientStock_doesNotCharge() {
        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(cartRepository.findByUserId(1L)).thenReturn(Optional.of(cart));
        doThrow(new com.ecommerce.platform.exception.InsufficientStockException("Insufficient stock"))
                .when(inventoryService).deductStock(10L, 2);

        assertThatThrownBy(() -> orderService.placeOrder("tok_ok"))
                .isInstanceOf(com.ecommerce.platform.exception.InsufficientStockException.class);

        // Critical: never charge a customer for an order we cannot fulfil.
        verify(paymentGatewayService, never()).charge(any(), any());
        verify(orderRepository, never()).save(any(Order.class));
    }

    @Test
    @DisplayName("placeOrder: empty cart is rejected as a 400-level IllegalStateException")
    void placeOrder_emptyCart() {
        cart.getItems().clear();
        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(cartRepository.findByUserId(1L)).thenReturn(Optional.of(cart));

        assertThatThrownBy(() -> orderService.placeOrder(null))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("empty cart");

        verifyNoInteractions(paymentGatewayService);
    }

    @Test
    @DisplayName("placeOrder: missing cart throws ResourceNotFoundException")
    void placeOrder_noCart() {
        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(cartRepository.findByUserId(1L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> orderService.placeOrder(null))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    // ---------------- state machine ----------------

    @Test
    @DisplayName("ship: PLACED -> SHIPPED is a legal transition")
    void ship_fromPlaced() {
        Order order = orderOf(customer, OrderStatus.PLACED);
        when(orderRepository.findById(77L)).thenReturn(Optional.of(order));
        when(orderRepository.save(order)).thenReturn(order);
        when(paymentRepository.findByOrderId(77L)).thenReturn(Optional.empty());

        assertThat(orderService.ship(77L).getStatus()).isEqualTo(OrderStatus.SHIPPED);
    }

    @Test
    @DisplayName("deliver: SHIPPED -> DELIVERED is legal")
    void deliver_fromShipped() {
        Order order = orderOf(customer, OrderStatus.SHIPPED);
        when(orderRepository.findById(77L)).thenReturn(Optional.of(order));
        when(orderRepository.save(order)).thenReturn(order);
        when(paymentRepository.findByOrderId(77L)).thenReturn(Optional.empty());

        assertThat(orderService.deliver(77L).getStatus()).isEqualTo(OrderStatus.DELIVERED);
    }

    @Test
    @DisplayName("deliver: PLACED -> DELIVERED is illegal (must ship first)")
    void deliver_fromPlaced_rejected() {
        Order order = orderOf(customer, OrderStatus.PLACED);
        when(orderRepository.findById(77L)).thenReturn(Optional.of(order));

        assertThatThrownBy(() -> orderService.deliver(77L))
                .isInstanceOf(InvalidOrderStateException.class)
                .hasMessageContaining("PLACED")
                .hasMessageContaining("DELIVERED");

        verify(orderRepository, never()).save(any());
    }

    @Test
    @DisplayName("cancel: DELIVERED is terminal, cannot be cancelled")
    void cancel_deliveredIsTerminal() {
        Order order = orderOf(customer, OrderStatus.DELIVERED);
        when(orderRepository.findById(77L)).thenReturn(Optional.of(order));
        when(securityUtils.getCurrentUser()).thenReturn(customer);

        assertThatThrownBy(() -> orderService.cancel(77L))
                .isInstanceOf(InvalidOrderStateException.class);

        verify(inventoryService, never()).restoreStock(anyLong(), anyInt());
    }

    @Test
    @DisplayName("cancel: restores stock for every item and marks the payment REFUNDED")
    void cancel_restoresStockAndRefunds() {
        Order order = orderOf(customer, OrderStatus.PLACED);
        Payment payment = Payment.builder()
                .id(1L).order(order).amount(new BigDecimal("1000.00"))
                .status(PaymentStatus.SUCCESS).transactionId("MOCK-123").build();

        when(orderRepository.findById(77L)).thenReturn(Optional.of(order));
        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(orderRepository.save(order)).thenReturn(order);
        when(paymentRepository.findByOrderId(77L)).thenReturn(Optional.of(payment));

        OrderResponse response = orderService.cancel(77L);

        assertThat(response.getStatus()).isEqualTo(OrderStatus.CANCELLED);
        verify(inventoryService).restoreStock(10L, 2);
        assertThat(payment.getStatus()).isEqualTo(PaymentStatus.REFUNDED);
        verify(paymentRepository).save(payment);
    }

    // ---------------- ownership ----------------

    @Test
    @DisplayName("getById: another customer's order is 403, not 404 leakage")
    void getById_otherCustomersOrder_denied() {
        Order order = orderOf(customer, OrderStatus.PLACED);
        when(orderRepository.findById(77L)).thenReturn(Optional.of(order));
        when(securityUtils.getCurrentUser()).thenReturn(otherCustomer);

        assertThatThrownBy(() -> orderService.getById(77L))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    @DisplayName("getById: an ADMIN may read anyone's order")
    void getById_adminAllowed() {
        Order order = orderOf(customer, OrderStatus.PLACED);
        User admin = User.builder().id(9L).email("admin@test.com").role(Role.ADMIN).build();

        when(orderRepository.findById(77L)).thenReturn(Optional.of(order));
        when(securityUtils.getCurrentUser()).thenReturn(admin);
        when(paymentRepository.findByOrderId(77L)).thenReturn(Optional.empty());

        assertThat(orderService.getById(77L).getId()).isEqualTo(77L);
    }

    @Test
    @DisplayName("cancel: another customer cannot cancel someone else's order")
    void cancel_otherCustomer_denied() {
        Order order = orderOf(customer, OrderStatus.PLACED);
        when(orderRepository.findById(77L)).thenReturn(Optional.of(order));
        when(securityUtils.getCurrentUser()).thenReturn(otherCustomer);

        assertThatThrownBy(() -> orderService.cancel(77L))
                .isInstanceOf(AccessDeniedException.class);

        verify(inventoryService, never()).restoreStock(anyLong(), anyInt());
    }

    // ---------------- helper ----------------

    private Order orderOf(User owner, OrderStatus status) {
        Order order = Order.builder()
                .id(77L).customer(owner).status(status)
                .totalAmount(new BigDecimal("1000.00"))
                .items(new ArrayList<>())
                .build();
        order.getItems().add(OrderItem.builder()
                .id(1L).order(order).product(product)
                .quantity(2).priceAtPurchase(new BigDecimal("500.00"))
                .build());
        return order;
    }
}