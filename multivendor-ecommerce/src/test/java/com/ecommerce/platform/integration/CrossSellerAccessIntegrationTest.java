package com.ecommerce.platform.integration;

import com.ecommerce.platform.entity.*;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Multi-tenancy is the whole point of a marketplace: having a valid SELLER
 * token must never be enough to touch another seller's data.
 */
class CrossSellerAccessIntegrationTest extends BaseIntegrationTest {

    private Seller sellerA;
    private Seller sellerB;
    private Product productOfA;

    @BeforeEach
    void seedTwoSellers() {
        Category category = createCategory("Footwear");
        sellerA = createSeller("a@shop.com", "Shop A", true);
        sellerB = createSeller("b@shop.com", "Shop B", true);
        productOfA = createProduct(sellerA, category, "500.00", 20);
    }

    private String productPayload() {
        return """
                {"name":"Hijacked Product","description":"x","price":1.00,"categoryId":%d}
                """.formatted(productOfA.getCategory().getId());
    }

    @Test
    @DisplayName("Seller B cannot UPDATE seller A's product")
    void updateOtherSellersProduct_forbidden() throws Exception {
        mockMvc.perform(put("/api/products/{id}", productOfA.getId())
                        .header("Authorization", bearer(sellerB.getUser()))
                        .contentType("application/json")
                        .content(productPayload()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403));

        assertThat(productRepository.findById(productOfA.getId()).orElseThrow().getName())
                .isNotEqualTo("Hijacked Product");
    }

    @Test
    @DisplayName("Seller B cannot DEACTIVATE seller A's product")
    void deactivateOtherSellersProduct_forbidden() throws Exception {
        mockMvc.perform(delete("/api/products/{id}", productOfA.getId())
                        .header("Authorization", bearer(sellerB.getUser())))
                .andExpect(status().isForbidden());

        assertThat(productRepository.findById(productOfA.getId()).orElseThrow().isActive()).isTrue();
    }

    @Test
    @DisplayName("Seller B cannot READ seller A's inventory levels")
    void readOtherSellersInventory_forbidden() throws Exception {
        mockMvc.perform(get("/api/products/{id}/inventory", productOfA.getId())
                        .header("Authorization", bearer(sellerB.getUser())))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Seller B cannot RESTOCK seller A's product")
    void restockOtherSellersProduct_forbidden() throws Exception {
        mockMvc.perform(patch("/api/products/{id}/inventory/restock", productOfA.getId())
                        .header("Authorization", bearer(sellerB.getUser()))
                        .contentType("application/json")
                        .content("{\"quantity\":500}"))
                .andExpect(status().isForbidden());

        assertThat(stockOf(productOfA)).isEqualTo(20);
    }

    @Test
    @DisplayName("Seller A CAN manage its own product and inventory")
    void ownerCanManageOwnProduct() throws Exception {
        mockMvc.perform(get("/api/products/{id}/inventory", productOfA.getId())
                        .header("Authorization", bearer(sellerA.getUser())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stockQuantity").value(20));

        mockMvc.perform(patch("/api/products/{id}/inventory/restock", productOfA.getId())
                        .header("Authorization", bearer(sellerA.getUser()))
                        .contentType("application/json")
                        .content("{\"quantity\":5}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stockQuantity").value(25));
    }

    @Test
    @DisplayName("my-products is scoped: seller B's listing never contains seller A's items")
    void myProducts_isScopedToOwnSeller() throws Exception {
        mockMvc.perform(get("/api/products/my-products")
                        .header("Authorization", bearer(sellerB.getUser())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(0));

        mockMvc.perform(get("/api/products/my-products")
                        .header("Authorization", bearer(sellerA.getUser())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    @DisplayName("An unapproved seller cannot create products")
    void unapprovedSeller_cannotCreateProduct() throws Exception {
        Seller pending = createSeller("pending@shop.com", "Pending Shop", false);

        mockMvc.perform(post("/api/products")
                        .header("Authorization", bearer(pending.getUser()))
                        .contentType("application/json")
                        .content(productPayload()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.message").value(
                        org.hamcrest.Matchers.containsString("pending admin approval")));
    }

    @Test
    @DisplayName("Customer B cannot read customer A's order")
    void readAnotherCustomersOrder_forbidden() throws Exception {
        User customerA = createCustomerWithCart("ca@test.com");
        User customerB = createCustomerWithCart("cb@test.com");
        addToCart(customerA, productOfA, 1);

        MvcResult result = mockMvc.perform(post("/api/orders")
                        .header("Authorization", bearer(customerA))
                        .contentType("application/json")
                        .content("{\"paymentToken\":\"tok_ok\"}"))
                .andExpect(status().isCreated())
                .andReturn();

        JsonNode body = objectMapper.readTree(result.getResponse().getContentAsString());
        long orderId = body.get("id").asLong();

        mockMvc.perform(get("/api/orders/{id}", orderId)
                        .header("Authorization", bearer(customerB)))
                .andExpect(status().isForbidden());

        mockMvc.perform(patch("/api/orders/{id}/cancel", orderId)
                        .header("Authorization", bearer(customerB)))
                .andExpect(status().isForbidden());

        // The owner still has access.
        mockMvc.perform(get("/api/orders/{id}", orderId)
                        .header("Authorization", bearer(customerA)))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("A customer cannot review a product they never had delivered")
    void reviewWithoutDeliveredPurchase_forbidden() throws Exception {
        User customer = createCustomerWithCart("reviewer@test.com");

        String payload = """
                {"productId":%d,"rating":5,"comment":"Never bought this"}
                """.formatted(productOfA.getId());

        mockMvc.perform(post("/api/reviews")
                        .header("Authorization", bearer(customer))
                        .contentType("application/json")
                        .content(payload))
                .andExpect(status().isForbidden());

        assertThat(reviewRepository.count()).isZero();
    }
}