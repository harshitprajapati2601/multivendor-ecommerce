package com.ecommerce.platform.service;

import com.ecommerce.platform.entity.Inventory;
import com.ecommerce.platform.entity.Product;
import com.ecommerce.platform.exception.InsufficientStockException;
import com.ecommerce.platform.exception.ResourceNotFoundException;
import com.ecommerce.platform.repository.InventoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class InventoryService {

    private final InventoryRepository inventoryRepository;

    @Transactional
    public Inventory createInventory(Product product, int initialStock) {
        Inventory inventory = Inventory.builder()
                .product(product)
                .stockQuantity(Math.max(initialStock, 0))
                .build();
        return inventoryRepository.save(inventory);
    }

    public Inventory getByProduct(Long productId) {
        return inventoryRepository.findByProductId(productId)
                .orElseThrow(() -> new ResourceNotFoundException("Inventory not found for product id: " + productId));
    }

    @Transactional
    public Inventory restock(Long productId, int quantity) {
        Inventory inventory = getByProduct(productId);
        inventory.setStockQuantity(inventory.getStockQuantity() + quantity);
        // save() re-checks the @Version column - if another transaction touched
        // this row concurrently, this throws OptimisticLockingFailureException.
        return inventoryRepository.save(inventory);
    }

    /**
     * Used during order placement (Day 16). Checks availability, decrements,
     * and flushes immediately (not just save()) so that if a concurrent order
     * already bumped this row's @Version, the OptimisticLockingFailureException
     * surfaces right here - inside the order's own @Transactional method -
     * instead of silently at end-of-transaction. That failure then rolls back
     * the whole order placement cleanly (Day 18).
     */
    @Transactional
    public Inventory deductStock(Long productId, int quantity) {
        Inventory inventory = getByProduct(productId);
        if (inventory.getStockQuantity() < quantity) {
            throw new InsufficientStockException(
                    "Insufficient stock for product '" + inventory.getProduct().getName() +
                            "': requested " + quantity + ", available " + inventory.getStockQuantity());
        }
        inventory.setStockQuantity(inventory.getStockQuantity() - quantity);
        return inventoryRepository.saveAndFlush(inventory);
    }

    /** Used when an order is cancelled - returns the reserved stock to the pool. */
    @Transactional
    public Inventory restoreStock(Long productId, int quantity) {
        return restock(productId, quantity);
    }
}
