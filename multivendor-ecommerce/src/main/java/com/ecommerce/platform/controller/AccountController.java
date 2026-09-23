package com.ecommerce.platform.controller;

import com.ecommerce.platform.dto.UpdateProfileRequest;
import com.ecommerce.platform.dto.UserProfileResponse;
import com.ecommerce.platform.service.AccountService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

// Same reasoning as PhoneController: not under /api/auth/**, so it falls
// through to anyRequest().authenticated() in SecurityConfig - any signed-in
// user of any role can read/update their own profile.
@RestController
@RequestMapping("/api/account")
@RequiredArgsConstructor
public class AccountController {

    private final AccountService accountService;

    @GetMapping("/me")
    public ResponseEntity<UserProfileResponse> getMyProfile() {
        return ResponseEntity.ok(accountService.getMyProfile());
    }

    @RequestMapping(value = "/me", method = {RequestMethod.PUT, RequestMethod.POST, RequestMethod.PATCH})
    public ResponseEntity<UserProfileResponse> updateMyProfile(@Valid @RequestBody UpdateProfileRequest request) {
        return ResponseEntity.ok(accountService.updateProfile(request));
    }


    // Multipart upload: field name must be "file". Overwrites any previous picture.
    @PostMapping(value = "/profile-picture", consumes = "multipart/form-data")
    public ResponseEntity<UserProfileResponse> uploadProfilePicture(@RequestParam("file") MultipartFile file) {
        return ResponseEntity.ok(accountService.updateProfilePicture(file));
    }
}

