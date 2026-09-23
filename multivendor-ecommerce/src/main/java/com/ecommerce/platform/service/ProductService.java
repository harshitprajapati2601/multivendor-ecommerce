package com.ecommerce.platform.service;

import com.ecommerce.platform.dto.ProductRequest;
import com.ecommerce.platform.dto.ProductResponse;
import com.ecommerce.platform.entity.*;
import com.ecommerce.platform.exception.ResourceNotFoundException;
import com.ecommerce.platform.exception.SellerNotApprovedException;
import com.ecommerce.platform.repository.CategoryRepository;
import com.ecommerce.platform.repository.InventoryRepository;
import com.ecommerce.platform.repository.ProductRepository;

import com.ecommerce.platform.repository.SellerRepository;
import com.ecommerce.platform.repository.spec.ProductSpecification;
import com.ecommerce.platform.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.math.BigDecimal;

@Service
@RequiredArgsConstructor
public class ProductService {

    private final ProductRepository productRepository;
    private final CategoryRepository categoryRepository;
    private final SellerRepository sellerRepository;
    private final InventoryRepository inventoryRepository;
    private final InventoryService inventoryService;
    private final SecurityUtils securityUtils;
    private final FileStorageService fileStorageService;


    // ---------- Public catalog browsing (Days 12-13) ----------

    @Transactional(readOnly = true)
    public Page<ProductResponse> browse(Long categoryId, BigDecimal minPrice, BigDecimal maxPrice,
                                         Double minRating, String keyword, Pageable pageable) {
        var spec = ProductSpecification.build(categoryId, null, minPrice, maxPrice, minRating, keyword, true);
        return productRepository.findAll(spec, pageable).map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public ProductResponse getById(Long id) {
        return toResponse(getProductOrThrow(id));
    }

    // ---------- Seller-scoped CRUD (Day 10) ----------

    @Transactional(readOnly = true)
    public Page<ProductResponse> getMyProducts(Pageable pageable) {
        Seller seller = getCurrentSellerOrThrow();
        return productRepository.findBySellerId(seller.getId(), pageable)
                .map(this::toResponse);
    }

    @Transactional
    public ProductResponse create(ProductRequest request) {
        Seller seller = getCurrentSellerOrThrow();
        if (!seller.isApproved()) {
            throw new SellerNotApprovedException("Your seller account is pending admin approval");
        }

        Category category = categoryRepository.findById(request.getCategoryId())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Category not found with id: " + request.getCategoryId()));

        Product product = Product.builder()
                .name(request.getName())
                .description(request.getDescription())
                .price(request.getPrice())
                .category(category)
                .seller(seller)
                .averageRating(0.0)
                .build();
        product = productRepository.save(product);

        int initialStock = request.getInitialStock() != null ? request.getInitialStock() : 0;
        inventoryService.createInventory(product, initialStock);

        return toResponse(product);
    }

    @Transactional
    public ProductResponse update(Long id, ProductRequest request) {
        Product product = getProductOrThrow(id);
        assertOwnership(product);

        Category category = categoryRepository.findById(request.getCategoryId())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Category not found with id: " + request.getCategoryId()));

        product.setName(request.getName());
        product.setDescription(request.getDescription());
        product.setPrice(request.getPrice());
        product.setCategory(category);
        // initialStock is intentionally ignored on update - use the restock endpoint.

        return toResponse(productRepository.save(product));
    }

    @Transactional
    public ProductResponse uploadImage(Long id, MultipartFile file) {
        Product product = getProductOrThrow(id);
        assertOwnership(product);

        String imageUrl = fileStorageService.storeImage(file, "products");
        product.setImageUrl(imageUrl);

        return toResponse(productRepository.save(product));
    }

    @Transactional
    public void deactivate(Long id) {
        Product product = getProductOrThrow(id);
        assertOwnership(product);
        product.setActive(false);
        productRepository.save(product);
    }

    @Transactional
    public void deleteProduct(Long id) {
        Product product = getProductOrThrow(id);
        assertOwnership(product);
        try {
            inventoryRepository.findByProductId(id).ifPresent(inventoryRepository::delete);
            productRepository.delete(product);
        } catch (Exception ex) {
            product.setActive(false);
            productRepository.save(product);
        }
    }

    @Transactional
    public ProductResponse activate(Long id) {
        Product product = getProductOrThrow(id);
        assertOwnership(product);
        product.setActive(true);
        return toResponse(productRepository.save(product));
    }

    // ---------- Shared helpers ----------

    public Product getProductOrThrow(Long id) {
        return productRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Product not found with id: " + id));
    }

    /** Confirms the currently authenticated seller owns this product; throws 403 otherwise. */
    public void assertOwnership(Product product) {
        Seller seller = getCurrentSellerOrThrow();
        if (!product.getSeller().getId().equals(seller.getId())) {
            throw new AccessDeniedException("You do not own this product");
        }
    }

    private Seller getCurrentSellerOrThrow() {
        User user = securityUtils.getCurrentUser();
        return sellerRepository.findByUserId(user.getId())
                .orElseThrow(() -> new AccessDeniedException("No seller profile associated with this account"));
    }

    private ProductResponse toResponse(Product product) {
        int stock;
        try {
            stock = inventoryService.getByProduct(product.getId()).getStockQuantity();
        } catch (ResourceNotFoundException ex) {
            stock = 0; // defensive - should never happen since inventory is created with the product
        }

        return ProductResponse.builder()
                .id(product.getId())
                .name(product.getName())
                .description(product.getDescription())
                .price(product.getPrice())
                .categoryId(product.getCategory().getId())
                .categoryName(product.getCategory().getName())
                .sellerId(product.getSeller().getId())
                .sellerShopName(product.getSeller().getShopName())
                .averageRating(product.getAverageRating())
                .stockQuantity(stock)
                .active(product.isActive())
                .imageUrl(product.getImageUrl())
                .createdAt(product.getCreatedAt())
                .updatedAt(product.getUpdatedAt())
                .build();
    }
}
