package com.ecommerce.platform.integration;

import com.ecommerce.platform.entity.*;
import com.ecommerce.platform.repository.*;
import com.ecommerce.platform.security.CustomUserDetailsService;
import com.ecommerce.platform.security.JwtService;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import javax.crypto.SecretKey;
import java.math.BigDecimal;
import java.util.Date;
import java.util.List;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public abstract class BaseIntegrationTest {

    @Autowired protected MockMvc mockMvc;
    @Autowired protected ObjectMapper objectMapper;

    @Autowired protected UserRepository userRepository;
    @Autowired protected SellerRepository sellerRepository;
    @Autowired protected CategoryRepository categoryRepository;
    @Autowired protected ProductRepository productRepository;
    @Autowired protected InventoryRepository inventoryRepository;
    @Autowired protected CartRepository cartRepository;
    @Autowired protected CartItemRepository cartItemRepository;
    @Autowired protected OrderRepository orderRepository;
    @Autowired protected OrderItemRepository orderItemRepository;
    @Autowired protected PaymentRepository paymentRepository;
    @Autowired protected ReviewRepository reviewRepository;
    @Autowired protected OtpRepository otpRepository;
    @Autowired protected RefreshTokenRepository refreshTokenRepository;

    @Autowired protected JwtService jwtService;
    @Autowired protected CustomUserDetailsService userDetailsService;
    @Autowired protected PasswordEncoder passwordEncoder;

    @Value("${app.jwt.secret}")
    protected String jwtSecret;

    /**
     * Child-first deletion order. Reverse this and H2 will reject the delete
     * with a foreign-key violation.
     */
    @BeforeEach
    void wipeDatabase() {
        paymentRepository.deleteAll();
        orderItemRepository.deleteAll();
        orderRepository.deleteAll();
        cartItemRepository.deleteAll();
        cartRepository.deleteAll();
        reviewRepository.deleteAll();
        inventoryRepository.deleteAll();
        productRepository.deleteAll();
        categoryRepository.deleteAll();
        otpRepository.deleteAll();
        refreshTokenRepository.deleteAll();
        sellerRepository.deleteAll();
        userRepository.deleteAll();
    }

    // ---------------- fixture builders ----------------

    protected User createUser(String email, Role role) {
        return userRepository.save(User.builder()
                .fullName("Test " + role.name())
                .email(email)
                .password(passwordEncoder.encode("Password@123"))
                .role(role)
                .enabled(true)          // skip the OTP email-verification step
                .phoneVerified(false)
                .provider(AuthProvider.LOCAL)
                .build());
    }

    protected User createCustomerWithCart(String email) {
        User customer = createUser(email, Role.CUSTOMER);
        cartRepository.save(Cart.builder().user(customer).build());
        return customer;
    }

    protected Seller createSeller(String email, String shopName, boolean approved) {
        User user = createUser(email, Role.SELLER);
        return sellerRepository.save(Seller.builder()
                .user(user)
                .shopName(shopName)
                .shopDescription("Integration test shop")
                .approved(approved)
                .build());
    }

    protected Category createCategory(String name) {
        return categoryRepository.save(Category.builder()
                .name(name).description(name + " description").build());
    }

    protected Product createProduct(Seller seller, Category category, String price, int stock) {
        Product product = productRepository.save(Product.builder()
                .name("Product of " + seller.getShopName())
                .description("Integration test product")
                .price(new BigDecimal(price))
                .category(category)
                .seller(seller)
                .averageRating(0.0)
                .build());

        inventoryRepository.save(Inventory.builder()
                .product(product).stockQuantity(stock).build());

        return product;
    }

    protected CartItem addToCart(User customer, Product product, int quantity) {
        Cart cart = cartRepository.findByUserId(customer.getId()).orElseThrow();
        return cartItemRepository.save(CartItem.builder()
                .cart(cart).product(product).quantity(quantity).build());
    }

    protected int stockOf(Product product) {
        return inventoryRepository.findByProductId(product.getId()).orElseThrow().getStockQuantity();
    }

    // ---------------- token helpers ----------------

    /** A real, valid access token - exactly what /api/auth/login would hand back. */
    protected String tokenFor(User user) {
        return jwtService.generateAccessToken(
                userDetailsService.loadUserByUsername(user.getEmail()));
    }

    protected String bearer(User user) {
        return "Bearer " + tokenFor(user);
    }

    /**
     * Correctly signed but already past its `exp`. Built with jjwt directly
     * because JwtService always issues tokens with a future expiry.
     */
    protected String expiredTokenFor(User user) {
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .subject(user.getEmail())
                .claim("authorities", List.of("ROLE_" + user.getRole().name()))
                .issuedAt(new Date(now - 3_600_000))
                .expiration(new Date(now - 60_000))
                .signWith(key)
                .compact();
    }

    /** Signed with the wrong key - simulates a forged token. */
    protected String forgedTokenFor(User user) {
        SecretKey wrongKey = Keys.hmacShaKeyFor(
                "YXR0YWNrZXItc2VjcmV0LWtleS10aGlydHktdHdvLWJ5dGVzLWxvbmctMTIzNA==".getBytes());
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .subject(user.getEmail())
                .claim("authorities", List.of("ROLE_ADMIN"))
                .issuedAt(new Date(now))
                .expiration(new Date(now + 900_000))
                .signWith(wrongKey)
                .compact();
    }
}