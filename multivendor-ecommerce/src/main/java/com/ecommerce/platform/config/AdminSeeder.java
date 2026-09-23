package com.ecommerce.platform.config;

import com.ecommerce.platform.entity.Role;
import com.ecommerce.platform.entity.User;
import com.ecommerce.platform.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * ADMIN accounts are intentionally blocked from self-registration
 * (see AuthService.register). This seeds one default admin on first boot
 * so you have a way to get an ADMIN token to test /api/test/admin (Day 8)
 * and, later, admin-only endpoints like seller approval.
 *
 * The admin password is read from the ADMIN_PASSWORD environment variable.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class AdminSeeder implements CommandLineRunner {

    private static final String ADMIN_EMAIL =
            System.getenv().getOrDefault("ADMIN_EMAIL", "admin@platform.com");

    private static final String ADMIN_PASSWORD =
            System.getenv("ADMIN_PASSWORD");

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {

        if (userRepository.existsByEmail(ADMIN_EMAIL)) {
            return;
        }

        if (ADMIN_PASSWORD == null || ADMIN_PASSWORD.isBlank()) {
            throw new IllegalStateException(
                    "ADMIN_PASSWORD environment variable is required to seed the default admin account."
            );
        }

        User admin = User.builder()
                .fullName("Platform Admin")
                .email(ADMIN_EMAIL)
                .password(passwordEncoder.encode(ADMIN_PASSWORD))
                .role(Role.ADMIN)
                .enabled(true)
                .build();

        userRepository.save(admin);

        log.info("Seeded default admin account -> email: {}", ADMIN_EMAIL);
    }
}