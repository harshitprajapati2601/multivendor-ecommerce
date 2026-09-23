package com.ecommerce.platform.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

/**
 * Handles email and SMS dispatch across the application.
 * If JavaMailSender is configured (via Spring Boot mail properties),
 * emails are transmitted over SMTP. Otherwise, email contents are logged
 * cleanly for local development.
 */
@Service
@Slf4j
public class NotificationService {

    @Autowired(required = false)
    private JavaMailSender mailSender;

    @Value("${app.mail.from:admin@multimart.com}")
    private String fromEmail;

    public void sendEmail(String toEmail, String subject, String body) {
        log.info("==== EMAIL DISPATCH ====\nFrom: {}\nTo: {}\nSubject: {}\nBody: {}\n========================",
                fromEmail, toEmail, subject, body);

        if (mailSender != null) {
            try {
                SimpleMailMessage message = new SimpleMailMessage();
                message.setFrom(fromEmail);
                message.setTo(toEmail);
                message.setSubject(subject);
                message.setText(body);
                mailSender.send(message);
                log.info("Successfully sent email via SMTP to {}", toEmail);
            } catch (Exception e) {
                log.error("Failed to send email via JavaMailSender: {}", e.getMessage());
            }
        }
    }

    public void sendSms(String toPhoneNumber, String message) {
        log.info("==== SMS DISPATCH ====\nTo: {}\nMessage: {}\n===================",
                toPhoneNumber, message);
    }
}
