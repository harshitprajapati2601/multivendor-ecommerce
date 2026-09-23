package com.ecommerce.platform.integration;

import com.ecommerce.platform.entity.*;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class OrderFlowIntegrationTest extends BaseIntegrationTest {

    private static final String OK_PAYMENT = "{\"paymentToken\":\"tok_ok\"}";
    private static final String FAIL_PAYMENT = "{\"paymentToken\":\"fail\"}";

    // ---------------- happy path ----------------

    @Test
    @DisplayName("Place order: 201, stock deducted, cart cleared, payment SUCCESS")
    void placeOrder_success() throws Exception {
        User customer = createCustomerWithCart("buyer@test.com");
        Seller seller = createSeller("seller@test.com", "Shoe Shop", true);
        Category category = createCategory("Footwear");
        Product product = createProduct(seller, category, "500.00", 10);
        addToCart(customer, product, 2);

        mockMvc.perform(post("/api/orders")
                        .header("Authorization", bearer(customer))
                        .contentType("application/json")
                        .content(OK_PAYMENT))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("PLACED"))
                .andExpect(jsonPath("$.totalAmount").value(1000.00))
                .andExpect(jsonPath("$.paymentStatus").value("SUCCESS"))
                .andExpect(jsonPath("$.items.length()").value(1));

        assertThat(stockOf(product)).isEqualTo(8);
        assertThat(cartItemRepository.count()).isZero();
        assertThat(orderRepository.count()).isEqualTo(1);
        assertThat(paymentRepository.count()).isEqualTo(1);
    }

    @Test
    @DisplayName("Place order: price is snapshotted, so a later price change does not alter history")
    void placeOrder_snapshotsPrice() throws Exception {
        User customer = createCustomerWithCart("buyer2@test.com");
        Seller seller = createSeller("seller2@test.com", "Shoe Shop", true);
        Product product = createProduct(seller, createCategory("Footwear"), "500.00", 10);
        addToCart(customer, product, 1);

        mockMvc.perform(post("/api/orders")
                        .header("Authorization", bearer(customer))
                        .contentType("application/json").content(OK_PAYMENT))
                .andExpect(status().isCreated());

        product.setPrice(new java.math.BigDecimal("9999.00"));
        productRepository.save(product);

        OrderItem item = orderItemRepository.findAll().get(0);
        assertThat(item.getPriceAtPurchase()).isEqualByComparingTo("500.00");
    }

    // ---------------- insufficient stock ----------------

    @Test
    @DisplayName("Insufficient stock: 409 Conflict, nothing deducted, no order row")
    void placeOrder_insufficientStock() throws Exception {
        User customer = createCustomerWithCart("buyer3@test.com");
        Seller seller = createSeller("seller3@test.com", "Shoe Shop", true);
        Product product = createProduct(seller, createCategory("Footwear"), "500.00", 1);
        addToCart(customer, product, 5);

        mockMvc.perform(post("/api/orders")
                        .header("Authorization", bearer(customer))
                        .contentType("application/json").content(OK_PAYMENT))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.message").value(
                        org.hamcrest.Matchers.containsString("Insufficient stock")));

        assertThat(stockOf(product)).isEqualTo(1);
        assertThat(orderRepository.count()).isZero();
        assertThat(paymentRepository.count()).isZero();
        assertThat(cartItemRepository.count()).isEqualTo(1); // cart preserved for retry
    }

    @Test
    @DisplayName("Multi-item cart: one short item rolls back the earlier item's deduction too")
    void placeOrder_partialStockFailure_rollsBackEverything() throws Exception {
        User customer = createCustomerWithCart("buyer4@test.com");
        Seller seller = createSeller("seller4@test.com", "Shoe Shop", true);
        Category category = createCategory("Footwear");

        Product plenty = createProduct(seller, category, "100.00", 50);
        Product scarce = createProduct(seller, category, "200.00", 1);

        addToCart(customer, plenty, 2);   // would succeed on its own
        addToCart(customer, scarce, 10);  // fails

        mockMvc.perform(post("/api/orders")
                        .header("Authorization", bearer(customer))
                        .contentType("application/json").content(OK_PAYMENT))
                .andExpect(status().isConflict());

        // The whole transaction unwound - the first product's stock is intact.
        assertThat(stockOf(plenty)).isEqualTo(50);
        assertThat(stockOf(scarce)).isEqualTo(1);
        assertThat(orderRepository.count()).isZero();
    }

    @Test
    @DisplayName("Empty cart: 400 Bad Request")
    void placeOrder_emptyCart() throws Exception {
        User customer = createCustomerWithCart("buyer5@test.com");

        mockMvc.perform(post("/api/orders")
                        .header("Authorization", bearer(customer))
                        .contentType("application/json").content(OK_PAYMENT))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(
                        org.hamcrest.Matchers.containsString("empty cart")));
    }

    // ---------------- payment rollback ----------------

    @Test
    @DisplayName("PAYMENT ROLLBACK: declined card returns 402 and every stock deduction is undone")
    void placeOrder_paymentFailure_rollsBackStock() throws Exception {
        User customer = createCustomerWithCart("buyer6@test.com");
        Seller seller = createSeller("seller6@test.com", "Shoe Shop", true);
        Product product = createProduct(seller, createCategory("Footwear"), "500.00", 10);
        addToCart(customer, product, 3);

        mockMvc.perform(post("/api/orders")
                        .header("Authorization", bearer(customer))
                        .contentType("application/json").content(FAIL_PAYMENT))
                .andExpect(status().isPaymentRequired())
                .andExpect(jsonPath("$.status").value(402))
                .andExpect(jsonPath("$.message").value(
                        org.hamcrest.Matchers.containsString("Card declined")));

        // The heart of the test: stock is back at 10, nothing was committed.
        assertThat(stockOf(product)).isEqualTo(10);
        assertThat(orderRepository.count()).isZero();
        assertThat(orderItemRepository.count()).isZero();
        assertThat(paymentRepository.count()).isZero();
        assertThat(cartItemRepository.count()).isEqualTo(1);
    }

    @Test
    @DisplayName("A retry after a declined payment succeeds, since nothing was consumed")
    void placeOrder_retryAfterPaymentFailure_succeeds() throws Exception {
        User customer = createCustomerWithCart("buyer7@test.com");
        Seller seller = createSeller("seller7@test.com", "Shoe Shop", true);
        Product product = createProduct(seller, createCategory("Footwear"), "500.00", 10);
        addToCart(customer, product, 3);

        mockMvc.perform(post("/api/orders")
                        .header("Authorization", bearer(customer))
                        .contentType("application/json").content(FAIL_PAYMENT))
                .andExpect(status().isPaymentRequired());

        mockMvc.perform(post("/api/orders")
                        .header("Authorization", bearer(customer))
                        .contentType("application/json").content(OK_PAYMENT))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.paymentStatus").value("SUCCESS"));

        assertThat(stockOf(product)).isEqualTo(7);
        assertThat(orderRepository.count()).isEqualTo(1);
    }

    // ---------------- state machine over HTTP ----------------

    @Test
    @DisplayName("PLACED -> SHIPPED -> DELIVERED works, then the order is terminal")
    void statusTransitions_fullLifecycle() throws Exception {
        User customer = createCustomerWithCart("buyer8@test.com");
        User admin = createUser("admin@test.com", Role.ADMIN);
        Seller seller = createSeller("seller8@test.com", "Shoe Shop", true);
        Product product = createProduct(seller, createCategory("Footwear"), "500.00", 10);
        addToCart(customer, product, 1);

        Long orderId = placeOrderAndGetId(customer);

        mockMvc.perform(patch("/api/orders/{id}/ship", orderId)
                        .header("Authorization", bearer(admin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SHIPPED"));

        mockMvc.perform(patch("/api/orders/{id}/deliver", orderId)
                        .header("Authorization", bearer(admin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("DELIVERED"));

        // DELIVERED is terminal - cancelling is a 409, not a 200.
        mockMvc.perform(patch("/api/orders/{id}/cancel", orderId)
                        .header("Authorization", bearer(customer)))
                .andExpect(status().isConflict());
    }

    @Test
    @DisplayName("Skipping SHIPPED (PLACED -> DELIVERED) is rejected with 409")
    void statusTransitions_cannotSkipShipped() throws Exception {
        User customer = createCustomerWithCart("buyer9@test.com");
        User admin = createUser("admin2@test.com", Role.ADMIN);
        Seller seller = createSeller("seller9@test.com", "Shoe Shop", true);
        Product product = createProduct(seller, createCategory("Footwear"), "500.00", 10);
        addToCart(customer, product, 1);

        Long orderId = placeOrderAndGetId(customer);

        mockMvc.perform(patch("/api/orders/{id}/deliver", orderId)
                        .header("Authorization", bearer(admin)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.message").value(
                        org.hamcrest.Matchers.containsString("Cannot move order")));
    }

    @Test
    @DisplayName("Cancel: stock is restored and the payment flips to REFUNDED")
    void cancelOrder_restoresStockAndRefunds() throws Exception {
        User customer = createCustomerWithCart("buyer10@test.com");
        Seller seller = createSeller("seller10@test.com", "Shoe Shop", true);
        Product product = createProduct(seller, createCategory("Footwear"), "500.00", 10);
        addToCart(customer, product, 4);

        Long orderId = placeOrderAndGetId(customer);
        assertThat(stockOf(product)).isEqualTo(6);

        mockMvc.perform(patch("/api/orders/{id}/cancel", orderId)
                        .header("Authorization", bearer(customer)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"))
                .andExpect(jsonPath("$.paymentStatus").value("REFUNDED"));

        assertThat(stockOf(product)).isEqualTo(10);
    }

    @Test
    @DisplayName("A SELLER cannot ship an order (ADMIN-only endpoint)")
    void ship_sellerForbidden() throws Exception {
        User customer = createCustomerWithCart("buyer11@test.com");
        Seller seller = createSeller("seller11@test.com", "Shoe Shop", true);
        Product product = createProduct(seller, createCategory("Footwear"), "500.00", 10);
        addToCart(customer, product, 1);

        Long orderId = placeOrderAndGetId(customer);

        mockMvc.perform(patch("/api/orders/{id}/ship", orderId)
                        .header("Authorization", bearer(seller.getUser())))
                .andExpect(status().isForbidden());
    }

    // ---------------- helper ----------------

    private Long placeOrderAndGetId(User customer) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/orders")
                        .header("Authorization", bearer(customer))
                        .contentType("application/json").content(OK_PAYMENT))
                .andExpect(status().isCreated())
                .andReturn();

        JsonNode body = objectMapper.readTree(result.getResponse().getContentAsString());
        return body.get("id").asLong();
    }
}