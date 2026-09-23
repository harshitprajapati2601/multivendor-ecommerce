package com.ecommerce.platform.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Set;
import java.util.UUID;

/**
 * Minimal local-disk image storage. Files are saved under
 * {app.upload.dir}/{subDir}/ and served back by WebConfig's resource
 * handler at /uploads/{subDir}/{filename} - no cloud bucket needed for
 * local development. Swap this out for an S3/GCS implementation later
 * without touching any caller.
 */
@Service
public class FileStorageService {

    private static final Set<String> ALLOWED_CONTENT_TYPES =
            Set.of("image/jpeg", "image/png", "image/webp", "image/gif");
    private static final long MAX_FILE_SIZE_BYTES = 5L * 1024 * 1024; // 5MB, mirrors application.properties

    @Value("${app.upload.dir:uploads}")
    private String uploadDir;

    /**
     * Validates and stores an image, returning a relative URL like
     * "/uploads/products/3f9c1e2a.jpg" to persist on the owning entity.
     */
    public String storeImage(MultipartFile file, String subDir) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("No file was uploaded");
        }
        if (file.getSize() > MAX_FILE_SIZE_BYTES) {
            throw new IllegalArgumentException("Image must be smaller than 5MB");
        }
        String contentType = file.getContentType();
        if (contentType == null || !ALLOWED_CONTENT_TYPES.contains(contentType.toLowerCase())) {
            throw new IllegalArgumentException("Only JPEG, PNG, WEBP or GIF images are allowed");
        }

        try {
            Path targetDir = Paths.get(uploadDir, subDir).toAbsolutePath().normalize();
            Files.createDirectories(targetDir);

            String extension = extensionFor(contentType, file.getOriginalFilename());
            String filename = UUID.randomUUID() + extension;
            Path targetFile = targetDir.resolve(filename);

            try (var in = file.getInputStream()) {
                Files.copy(in, targetFile, StandardCopyOption.REPLACE_EXISTING);
            }

            return "/uploads/" + subDir + "/" + filename;
        } catch (IOException ex) {
            throw new UncheckedIOException("Failed to store uploaded image", ex);
        }
    }

    private String extensionFor(String contentType, String originalFilename) {
        String fromName = StringUtils.getFilenameExtension(originalFilename);
        if (fromName != null && !fromName.isBlank()) {
            return "." + fromName.toLowerCase();
        }
        return switch (contentType.toLowerCase()) {
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";
            case "image/gif" -> ".gif";
            default -> ".jpg";
        };
    }
}
