package com.ecommerce.platform.controller;

import com.ecommerce.platform.dto.*;
import com.ecommerce.platform.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    public ResponseEntity<MessageResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(authService.register(request));
    }

    @PostMapping("/verify-email")
    public ResponseEntity<MessageResponse> verifyEmail(@Valid @RequestBody VerifyEmailRequest request) {
        return ResponseEntity.ok(authService.verifyEmail(request));
    }

    @PostMapping("/verify-email/resend")
    public ResponseEntity<MessageResponse> resendEmailVerification(
            @Valid @RequestBody ResendEmailVerificationRequest request) {
        return ResponseEntity.ok(authService.resendEmailVerification(request));
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        return ResponseEntity.ok(authService.login(request));
    }

    // ---------- OTP-based (passwordless) login ----------

    @PostMapping("/otp/login/request")
    public ResponseEntity<MessageResponse> requestLoginOtp(@Valid @RequestBody RequestOtpRequest request) {
        return ResponseEntity.ok(authService.requestLoginOtp(request));
    }

    @PostMapping("/otp/login/verify")
    public ResponseEntity<AuthResponse> verifyLoginOtp(@Valid @RequestBody VerifyOtpLoginRequest request) {
        return ResponseEntity.ok(authService.verifyLoginOtp(request));
    }

    // ---------- Password Reset ----------

    @PostMapping("/password/reset-request")
    public ResponseEntity<MessageResponse> requestPasswordReset(@Valid @RequestBody ForgotPasswordRequest request) {
        return ResponseEntity.ok(authService.requestPasswordReset(request));
    }

    @PostMapping("/password/reset")
    public ResponseEntity<MessageResponse> resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        return ResponseEntity.ok(authService.resetPassword(request));
    }

    // ---------- Google Social Sign-In ----------

    @PostMapping("/google")
    public ResponseEntity<AuthResponse> googleLogin(@Valid @RequestBody GoogleAuthRequest request) {
        return ResponseEntity.ok(authService.googleLogin(request));
    }

    @PostMapping("/refresh-token")
    public ResponseEntity<AuthResponse> refreshToken(
            @RequestBody(required = false) RefreshTokenRequest request,
            @RequestParam(name = "refreshToken", required = false) String paramRefreshToken,
            @RequestParam(name = "refresh_token", required = false) String paramSnakeRefreshToken,
            @RequestParam(name = "token", required = false) String paramGenericToken) {

        String tokenToUse = null;
        if (request != null && request.getRefreshToken() != null && !request.getRefreshToken().isBlank()) {
            tokenToUse = request.getRefreshToken();
        } else if (paramRefreshToken != null && !paramRefreshToken.isBlank()) {
            tokenToUse = paramRefreshToken;
        } else if (paramSnakeRefreshToken != null && !paramSnakeRefreshToken.isBlank()) {
            tokenToUse = paramSnakeRefreshToken;
        } else if (paramGenericToken != null && !paramGenericToken.isBlank()) {
            tokenToUse = paramGenericToken;
        }

        if (tokenToUse == null || tokenToUse.isBlank()) {
            throw new IllegalArgumentException("Refresh token is required");
        }

        return ResponseEntity.ok(
                authService.refreshAccessToken(new RefreshTokenRequest(tokenToUse)));
    }
    @PostMapping("/logout")
    public ResponseEntity<MessageResponse> logout() {
        return ResponseEntity.ok(authService.logout());
    }
}
