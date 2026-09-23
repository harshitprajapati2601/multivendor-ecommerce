package com.ecommerce.platform.config;

import com.ecommerce.platform.security.CustomOAuth2FailureHandler;
import com.ecommerce.platform.security.CustomOAuth2SuccessHandler;
import com.ecommerce.platform.security.JwtAuthenticationFilter;
import com.ecommerce.platform.security.RestAccessDeniedHandler;
import com.ecommerce.platform.security.RestAuthenticationEntryPoint;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity // required for @PreAuthorize on controller/service methods (Day 8)
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final CustomOAuth2SuccessHandler customOAuth2SuccessHandler;
    private final CustomOAuth2FailureHandler customOAuth2FailureHandler;
    private final RestAuthenticationEntryPoint restAuthenticationEntryPoint;
    private final RestAccessDeniedHandler restAccessDeniedHandler;
    // Both now come from AuthenticationConfig - not defined here anymore.
    private final DaoAuthenticationProvider authenticationProvider;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable()) // stateless JWT API - no CSRF tokens needed
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // =========================
                        // PUBLIC AUTHENTICATION APIs
                        // =========================
                        .requestMatchers("/api/auth/**").permitAll()

                        // =========================
                        // GOOGLE OAUTH2
                        // =========================
                        .requestMatchers("/oauth2/**", "/login/**", "/error").permitAll() // Google login redirect flow & error endpoint

                        // =========================
                        // SWAGGER
                        // =========================
                        .requestMatchers(
                                "/swagger-ui/**",
                                "/v3/api-docs/**",
                                "/swagger-ui.html",
                                "/swagger-resources/**",
                                "/webjars/**"
                        ).permitAll()

                        // =========================
                        // UPLOADED IMAGES (product photos, avatars)
                        // =========================
                        .requestMatchers(HttpMethod.GET, "/uploads/**").permitAll()

                        // =========================
                        // PUBLIC PRODUCT BROWSING
                        // =========================
                        .requestMatchers(
                                HttpMethod.GET,
                                "/api/products",
                                "/api/products/{id}"
                        ).permitAll()

                        // =========================
                        // PUBLIC CATEGORY BROWSING
                        // =========================
                        .requestMatchers(HttpMethod.GET,
                                "/api/categories",
                                "/api/categories/{id}"
                        ).permitAll()

                        // =========================
                        // TEST APIs
                        // =========================
                        .requestMatchers("/api/test/customer").hasRole("CUSTOMER")
                        .requestMatchers("/api/test/seller").hasRole("SELLER")
                        .requestMatchers("/api/test/admin").hasRole("ADMIN")

                        // =========================
                        // ADMIN APIs
                        // =========================
                        .requestMatchers("/api/admin/**").hasRole("ADMIN")
                        .requestMatchers("/api/reports/**").hasRole("ADMIN")

                        // =========================
                        // CATEGORY ADMIN OPERATIONS
                        // =========================
                        .requestMatchers(HttpMethod.POST, "/api/categories/**").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.PUT, "/api/categories/**").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.DELETE, "/api/categories/**").hasRole("ADMIN")

                        // =========================
                        // SELLER PRODUCT APIs
                        // =========================
                        .requestMatchers(HttpMethod.GET, "/api/products/{productId}/reviews").permitAll()
                        .requestMatchers("/api/products/my-products").hasRole("SELLER")
                        .requestMatchers(HttpMethod.POST, "/api/products/**").hasRole("SELLER")
                        .requestMatchers(HttpMethod.PUT, "/api/products/**").hasRole("SELLER")
                        .requestMatchers(HttpMethod.DELETE, "/api/products/**").hasRole("SELLER")

                        // =========================
                        // SELLER INVENTORY APIs
                        // =========================
                        .requestMatchers("/api/products/*/inventory/**").hasRole("SELLER")

                        // =========================
                        // EVERYTHING ELSE
                        // =========================
                        .anyRequest().authenticated()
                )
                .authenticationProvider(authenticationProvider)
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
                // Fixes: missing/invalid/expired JWT on /api/** was silently redirecting
                // to /oauth2/authorization/google (Spring's default entry point once
                // oauth2Login() is registered), which then failed with
                // "OAuth Error 401: invalid_client" on Google's side. Now it returns a
                // clean JSON 401 instead. Real Google login (/oauth2/authorization/google)
                // is unaffected since that path is permitAll() above.
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint(restAuthenticationEntryPoint)
                        .accessDeniedHandler(restAccessDeniedHandler)
                )
                .oauth2Login(oauth2 -> oauth2
                        .successHandler(customOAuth2SuccessHandler)
                        .failureHandler(customOAuth2FailureHandler)
                );

        return http.build();
    }
}