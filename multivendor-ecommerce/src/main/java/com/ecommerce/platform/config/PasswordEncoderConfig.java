package com.ecommerce.platform.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * Deliberately its own class, not a @Bean method inside SecurityConfig.
 *
 * SecurityConfig's constructor needs CustomOAuth2SuccessHandler, which needs
 * PasswordEncoder. If PasswordEncoder were defined as a @Bean method on
 * SecurityConfig itself, Spring would have to fully construct SecurityConfig
 * before it could even call that method - but constructing SecurityConfig
 * requires PasswordEncoder first. That circular wait is exactly the
 * "Requested bean is currently in creation" error. Putting it in a
 * standalone, dependency-free class breaks the cycle.
 */
@Configuration
public class PasswordEncoderConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
