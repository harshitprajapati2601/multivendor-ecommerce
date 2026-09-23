package com.ecommerce.platform.repository;

import com.ecommerce.platform.entity.Otp;
import com.ecommerce.platform.entity.OtpPurpose;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface OtpRepository extends JpaRepository<Otp, Long> {

    Optional<Otp> findTopByUserIdAndPurposeAndCodeAndUsedFalseOrderByIdDesc(
            Long userId, OtpPurpose purpose, String code);

    // Used to invalidate any still-outstanding codes when a new one is issued,
    // so only the most recently sent code is ever valid.
    List<Otp> findByUserIdAndPurposeAndUsedFalse(Long userId, OtpPurpose purpose);
}
