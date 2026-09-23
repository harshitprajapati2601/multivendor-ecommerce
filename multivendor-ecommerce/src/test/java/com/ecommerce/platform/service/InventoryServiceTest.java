package com.ecommerce.platform.service;

import com.ecommerce.platform.entity.Inventory;
import com.ecommerce.platform.entity.Product;
import com.ecommerce.platform.exception.InsufficientStockException;
import com.ecommerce.platform.exception.ResourceNotFoundException;
import com.ecommerce.platform.repository.InventoryRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Pure unit test - no Spring, no database. InventoryRepository is a Mockito
 * mock, so these run in milliseconds and test ONLY the service's own logic.
 */
@ExtendWith(MockitoExtension.class)
class InventoryServiceTest {

    @Mock
    private InventoryRepository inventoryRepository;

    @InjectMocks
    private InventoryService inventoryService;

    private Inventory inventoryWithStock(int stock) {
        Product product = Product.builder().id(1L).name("Test Shoe").build();
        return Inventory.builder().id(100L).product(product).stockQuantity(stock).build();
    }

    @Test
    @DisplayName("deductStock: reduces quantity and flushes when enough stock exists")
    void deductStock_success() {
        Inventory inventory = inventoryWithStock(10);
        when(inventoryRepository.findByProductId(1L)).thenReturn(Optional.of(inventory));
        when(inventoryRepository.saveAndFlush(any(Inventory.class))).thenAnswer(i -> i.getArgument(0));

        Inventory result = inventoryService.deductStock(1L, 3);

        assertThat(result.getStockQuantity()).isEqualTo(7);
        // saveAndFlush (not save) is deliberate - it surfaces optimistic lock
        // failures inside the order's transaction instead of at commit time.
        verify(inventoryRepository).saveAndFlush(inventory);
    }

    @Test
    @DisplayName("deductStock: throws InsufficientStockException and never saves when stock is short")
    void deductStock_insufficientStock() {
        Inventory inventory = inventoryWithStock(2);
        when(inventoryRepository.findByProductId(1L)).thenReturn(Optional.of(inventory));

        assertThatThrownBy(() -> inventoryService.deductStock(1L, 5))
                .isInstanceOf(InsufficientStockException.class)
                .hasMessageContaining("requested 5")
                .hasMessageContaining("available 2");

        assertThat(inventory.getStockQuantity()).isEqualTo(2); // untouched
        verify(inventoryRepository, never()).saveAndFlush(any());
        verify(inventoryRepository, never()).save(any());
    }

    @Test
    @DisplayName("deductStock: exact-stock order is allowed (boundary case)")
    void deductStock_exactStockAllowed() {
        Inventory inventory = inventoryWithStock(5);
        when(inventoryRepository.findByProductId(1L)).thenReturn(Optional.of(inventory));
        when(inventoryRepository.saveAndFlush(any(Inventory.class))).thenAnswer(i -> i.getArgument(0));

        assertThat(inventoryService.deductStock(1L, 5).getStockQuantity()).isZero();
    }

    @Test
    @DisplayName("restock: adds to existing quantity")
    void restock_success() {
        Inventory inventory = inventoryWithStock(4);
        when(inventoryRepository.findByProductId(1L)).thenReturn(Optional.of(inventory));
        when(inventoryRepository.save(any(Inventory.class))).thenAnswer(i -> i.getArgument(0));

        assertThat(inventoryService.restock(1L, 6).getStockQuantity()).isEqualTo(10);
    }

    @Test
    @DisplayName("restoreStock: puts cancelled-order quantity back into the pool")
    void restoreStock_success() {
        Inventory inventory = inventoryWithStock(0);
        when(inventoryRepository.findByProductId(1L)).thenReturn(Optional.of(inventory));
        when(inventoryRepository.save(any(Inventory.class))).thenAnswer(i -> i.getArgument(0));

        assertThat(inventoryService.restoreStock(1L, 3).getStockQuantity()).isEqualTo(3);
    }

    @Test
    @DisplayName("getByProduct: throws ResourceNotFoundException for an unknown product")
    void getByProduct_notFound() {
        when(inventoryRepository.findByProductId(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> inventoryService.getByProduct(99L))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("99");
    }

    @Test
    @DisplayName("createInventory: clamps a negative initial stock to zero")
    void createInventory_clampsNegative() {
        Product product = Product.builder().id(1L).build();
        when(inventoryRepository.save(any(Inventory.class))).thenAnswer(i -> i.getArgument(0));

        assertThat(inventoryService.createInventory(product, -50).getStockQuantity()).isZero();
    }
}