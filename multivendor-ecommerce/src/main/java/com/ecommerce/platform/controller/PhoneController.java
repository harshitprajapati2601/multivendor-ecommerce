package com.ecommerce.platform.controller;

import com.ecommerce.platform.dto.MessageResponse;
import com.ecommerce.platform.dto.RequestPhoneOtpRequest;
import com.ecommerce.platform.dto.VerifyPhoneOtpRequest;
import com.ecommerce.platform.service.PhoneVerificationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

// Deliberately NOT under /api/auth/** - that prefix is permitAll in
// SecurityConfig. This one needs a valid JWT, which the default
// anyRequest().authenticated() rule already covers.
@RestController
@RequestMapping("/api/account/phone")
@RequiredArgsConstructor
public class PhoneController {

    private final PhoneVerificationService phoneVerificationService;

    @PostMapping("/request-otp")
    public ResponseEntity<MessageResponse> requestOtp(@Valid @RequestBody RequestPhoneOtpRequest request) {
        return ResponseEntity.ok(phoneVerificationService.requestOtp(request.getPhoneNumber()));
    }

    @PostMapping("/verify-otp")
    public ResponseEntity<MessageResponse> verifyOtp(@Valid @RequestBody VerifyPhoneOtpRequest request) {
        return ResponseEntity.ok(phoneVerificationService.verifyOtp(request.getOtp()));
    }
}
