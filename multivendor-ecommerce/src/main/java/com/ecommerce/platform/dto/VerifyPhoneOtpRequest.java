package com.ecommerce.platform.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class VerifyPhoneOtpRequest {

    @NotBlank(message = "otp is required")
    private String otp;
}
