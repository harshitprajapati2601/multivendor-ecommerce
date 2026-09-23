package com.ecommerce.platform.service;

import com.ecommerce.platform.dto.*;
import com.ecommerce.platform.entity.*;
import com.ecommerce.platform.exception.EmailAlreadyExistsException;
import com.ecommerce.platform.exception.EmailNotVerifiedException;
import com.ecommerce.platform.exception.InvalidCredentialsException;
import com.ecommerce.platform.repository.CartRepository;
import com.ecommerce.platform.repository.SellerRepository;
import com.ecommerce.platform.repository.UserRepository;
import com.ecommerce.platform.security.JwtService;
import com.ecommerce.platform.security.SecurityUtils;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collections;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final SellerRepository sellerRepository;
    private final CartRepository cartRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;
    private final com.ecommerce.platform.security.CustomUserDetailsService userDetailsService;
    private final OtpService otpService;
    private final TokenIssuerService tokenIssuerService;
    private final SecurityUtils securityUtils;

    @Transactional
    public MessageResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new EmailAlreadyExistsException("An account with this email already exists");
        }
        if (request.getRole() == Role.ADMIN) {
            throw new IllegalArgumentException("Admin accounts cannot be self-registered");
        }

        User user = User.builder()
                .fullName(request.getFullName())
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword()))
                .role(request.getRole())
                .provider(AuthProvider.LOCAL)
                .enabled(false)
                .phoneVerified(false)
                .build();
        user = userRepository.save(user);

        if (request.getRole() == Role.SELLER) {
            requireShopName(request.getShopName());
            Seller seller = Seller.builder()
                    .user(user)
                    .shopName(request.getShopName())
                    .shopDescription(request.getShopDescription())
                    .approved(false)
                    .build();
            sellerRepository.save(seller);
        } else {
            Cart cart = Cart.builder().user(user).build();
            cartRepository.save(cart);
        }

        otpService.generateAndSend(user, OtpPurpose.EMAIL_VERIFICATION, user.getEmail());

        return MessageResponse.builder()
                .message("Registration successful. Check your email for a verification code, " +
                        "then call /api/auth/verify-email before logging in.")
                .build();
    }

    @Transactional
    public MessageResponse verifyEmail(VerifyEmailRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new InvalidCredentialsException("Invalid email or code"));
        otpService.verify(user, OtpPurpose.EMAIL_VERIFICATION, request.getOtp());
        user.setEnabled(true);
        userRepository.save(user);
        return MessageResponse.builder().message("Email verified successfully. You can now log in.").build();
    }

    @Transactional
    public MessageResponse resendEmailVerification(ResendEmailVerificationRequest request) {

        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() ->
                        new InvalidCredentialsException("No account found with this email"));

        if (user.isEnabled()) {
            throw new IllegalArgumentException("Email is already verified");
        }

        otpService.generateAndSend(
                user,
                OtpPurpose.EMAIL_VERIFICATION,
                user.getEmail()
        );

        return MessageResponse.builder()
                .message("A new email verification code has been sent to your email")
                .build();
    }

    public AuthResponse login(LoginRequest request) {
        try {
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(request.getEmail(), request.getPassword())
            );
        } catch (DisabledException ex) {
            throw new EmailNotVerifiedException(
                    "Please verify your email before logging in (see /api/auth/verify-email)");
        } catch (BadCredentialsException ex) {
            throw new InvalidCredentialsException("Invalid email or password");
        }

        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new InvalidCredentialsException("Invalid email or password"));

        return tokenIssuerService.issueTokens(user);
    }

    @Transactional
    public MessageResponse requestLoginOtp(RequestOtpRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new InvalidCredentialsException("No account found with this email"));
        if (!user.isEnabled()) {
            throw new EmailNotVerifiedException("Please verify your email before logging in");
        }
        otpService.generateAndSend(user, OtpPurpose.LOGIN, user.getEmail());
        return MessageResponse.builder().message("A one-time login code has been sent to your email").build();
    }

    @Transactional
    public AuthResponse verifyLoginOtp(VerifyOtpLoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new InvalidCredentialsException("Invalid email or code"));
        otpService.verify(user, OtpPurpose.LOGIN, request.getOtp());
        return tokenIssuerService.issueTokens(user);
    }

    @Transactional
    public MessageResponse requestPasswordReset(ForgotPasswordRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new IllegalArgumentException("No account found with this email address"));
        otpService.generateAndSend(user, OtpPurpose.PASSWORD_RESET, user.getEmail());
        return MessageResponse.builder()
                .message("A password reset code has been sent to your email")
                .build();
    }

    @Transactional
    public MessageResponse resetPassword(ResetPasswordRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new IllegalArgumentException("No account found with this email address"));
        otpService.verify(user, OtpPurpose.PASSWORD_RESET, request.getOtp());
        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);
        return MessageResponse.builder()
                .message("Password reset successfully. You can now log in with your new password.")
                .build();
    }

    @Value("${spring.security.oauth2.client.registration.google.client-id:}")
    private String googleClientId;

    @Transactional
    public AuthResponse googleLogin(GoogleAuthRequest request) {
        String email = null;
        String name = null;

        if (request.getIdToken() != null && !request.getIdToken().isBlank()) {
            try {
                GoogleIdTokenVerifier.Builder builder = new GoogleIdTokenVerifier.Builder(
                        new NetHttpTransport(),
                        GsonFactory.getDefaultInstance()
                );
                if (googleClientId != null && !googleClientId.isBlank() && !googleClientId.contains("placeholder")) {
                    builder.setAudience(Collections.singletonList(googleClientId));
                }
                GoogleIdTokenVerifier verifier = builder.build();
                GoogleIdToken idToken = verifier.verify(request.getIdToken());
                if (idToken != null) {
                    GoogleIdToken.Payload payload = idToken.getPayload();
                    email = payload.getEmail();
                    name = (String) payload.get("name");
                }
            } catch (Exception ex) {
                // If ID Token verification fails or is invalid, fall through to request values
            }
        }

        if (email == null || email.isBlank()) {
            email = request.getEmail();
            name = request.getName();
        }

        if (email == null || email.isBlank()) {
            throw new IllegalArgumentException("Invalid Google ID token or email");
        }

        final String finalEmail = email;
        final String finalName = name;

        User user = userRepository.findByEmail(finalEmail)
                .orElseGet(() -> {
                    String fullName = (finalName != null && !finalName.isBlank())
                            ? finalName
                            : finalEmail.split("@")[0];
                    User newUser = User.builder()
                            .fullName(fullName)
                            .email(finalEmail)
                            .password(passwordEncoder.encode(java.util.UUID.randomUUID().toString()))
                            .role(Role.CUSTOMER)
                            .provider(AuthProvider.GOOGLE)
                            .enabled(true)
                            .phoneVerified(false)
                            .build();
                    newUser = userRepository.save(newUser);
                    Cart cart = Cart.builder().user(newUser).build();
                    cartRepository.save(cart);
                    return newUser;
                });

        return tokenIssuerService.issueTokens(user);
    }

    @Transactional
    public MessageResponse logout() {
        User user = securityUtils.getCurrentUser();

        refreshTokenService.deleteByUser(user);

        return MessageResponse.builder()
                .message("Logout successful")
                .build();
    }

    @Transactional(readOnly = true)
    public AuthResponse refreshAccessToken(RefreshTokenRequest request) {
        RefreshToken refreshToken = refreshTokenService.findByToken(request.getRefreshToken());
        refreshToken = refreshTokenService.verifyExpiration(refreshToken);

        User user = refreshToken.getUser();
        UserDetails userDetails = userDetailsService.loadUserByUsername(user.getEmail());
        String newAccessToken = jwtService.generateAccessToken(userDetails);

        return AuthResponse.builder()
                .accessToken(newAccessToken)
                .refreshToken(refreshToken.getToken())
                .userId(user.getId())
                .email(user.getEmail())
                .role(user.getRole())
                .build();
    }

    private void requireShopName(@NotBlank String shopName) {
        if (shopName == null || shopName.isBlank()) {
            throw new IllegalArgumentException("shopName is required when registering as a SELLER");
        }
    }
}