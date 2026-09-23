import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Read-only star display for an average rating (e.g. 4.3).
class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final bool showValue;

  const RatingStars({super.key, required this.rating, this.size = 16, this.showValue = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final filled = rating >= i + 1;
          final half = !filled && rating > i && rating < i + 1;
          return Icon(
            half ? Icons.star_half_rounded : (filled ? Icons.star_rounded : Icons.star_border_rounded),
            size: size,
            color: rating > 0 ? AppColors.secondary : AppColors.textSecondary.withValues(alpha: 0.4),
          );
        }),
        if (showValue) ...[
          const SizedBox(width: 4),
          Text(
            rating > 0 ? rating.toStringAsFixed(1) : 'New',
            style: TextStyle(fontSize: size * 0.78, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

/// Interactive star picker used when writing a review.
class RatingPicker extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  final double size;

  const RatingPicker({super.key, required this.rating, required this.onChanged, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = rating >= i + 1;
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => onChanged(i + 1),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            size: size,
            color: AppColors.secondary,
          ),
        );
      }),
    );
  }
}
