import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';

/// A deterministic, pleasant gradient for a product's placeholder art —
/// used whenever a product has no uploaded photo yet.
const _gradients = [
  [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  [Color(0xFFF59E0B), Color(0xFFEF4444)],
  [Color(0xFF06B6D4), Color(0xFF3B82F6)],
  [Color(0xFF10B981), Color(0xFF22C55E)],
  [Color(0xFFEC4899), Color(0xFFF43F5E)],
  [Color(0xFF8B5CF6), Color(0xFFD946EF)],
  [Color(0xFF0EA5E9), Color(0xFF6366F1)],
];

List<Color> gradientForId(int id) => _gradients[id % _gradients.length];

/// Fills the available space with the product's uploaded photo, or a
/// generated gradient "brand tile" with its initial when no photo exists.
class ProductImage extends StatelessWidget {
  final int id;
  final String name;
  final String? imageUrl;
  final double letterSize;

  const ProductImage({
    super.key,
    required this.id,
    required this.name,
    required this.imageUrl,
    this.letterSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = AppConfig.resolveImageUrl(imageUrl);
    final colors = gradientForId(id);

    if (resolvedUrl != null) {
      return CachedNetworkImage(
        imageUrl: resolvedUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => _placeholderTile(colors),
        errorWidget: (context, url, error) => _placeholderTile(colors),
      );
    }
    return _placeholderTile(colors);
  }

  Widget _placeholderTile(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(fontSize: letterSize, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
      ),
    );
  }
}
