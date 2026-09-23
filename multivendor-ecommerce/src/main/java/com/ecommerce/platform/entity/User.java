package com.ecommerce.platform.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "users", uniqueConstraints = @UniqueConstraint(columnNames = "email"))
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String fullName;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String password;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role;

    // For LOCAL accounts this doubles as "email verified" - false until
    // /api/auth/verify-email succeeds, which also blocks login (see
    // CustomUserDetailsService -> DaoAuthenticationProvider). GOOGLE accounts
    // are enabled immediately since Google has already verified the email.
    @Column(nullable = false)
    private boolean enabled;

    @Column(unique = true)
    private String phoneNumber;

    @Column(nullable = false)
    private boolean phoneVerified;

    // Relative URL (e.g. "/uploads/avatars/xyz.jpg") set via POST /api/account/profile-picture.
    // Null until the user uploads one.
    private String profileImageUrl;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private AuthProvider provider = AuthProvider.LOCAL;

    @Column(updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
