package com.ecommerce.platform.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class VerifyOtpLoginRequest {

    @NotBlank
    @Email
    private String email;

    @NotBlank(message = "otp is required")
    private String otp;
}
