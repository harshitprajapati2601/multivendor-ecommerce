package com.ecommerce.platform.service;

import com.ecommerce.platform.dto.ProductRequest;
import com.ecommerce.platform.dto.ProductResponse;
import com.ecommerce.platform.entity.*;
import com.ecommerce.platform.exception.ResourceNotFoundException;
import com.ecommerce.platform.exception.SellerNotApprovedException;
import com.ecommerce.platform.repository.CategoryRepository;
import com.ecommerce.platform.repository.ProductRepository;
import com.ecommerce.platform.repository.SellerRepository;
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
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ProductServiceTest {

    @Mock private ProductRepository productRepository;
    @Mock private CategoryRepository categoryRepository;
    @Mock private SellerRepository sellerRepository;
    @Mock private InventoryService inventoryService;
    @Mock private SecurityUtils securityUtils;

    @InjectMocks private ProductService productService;

    private User sellerUserA;
    private User sellerUserB;
    private Seller sellerA;
    private Seller sellerB;
    private Category category;

    @BeforeEach
    void setUp() {
        sellerUserA = User.builder().id(1L).email("a@shop.com").role(Role.SELLER).build();
        sellerUserB = User.builder().id(2L).email("b@shop.com").role(Role.SELLER).build();
        sellerA = Seller.builder().id(11L).user(sellerUserA).shopName("Shop A").approved(true).build();
        sellerB = Seller.builder().id(22L).user(sellerUserB).shopName("Shop B").approved(true).build();
        category = Category.builder().id(3L).name("Footwear").build();
    }

    private ProductRequest request() {
        ProductRequest r = new ProductRequest();
        r.setName("Running Shoe");
        r.setDescription("Light and fast");
        r.setPrice(new BigDecimal("999.00"));
        r.setCategoryId(3L);
        r.setInitialStock(25);
        return r;
    }

    private Product productOwnedBy(Seller seller) {
        return Product.builder()
                .id(100L).name("Running Shoe").price(new BigDecimal("999.00"))
                .category(category).seller(seller).averageRating(0.0).active(true)
                .build();
    }

    @Test
    @DisplayName("create: an approved seller gets a product plus its inventory row")
    void create_success() {
        when(securityUtils.getCurrentUser()).thenReturn(sellerUserA);
        when(sellerRepository.findByUserId(1L)).thenReturn(Optional.of(sellerA));
        when(categoryRepository.findById(3L)).thenReturn(Optional.of(category));
        when(productRepository.save(any(Product.class))).thenAnswer(i -> {
            Product p = i.getArgument(0);
            p.setId(100L);
            return p;
        });
        when(inventoryService.getByProduct(100L))
                .thenReturn(Inventory.builder().stockQuantity(25).build());

        ProductResponse response = productService.create(request());

        assertThat(response.getSellerId()).isEqualTo(11L);
        assertThat(response.getStockQuantity()).isEqualTo(25);
        verify(inventoryService).createInventory(any(Product.class), eq(25));
    }

    @Test
    @DisplayName("create: an unapproved seller is blocked before anything is written")
    void create_sellerNotApproved() {
        sellerA.setApproved(false);
        when(securityUtils.getCurrentUser()).thenReturn(sellerUserA);
        when(sellerRepository.findByUserId(1L)).thenReturn(Optional.of(sellerA));

        assertThatThrownBy(() -> productService.create(request()))
                .isInstanceOf(SellerNotApprovedException.class)
                .hasMessageContaining("pending admin approval");

        verify(productRepository, never()).save(any());
        verify(inventoryService, never()).createInventory(any(), anyInt());
    }

    @Test
    @DisplayName("create: unknown categoryId is a 404, not a bad FK at the DB level")
    void create_categoryNotFound() {
        when(securityUtils.getCurrentUser()).thenReturn(sellerUserA);
        when(sellerRepository.findByUserId(1L)).thenReturn(Optional.of(sellerA));
        when(categoryRepository.findById(3L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> productService.create(request()))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    @DisplayName("update: seller B cannot edit seller A's product (cross-seller access)")
    void update_crossSeller_denied() {
        when(productRepository.findById(100L)).thenReturn(Optional.of(productOwnedBy(sellerA)));
        when(securityUtils.getCurrentUser()).thenReturn(sellerUserB);
        when(sellerRepository.findByUserId(2L)).thenReturn(Optional.of(sellerB));

        assertThatThrownBy(() -> productService.update(100L, request()))
                .isInstanceOf(AccessDeniedException.class)
                .hasMessageContaining("do not own");

        verify(productRepository, never()).save(any());
    }

    @Test
    @DisplayName("deactivate: seller B cannot soft-delete seller A's product")
    void deactivate_crossSeller_denied() {
        Product product = productOwnedBy(sellerA);
        when(productRepository.findById(100L)).thenReturn(Optional.of(product));
        when(securityUtils.getCurrentUser()).thenReturn(sellerUserB);
        when(sellerRepository.findByUserId(2L)).thenReturn(Optional.of(sellerB));

        assertThatThrownBy(() -> productService.deactivate(100L))
                .isInstanceOf(AccessDeniedException.class);

        assertThat(product.isActive()).isTrue();
    }

    @Test
    @DisplayName("deactivate: the owner soft-deletes rather than hard-deletes")
    void deactivate_ownerSoftDeletes() {
        Product product = productOwnedBy(sellerA);
        when(productRepository.findById(100L)).thenReturn(Optional.of(product));
        when(securityUtils.getCurrentUser()).thenReturn(sellerUserA);
        when(sellerRepository.findByUserId(1L)).thenReturn(Optional.of(sellerA));

        productService.deactivate(100L);

        assertThat(product.isActive()).isFalse();
        verify(productRepository).save(product);
        verify(productRepository, never()).delete(any(Product.class));
    }

    @Test
    @DisplayName("assertOwnership: a CUSTOMER with no seller profile is denied")
    void assertOwnership_noSellerProfile() {
        User customer = User.builder().id(5L).email("c@test.com").role(Role.CUSTOMER).build();
        when(securityUtils.getCurrentUser()).thenReturn(customer);
        when(sellerRepository.findByUserId(5L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> productService.assertOwnership(productOwnedBy(sellerA)))
                .isInstanceOf(AccessDeniedException.class)
                .hasMessageContaining("No seller profile");
    }

    @Test
    @DisplayName("update: the owner's changes are applied and initialStock is ignored")
    void update_ownerSuccess() {
        Product product = productOwnedBy(sellerA);
        when(productRepository.findById(100L)).thenReturn(Optional.of(product));
        when(securityUtils.getCurrentUser()).thenReturn(sellerUserA);
        when(sellerRepository.findByUserId(1L)).thenReturn(Optional.of(sellerA));
        when(categoryRepository.findById(3L)).thenReturn(Optional.of(category));
        when(productRepository.save(any(Product.class))).thenAnswer(i -> i.getArgument(0));
        when(inventoryService.getByProduct(100L))
                .thenReturn(Inventory.builder().stockQuantity(7).build());

        ProductRequest req = request();
        req.setName("Renamed Shoe");
        req.setInitialStock(9999); // must be ignored on update

        ProductResponse response = productService.update(100L, req);

        assertThat(response.getName()).isEqualTo("Renamed Shoe");
        assertThat(response.getStockQuantity()).isEqualTo(7);
        verify(inventoryService, never()).createInventory(any(), anyInt());
    }
}