import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';

/// Circular profile picture that's tappable to change. Shows the user's
/// uploaded photo when present, otherwise their initial on a tinted
/// background — and always overlays a small camera badge so it reads as
/// interactive.
class AvatarPicker extends StatelessWidget {
  final double radius;

  const AvatarPicker({super.key, this.radius = 40});

  Future<void> _pick(BuildContext context) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await picker.pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (image == null || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.uploadProfilePicture(image);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.errorMessage ?? 'Could not upload photo')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final resolvedUrl = AppConfig.resolveImageUrl(auth.profileImageUrl);
    final initial = (auth.fullName ?? auth.email ?? '?').isNotEmpty
        ? (auth.fullName ?? auth.email ?? '?')[0].toUpperCase()
        : '?';

    return InkWell(
      onTap: auth.isUploadingPhoto ? null : () => _pick(context),
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: resolvedUrl != null ? NetworkImage(resolvedUrl) : null,
            child: resolvedUrl == null
                ? Text(
                    initial,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: radius * 0.7,
                    ),
                  )
                : null,
          ),
          if (auth.isUploadingPhoto)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  ),
                ),
              ),
            )
          else
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
