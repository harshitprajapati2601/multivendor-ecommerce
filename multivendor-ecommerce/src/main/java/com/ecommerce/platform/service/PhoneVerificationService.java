package com.ecommerce.platform.service;

import com.ecommerce.platform.dto.MessageResponse;
import com.ecommerce.platform.entity.Otp;
import com.ecommerce.platform.entity.OtpPurpose;
import com.ecommerce.platform.entity.User;
import com.ecommerce.platform.repository.UserRepository;
import com.ecommerce.platform.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PhoneVerificationService {

    private final OtpService otpService;
    private final UserRepository userRepository;
    private final SecurityUtils securityUtils;

    @Transactional
    public MessageResponse requestOtp(String phoneNumber) {
        User user = securityUtils.getCurrentUser();
        // The number isn't saved to the User yet - only once verify() succeeds.
        // This also means two users could race to claim the same number; a
        // production system would reserve it here. Kept simple for this project.
        otpService.generateAndSend(user, OtpPurpose.PHONE_VERIFICATION, phoneNumber);
        return MessageResponse.builder().message("A verification code has been sent to " + phoneNumber).build();
    }

    @Transactional
    public MessageResponse verifyOtp(String code) {
        User user = securityUtils.getCurrentUser();
        Otp otp = otpService.verify(user, OtpPurpose.PHONE_VERIFICATION, code);

        user.setPhoneNumber(otp.getTarget());
        user.setPhoneVerified(true);
        userRepository.save(user);

        return MessageResponse.builder().message("Phone number verified successfully").build();
    }
}
