package com.ecommerce.platform.service;

import com.ecommerce.platform.dto.SellerResponse;
import com.ecommerce.platform.entity.Seller;
import com.ecommerce.platform.exception.ResourceNotFoundException;
import com.ecommerce.platform.repository.SellerRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class AdminSellerService {

    private final SellerRepository sellerRepository;

    @Transactional(readOnly = true)
    public List<SellerResponse> getPendingSellers() {
        return sellerRepository.findByApprovedFalse()
                .stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<SellerResponse> getApprovedSellers() {
        return sellerRepository.findByApprovedTrue()
                .stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public SellerResponse approve(Long sellerId) {
        Seller seller = sellerRepository.findById(sellerId)
                .orElseThrow(() -> new ResourceNotFoundException("Seller not found with id: " + sellerId));
        seller.setApproved(true);
        return toResponse(sellerRepository.save(seller));
    }

    @Transactional
    public void rejectOrCancel(Long sellerId) {
        Seller seller = sellerRepository.findById(sellerId)
                .orElseThrow(() -> new ResourceNotFoundException("Seller not found with id: " + sellerId));
        sellerRepository.delete(seller);
    }


    private SellerResponse toResponse(Seller seller) {
        return SellerResponse.builder()
                .id(seller.getId())
                .userId(seller.getUser().getId())
                .fullName(seller.getUser().getFullName())
                .email(seller.getUser().getEmail())
                .shopName(seller.getShopName())
                .shopDescription(seller.getShopDescription())
                .approved(seller.isApproved())
                .build();
    }
}
