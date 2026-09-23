package com.ecommerce.platform.integration;

import com.ecommerce.platform.entity.Role;
import com.ecommerce.platform.entity.User;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class SecurityIntegrationTest extends BaseIntegrationTest {

    // ---------------- public endpoints ----------------

    @Test
    @DisplayName("Public catalog browsing needs no token")
    void browseProducts_isPublic() throws Exception {
        mockMvc.perform(get("/api/products"))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("Public category listing needs no token")
    void listCategories_isPublic() throws Exception {
        mockMvc.perform(get("/api/categories"))
                .andExpect(status().isOk());
    }

    // ---------------- missing / broken tokens ----------------

    @Test
    @DisplayName("No Authorization header on a protected endpoint returns JSON 401")
    void noToken_returns401Json() throws Exception {
        mockMvc.perform(get("/api/orders"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401));
    }

    @Test
    @DisplayName("EXPIRED JWT returns 401, never 403 and never a stack trace")
    void expiredToken_returns401() throws Exception {
        User customer = createCustomerWithCart("expired@test.com");

        mockMvc.perform(get("/api/orders")
                        .header("Authorization", "Bearer " + expiredTokenFor(customer)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401));
    }

    @Test
    @DisplayName("Expired JWT is rejected on a write endpoint too")
    void expiredToken_onPost_returns401() throws Exception {
        User customer = createCustomerWithCart("expired2@test.com");

        mockMvc.perform(post("/api/orders")
                        .header("Authorization", "Bearer " + expiredTokenFor(customer))
                        .contentType("application/json")
                        .content("{\"paymentToken\":\"tok_ok\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Token signed with the wrong secret is rejected even though it claims ROLE_ADMIN")
    void forgedToken_returns401() throws Exception {
        User customer = createCustomerWithCart("forged@test.com");

        mockMvc.perform(get("/api/admin/sellers/pending")
                        .header("Authorization", "Bearer " + forgedTokenFor(customer)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Garbage token string returns 401, not 500")
    void malformedToken_returns401() throws Exception {
        mockMvc.perform(get("/api/orders")
                        .header("Authorization", "Bearer this.is.not.a.jwt"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("A non-Bearer scheme is ignored and treated as anonymous")
    void basicAuthHeader_returns401() throws Exception {
        mockMvc.perform(get("/api/orders")
                        .header("Authorization", "Basic YWRtaW46YWRtaW4="))
                .andExpect(status().isUnauthorized());
    }

    // ---------------- role boundaries ----------------

    @Test
    @DisplayName("CUSTOMER token on an ADMIN endpoint returns 403")
    void customerOnAdminEndpoint_returns403() throws Exception {
        User customer = createCustomerWithCart("cust@test.com");

        mockMvc.perform(get("/api/admin/sellers/pending")
                        .header("Authorization", bearer(customer)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403));
    }

    @Test
    @DisplayName("SELLER token on an ADMIN reports endpoint returns 403")
    void sellerOnReports_returns403() throws Exception {
        User seller = createSeller("seller@test.com", "Shop S", true).getUser();

        mockMvc.perform(get("/api/reports/top-sellers")
                        .header("Authorization", bearer(seller)))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("CUSTOMER token on a SELLER-only endpoint returns 403")
    void customerOnSellerEndpoint_returns403() throws Exception {
        User customer = createCustomerWithCart("cust2@test.com");

        mockMvc.perform(get("/api/products/my-products")
                        .header("Authorization", bearer(customer)))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("ADMIN token on an ADMIN endpoint returns 200")
    void adminOnAdminEndpoint_returns200() throws Exception {
        User admin = createUser("admin@test.com", Role.ADMIN);

        mockMvc.perform(get("/api/admin/sellers/pending")
                        .header("Authorization", bearer(admin)))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("CUSTOMER token on a CUSTOMER endpoint returns 200")
    void customerOnOwnEndpoint_returns200() throws Exception {
        User customer = createCustomerWithCart("cust3@test.com");

        mockMvc.perform(get("/api/cart")
                        .header("Authorization", bearer(customer)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalAmount").value(0));
    }

    // ---------------- Day 25 error-handling guarantees ----------------

    @Test
    @DisplayName("Unknown endpoint with a valid token returns the JSON 404 shape, not a whitelabel page")
    void unknownEndpoint_returnsJson404() throws Exception {
        User customer = createCustomerWithCart("cust4@test.com");

        mockMvc.perform(get("/api/does-not-exist")
                        .header("Authorization", bearer(customer)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.message", containsString("No endpoint found")));
    }

    @Test
    @DisplayName("Non-numeric path variable returns a 400 with a readable message")
    void badPathVariable_returns400() throws Exception {
        mockMvc.perform(get("/api/products/not-a-number"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));
    }

    @Test
    @DisplayName("Bean-validation failure returns 400 with a populated fieldErrors map")
    void validationFailure_returnsFieldErrors() throws Exception {
        User seller = createSeller("seller2@test.com", "Shop V", true).getUser();

        String invalidProduct = """
                {"name":"","price":-5,"categoryId":null}
                """;

        mockMvc.perform(post("/api/products")
                        .header("Authorization", bearer(seller))
                        .contentType("application/json")
                        .content(invalidProduct))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Validation failed"))
                .andExpect(jsonPath("$.fieldErrors.name").exists())
                .andExpect(jsonPath("$.fieldErrors.price").exists())
                .andExpect(jsonPath("$.fieldErrors.categoryId").exists());
    }

    @Test
    @DisplayName("Malformed JSON body returns 400, not 500")
    void malformedJson_returns400() throws Exception {
        User seller = createSeller("seller3@test.com", "Shop M", true).getUser();

        mockMvc.perform(post("/api/products")
                        .header("Authorization", bearer(seller))
                        .contentType("application/json")
                        .content("{\"name\": \"broken\","))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Malformed or missing request body"));
    }

    @Test
    @DisplayName("Wrong HTTP method returns 405")
    void wrongHttpMethod_returns405() throws Exception {
        User customer = createCustomerWithCart("cust5@test.com");

        mockMvc.perform(post("/api/orders/1/cancel")
                        .header("Authorization", bearer(customer)))
                .andExpect(status().isMethodNotAllowed());
    }
}