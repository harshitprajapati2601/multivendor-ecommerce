package com.ecommerce.platform.service;

import com.ecommerce.platform.dto.AuthResponse;
import com.ecommerce.platform.entity.RefreshToken;
import com.ecommerce.platform.entity.User;
import com.ecommerce.platform.security.CustomUserDetailsService;
import com.ecommerce.platform.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Service;

/**
 * Pulled out of AuthService on purpose. AuthService also depends on
 * AuthenticationManager (for password login), and CustomOAuth2SuccessHandler
 * depends on SecurityConfig's bean graph - so if CustomOAuth2SuccessHandler
 * depended on the whole AuthService, you get:
 * securityConfig -> customOAuth2SuccessHandler -> authService -> authenticationManager -> (back to securityConfig)
 * This class has NO dependency on AuthenticationManager at all, so
 * CustomOAuth2SuccessHandler can depend on just this piece and the cycle
 * never forms.
 */
@Service
@RequiredArgsConstructor
public class TokenIssuerService {

    private final CustomUserDetailsService userDetailsService;
    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;

    public AuthResponse issueTokens(User user) {
        UserDetails userDetails = userDetailsService.loadUserByUsername(user.getEmail());
        String accessToken = jwtService.generateAccessToken(userDetails);
        RefreshToken refreshToken = refreshTokenService.createRefreshToken(user);

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken.getToken())
                .userId(user.getId())
                .email(user.getEmail())
                .role(user.getRole())
                .build();
    }
}