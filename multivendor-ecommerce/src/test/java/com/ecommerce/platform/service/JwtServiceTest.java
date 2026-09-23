package com.ecommerce.platform.security;

import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.security.SignatureException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * JwtService reads its secret and TTL from @Value fields. Because there is no
 * Spring context here, ReflectionTestUtils injects them by hand - that is the
 * standard way to unit test a @Value-driven bean.
 */
class JwtServiceTest {

    private static final String SECRET =
            "dGVzdC1vbmx5LXNlY3JldC1rZXktbXVzdC1iZS0zMi1ieXRlcy1sb25nLTEyMzQ1Ng==";

    private JwtService jwtService;
    private UserDetails userDetails;

    @BeforeEach
    void setUp() {
        jwtService = new JwtService();
        ReflectionTestUtils.setField(jwtService, "secret", SECRET);
        ReflectionTestUtils.setField(jwtService, "accessTokenExpirationMs", 900_000L);

        userDetails = User.builder()
                .username("buyer@test.com")
                .password("irrelevant")
                .authorities(List.of(new SimpleGrantedAuthority("ROLE_CUSTOMER")))
                .build();
    }

    @Test
    @DisplayName("generateAccessToken: the email lands in the subject claim")
    void generate_and_extractEmail() {
        String token = jwtService.generateAccessToken(userDetails);
        assertThat(jwtService.extractEmail(token)).isEqualTo("buyer@test.com");
    }

    @Test
    @DisplayName("isTokenValid: a freshly issued token for the right user is valid")
    void isTokenValid_freshToken() {
        String token = jwtService.generateAccessToken(userDetails);
        assertThat(jwtService.isTokenValid(token, userDetails)).isTrue();
    }

    @Test
    @DisplayName("isTokenValid: a token issued for one user is not valid for another")
    void isTokenValid_wrongUser() {
        String token = jwtService.generateAccessToken(userDetails);

        UserDetails someoneElse = User.builder()
                .username("hacker@test.com").password("x")
                .authorities(List.of(new SimpleGrantedAuthority("ROLE_CUSTOMER")))
                .build();

        assertThat(jwtService.isTokenValid(token, someoneElse)).isFalse();
    }

    @Test
    @DisplayName("An EXPIRED token throws ExpiredJwtException on parse")
    void expiredToken_throws() {
        // Negative TTL => the token is already expired the moment it is created.
        ReflectionTestUtils.setField(jwtService, "accessTokenExpirationMs", -60_000L);
        String expired = jwtService.generateAccessToken(userDetails);

        // jjwt validates `exp` during parsing, so the exception comes out of
        // extractEmail - it does NOT quietly return false. JwtAuthenticationFilter
        // catches this, leaves the SecurityContext empty, and Spring Security
        // answers 401. SecurityIntegrationTest proves that end to end.
        assertThatThrownBy(() -> jwtService.extractEmail(expired))
                .isInstanceOf(ExpiredJwtException.class);

        assertThatThrownBy(() -> jwtService.isTokenValid(expired, userDetails))
                .isInstanceOf(ExpiredJwtException.class);
    }

    @Test
    @DisplayName("A token signed with a different secret is rejected as a forgery")
    void tamperedSignature_throws() {
        JwtService attackerService = new JwtService();
        ReflectionTestUtils.setField(attackerService, "secret",
                "YXR0YWNrZXItc2VjcmV0LWtleS10aGlydHktdHdvLWJ5dGVzLWxvbmctMTIzNA==");
        ReflectionTestUtils.setField(attackerService, "accessTokenExpirationMs", 900_000L);

        String forged = attackerService.generateAccessToken(userDetails);

        assertThatThrownBy(() -> jwtService.extractEmail(forged))
                .isInstanceOf(SignatureException.class);
    }

    @Test
    @DisplayName("Garbage in the Authorization header does not crash the parser path")
    void malformedToken_throws() {
        assertThatThrownBy(() -> jwtService.extractEmail("not.a.jwt"))
                .isInstanceOf(RuntimeException.class);
    }
}