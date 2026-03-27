import 'package:flutter/material.dart';

/// Widget reutilizable para mostrar la imagen de un producto.
/// Lee la URL guardada en la BD (campo `picture` de ProductModel)
/// y la muestra con Image.network.
///
/// Uso:
///   ProductImage(url: product.picture, size: 96)
///   ProductImage(url: product.picture, width: 200, height: 140, radius: 16)
class ProductImage extends StatelessWidget {
  final String? url;

  /// Tamaño cuadrado (usa este O usa width + height, no ambos)
  final double? size;

  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;

  const ProductImage({
    super.key,
    required this.url,
    this.size,
    this.width,
    this.height,
    this.radius = 16,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final double w = size ?? width ?? 80;
    final double h = size ?? height ?? 80;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: _buildImage(w, h),
      ),
    );
  }

  Widget _buildImage(double w, double h) {
    if (url == null || url!.isEmpty) {
      return _placeholder();
    }

    return Image.network(
      url!,
      width: w,
      height: h,
      fit: fit,
      // Muestra un shimmer/placeholder mientras carga
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _loadingIndicator(loadingProgress, w, h);
      },
      // Si la URL falla muestra ícono de error
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _loadingIndicator(ImageChunkEvent progress, double w, double h) {
    final percent = progress.expectedTotalBytes != null
        ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
        : null;

    return Container(
      width: w,
      height: h,
      color: const Color(0xFFF0EBE0),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            value: percent,
            strokeWidth: 2,
            color: const Color(0xFFC69A5B),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF5F0E8),
      child: const Center(
        child: Icon(
          Icons.eco_outlined,
          color: Color(0xFFC69A5B),
          size: 30,
        ),
      ),
    );
  }
}

/// Versión rectangular para cards de producto (ej: en el dashboard del cliente)
///
/// Uso:
///   ProductImageCard(url: product.picture)
class ProductImageCard extends StatelessWidget {
  final String? url;
  final double height;
  final double borderRadius;

  const ProductImageCard({
    super.key,
    required this.url,
    this.height = 140,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return ProductImage(
      url: url,
      width: double.infinity,
      height: height,
      radius: borderRadius,
      fit: BoxFit.cover,
    );
  }
}