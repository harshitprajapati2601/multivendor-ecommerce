package com.ecommerce.platform.service;

import com.ecommerce.platform.dto.UpdateProfileRequest;
import com.ecommerce.platform.dto.UserProfileResponse;
import com.ecommerce.platform.entity.Role;
import com.ecommerce.platform.entity.Seller;
import com.ecommerce.platform.entity.User;
import com.ecommerce.platform.repository.UserRepository;
import com.ecommerce.platform.repository.SellerRepository;
import com.ecommerce.platform.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.util.Optional;

@Service
@RequiredArgsConstructor
public class AccountService {

    private final UserRepository userRepository;
    private final SellerRepository sellerRepository;
    private final SecurityUtils securityUtils;
    private final FileStorageService fileStorageService;

    @Transactional(readOnly = true)
    public UserProfileResponse getMyProfile() {
        return toResponse(securityUtils.getCurrentUser());
    }

    @Transactional
    public UserProfileResponse updateProfile(UpdateProfileRequest request) {
        User user = securityUtils.getCurrentUser();

        if (request.getFullName() != null && !request.getFullName().isBlank()) {
            user.setFullName(request.getFullName().trim());
        }
        if (request.getPhoneNumber() != null) {
            user.setPhoneNumber(request.getPhoneNumber().trim());
        }

        userRepository.save(user);

        if (user.getRole() == Role.SELLER) {
            Optional<Seller> sellerOpt = sellerRepository.findByUserId(user.getId());
            if (sellerOpt.isPresent()) {
                Seller seller = sellerOpt.get();
                if (request.getShopName() != null && !request.getShopName().isBlank()) {
                    seller.setShopName(request.getShopName().trim());
                }
                if (request.getShopDescription() != null) {
                    seller.setShopDescription(request.getShopDescription().trim());
                }
                sellerRepository.save(seller);
            }
        }

        return toResponse(user);
    }

    @Transactional
    public UserProfileResponse updateProfilePicture(MultipartFile file) {
        User user = securityUtils.getCurrentUser();
        String imageUrl = fileStorageService.storeImage(file, "avatars");
        user.setProfileImageUrl(imageUrl);
        return toResponse(userRepository.save(user));
    }

    private UserProfileResponse toResponse(User user) {
        UserProfileResponse.UserProfileResponseBuilder builder = UserProfileResponse.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .role(user.getRole().name())
                .phoneNumber(user.getPhoneNumber())
                .phoneVerified(user.isPhoneVerified())
                .profileImageUrl(user.getProfileImageUrl());

        if (user.getRole() == Role.SELLER) {
            sellerRepository.findByUserId(user.getId()).ifPresent(seller -> {
                builder.shopName(seller.getShopName())
                        .shopDescription(seller.getShopDescription())
                        .sellerApproved(seller.isApproved());
            });
        }

        return builder.build();
    }
}

