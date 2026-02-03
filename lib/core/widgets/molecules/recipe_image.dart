import 'package:flutter/material.dart';

/// Helper Widget für Recipe-Bilder
/// Unterstützt sowohl Asset-Pfade als auch Netzwerk-URLs
class RecipeImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const RecipeImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  /// Prüft ob es ein Asset-Pfad ist
  bool get isAssetPath {
    if (imageUrl == null || imageUrl!.isEmpty) return false;
    return imageUrl!.startsWith('assets/');
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return placeholder ?? _buildDefaultPlaceholder();
    }

    if (isAssetPath) {
      // Asset-Pfad: Verwende Image.asset
      return Image.asset(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? placeholder ?? _buildDefaultPlaceholder();
        },
      );
    } else {
      // Netzwerk-URL: Verwende Image.network
      return Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? placeholder ?? _buildDefaultPlaceholder();
        },
      );
    }
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: width,
      height: height ?? 200,
      color: Colors.grey[200],
      child: const Icon(
        Icons.restaurant_menu_rounded,
        size: 48,
        color: Colors.grey,
      ),
    );
  }
}

