package com.ecommerce.platform.service;

import com.ecommerce.platform.entity.Otp;
import com.ecommerce.platform.entity.OtpPurpose;
import com.ecommerce.platform.entity.User;
import com.ecommerce.platform.repository.OtpRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
@RequiredArgsConstructor
public class OtpService {

    private final OtpRepository otpRepository;
    private final NotificationService notificationService;

    @Value("${app.otp.length}")
    private int otpLength;

    @Value("${app.otp.expiration-minutes}")
    private long otpExpirationMinutes;

    private static final SecureRandom RANDOM = new SecureRandom();

    @Transactional
    public void generateAndSend(User user, OtpPurpose purpose, String target) {
        // Invalidate any still-outstanding codes for this user+purpose so
        // only the most recently issued one can ever succeed.
        List<Otp> outstanding = otpRepository.findByUserIdAndPurposeAndUsedFalse(user.getId(), purpose);
        outstanding.forEach(o -> o.setUsed(true));
        otpRepository.saveAll(outstanding);

        String code = generateCode();
        Otp otp = Otp.builder()
                .user(user)
                .code(code)
                .purpose(purpose)
                .target(target)
                .expiryDate(Instant.now().plus(otpExpirationMinutes, ChronoUnit.MINUTES))
                .used(false)
                .build();
        otpRepository.save(otp);

        send(purpose, target, code);
    }

    /**
     * Validates the code and marks it used. Returns the matched Otp (its
     * `target` is what the caller needs for PHONE_VERIFICATION, to know
     * which number to actually save onto the User).
     */
    @Transactional
    public Otp verify(User user, OtpPurpose purpose, String code) {
        Otp otp = otpRepository
                .findTopByUserIdAndPurposeAndCodeAndUsedFalseOrderByIdDesc(user.getId(), purpose, code)
                .orElseThrow(() -> new IllegalArgumentException("Invalid OTP — no matching unused code found"));

        if (otp.getExpiryDate().isBefore(Instant.now())) {
            throw new IllegalArgumentException(
                    "OTP expired (issued " + otp.getCreatedAt() + ", expired " + otp.getExpiryDate() +
                            ", now " + Instant.now() + ")");
        }

        otp.setUsed(true);
        return otpRepository.save(otp);
    }

    private void send(OtpPurpose purpose, String target, String code) {
        switch (purpose) {
            case EMAIL_VERIFICATION -> notificationService.sendEmail(target, "Verify your email",
                    "Your verification code is " + code + ". It expires in " + otpExpirationMinutes + " minutes.");
            case LOGIN -> notificationService.sendEmail(target, "Your login code",
                    "Your one-time login code is " + code + ". It expires in " + otpExpirationMinutes + " minutes.");
            case PASSWORD_RESET -> notificationService.sendEmail(target, "Password Reset Code",
                    "Your password reset code is " + code + ". It expires in " + otpExpirationMinutes + " minutes.");
            case PHONE_VERIFICATION -> notificationService.sendSms(target,
                    "Your verification code is " + code + ". It expires in " + otpExpirationMinutes + " minutes.");
        }
    }

    private String generateCode() {
        StringBuilder sb = new StringBuilder(otpLength);
        for (int i = 0; i < otpLength; i++) {
            sb.append(RANDOM.nextInt(10));
        }
        return sb.toString();
    }
}
