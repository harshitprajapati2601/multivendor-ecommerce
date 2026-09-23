package com.ecommerce.platform.repository;

import com.ecommerce.platform.entity.Seller;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SellerRepository extends JpaRepository<Seller, Long> {

    Optional<Seller> findByUserId(Long userId);

    List<Seller> findByApprovedFalse();

    List<Seller> findByApprovedTrue();
}

