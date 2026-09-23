package com.ecommerce.platform.service;

import com.ecommerce.platform.dto.OrderItemResponse;
import com.ecommerce.platform.dto.OrderResponse;
import com.ecommerce.platform.entity.*;
import com.ecommerce.platform.exception.InvalidOrderStateException;
import com.ecommerce.platform.exception.PaymentFailedException;
import com.ecommerce.platform.exception.ResourceNotFoundException;
import com.ecommerce.platform.repository.CartRepository;
import com.ecommerce.platform.repository.OrderRepository;
import com.ecommerce.platform.repository.PaymentRepository;
import com.ecommerce.platform.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final CartRepository cartRepository;
    private final InventoryService inventoryService;
    private final SecurityUtils securityUtils;
    private final MockPaymentGatewayService paymentGatewayService;
    private final PaymentRepository paymentRepository;

    // Day 17: the order status state machine. Every key is a "from" state,
    // mapped to the set of states it may legally move to. Anything not
    // listed here (e.g. DELIVERED -> anything) is terminal.
    private static final Map<OrderStatus, EnumSet<OrderStatus>> VALID_TRANSITIONS = Map.of(
            OrderStatus.PLACED, EnumSet.of(OrderStatus.SHIPPED, OrderStatus.CANCELLED),
            OrderStatus.SHIPPED, EnumSet.of(OrderStatus.DELIVERED),
            OrderStatus.DELIVERED, EnumSet.noneOf(OrderStatus.class),
            OrderStatus.CANCELLED, EnumSet.noneOf(OrderStatus.class)
    );

    // ---------- Place order (Days 15-16) ----------

    @Transactional
    public OrderResponse placeOrder(String paymentToken) {
        User customer = securityUtils.getCurrentUser();
        Cart cart = cartRepository.findByUserId(customer.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Cart not found for this user"));

        if (cart.getItems().isEmpty()) {
            throw new IllegalStateException("Cannot place an order from an empty cart");
        }

        List<OrderItem> orderItems = new ArrayList<>();
        BigDecimal total = BigDecimal.ZERO;

        Order order = Order.builder()
                .customer(customer)
                .status(OrderStatus.PLACED)
                .build();

        // Deduct stock item-by-item. If ANY item fails (insufficient stock or
        // a concurrent order wins the race on the @Version column), the
        // exception propagates, @Transactional rolls back everything already
        // deducted in this loop, and the cart is left untouched. Nothing is
        // partially applied (Day 16 & 18).
        for (CartItem cartItem : cart.getItems()) {
            Product product = cartItem.getProduct();
            inventoryService.deductStock(product.getId(), cartItem.getQuantity());

            BigDecimal subtotal = product.getPrice().multiply(BigDecimal.valueOf(cartItem.getQuantity()));
            total = total.add(subtotal);

            orderItems.add(OrderItem.builder()
                    .order(order)
                    .product(product)
                    .quantity(cartItem.getQuantity())
                    .priceAtPurchase(product.getPrice())
                    .build());
        }

        // Day 19-20: charge before persisting anything. If the gateway
        // declines, we throw here - the @Transactional rollback undoes every
        // stock deduction flushed above and no Order/Payment row is ever
        // committed. The customer's cart is untouched, so they can just retry.
        PaymentGatewayResult result = paymentGatewayService.charge(total, paymentToken);
        if (!result.success()) {
            throw new PaymentFailedException("Payment failed: " + result.message());
        }

        order.setItems(orderItems);
        order.setTotalAmount(total);
        order = orderRepository.save(order); // cascades to OrderItems

        Payment payment = Payment.builder()
                .order(order)
                .amount(total)
                .status(PaymentStatus.SUCCESS)
                .transactionId(result.transactionId())
                .build();
        paymentRepository.save(payment);

        cart.getItems().clear(); // orphanRemoval=true deletes the old CartItem rows
        cartRepository.save(cart);

        return toResponse(order);
    }

    // ---------- Read (Day 15) ----------

    @Transactional(readOnly = true)
    public Page<OrderResponse> getMyOrders(Pageable pageable) {
        User customer = securityUtils.getCurrentUser();
        return orderRepository.findByCustomerId(customer.getId(), pageable).map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public Page<OrderResponse> getAllOrders(OrderStatus status, Pageable pageable) {
        if (status != null) {
            return orderRepository.findByStatus(status, pageable).map(this::toResponse);
        }
        return orderRepository.findAll(pageable).map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public OrderResponse getById(Long id) {
        Order order = getOrderOrThrow(id);
        assertOwnershipOrAdmin(order);
        return toResponse(order);
    }

    // ---------- State machine transitions (Day 17) ----------

    @Transactional
    public OrderResponse ship(Long id) {
        Order order = getOrderOrThrow(id);
        transitionTo(order, OrderStatus.SHIPPED);
        return toResponse(orderRepository.save(order));
    }

    @Transactional
    public OrderResponse deliver(Long id) {
        Order order = getOrderOrThrow(id);
        transitionTo(order, OrderStatus.DELIVERED);
        return toResponse(orderRepository.save(order));
    }

    @Transactional
    public OrderResponse cancel(Long id) {
        Order order = getOrderOrThrow(id);
        assertOwnershipOrAdmin(order);
        transitionTo(order, OrderStatus.CANCELLED);

        // Compensate: return every item's quantity back to inventory.
        for (OrderItem item : order.getItems()) {
            inventoryService.restoreStock(item.getProduct().getId(), item.getQuantity());
        }

        paymentRepository.findByOrderId(order.getId()).ifPresent(payment -> {
            payment.setStatus(PaymentStatus.REFUNDED);
            paymentRepository.save(payment);
        });

        return toResponse(orderRepository.save(order));
    }

    private void transitionTo(Order order, OrderStatus target) {
        OrderStatus current = order.getStatus();
        EnumSet<OrderStatus> allowed = VALID_TRANSITIONS.getOrDefault(current, EnumSet.noneOf(OrderStatus.class));

        if (!allowed.contains(target)) {
            throw new InvalidOrderStateException(
                    "Cannot move order from " + current + " to " + target);
        }
        order.setStatus(target);
    }

    // ---------- Helpers ----------

    private Order getOrderOrThrow(Long id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Order not found with id: " + id));
    }

    private void assertOwnershipOrAdmin(Order order) {
        User current = securityUtils.getCurrentUser();
        boolean isOwner = order.getCustomer().getId().equals(current.getId());
        boolean isAdmin = current.getRole() == Role.ADMIN;
        if (!isOwner && !isAdmin) {
            throw new AccessDeniedException("You do not have access to this order");
        }
    }

    private OrderResponse toResponse(Order order) {
        List<OrderItemResponse> items = order.getItems().stream()
                .map(item -> OrderItemResponse.builder()
                        .productId(item.getProduct().getId())
                        .productName(item.getProduct().getName())
                        .quantity(item.getQuantity())
                        .priceAtPurchase(item.getPriceAtPurchase())
                        .subtotal(item.getPriceAtPurchase().multiply(BigDecimal.valueOf(item.getQuantity())))
                        .build())
                .toList();

        Payment payment = paymentRepository.findByOrderId(order.getId()).orElse(null);

        return OrderResponse.builder()
                .id(order.getId())
                .customerId(order.getCustomer() != null ? order.getCustomer().getId() : null)
                .customerName(order.getCustomer() != null ? order.getCustomer().getFullName() : null)
                .customerEmail(order.getCustomer() != null ? order.getCustomer().getEmail() : null)
                .status(order.getStatus())
                .totalAmount(order.getTotalAmount())
                .items(items)
                .paymentStatus(payment != null ? payment.getStatus() : null)
                .paymentTransactionId(payment != null ? payment.getTransactionId() : null)
                .createdAt(order.getCreatedAt())
                .updatedAt(order.getUpdatedAt())
                .build();
    }
}
