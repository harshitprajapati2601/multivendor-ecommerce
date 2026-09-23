package com.ecommerce.platform.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Day 8 scaffolding: hit each endpoint with tokens from a CUSTOMER, a SELLER,
 * and an ADMIN account and confirm you get 200 / 403 as expected.
 * Delete this once real role-protected endpoints exist in Phase 3+.
 */
@RestController
@RequestMapping("/api/test")
public class RoleTestController {

    @GetMapping("/customer")
    @PreAuthorize("hasRole('CUSTOMER')")
    public String customerOnly() {
        return "Hello CUSTOMER - your token works.";
    }

    @GetMapping("/seller")
    @PreAuthorize("hasRole('SELLER')")
    public String sellerOnly() {
        return "Hello SELLER - your token works.";
    }

    @GetMapping("/admin")
    @PreAuthorize("hasRole('ADMIN')")
    public String adminOnly() {
        return "Hello ADMIN - your token works.";
    }

    @GetMapping("/any-authenticated")
    public String anyAuthenticated() {
        return "Any logged-in user can see this.";
    }
}
