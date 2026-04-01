import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

/// Helper para convertir imágenes a Base64 y guardarlas directo en la BD
/// Reemplaza completamente a CloudinaryHelper
class ImageHelper {
  /// Convierte un File de imagen a string Base64 con prefijo de tipo MIME
  /// El string resultante se guarda directo en la columna picture/image de la BD
  /// y se usa con Image.memory() para mostrarlo
  static Future<String?> toBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final extension = imageFile.path.split('.').last.toLowerCase();
      final mime = _mimeFromExtension(extension);
      // Formato: data:image/jpeg;base64,/9j/4AAQ...
      return 'data:$mime;base64,$base64String';
    } catch (e) {
      print('Error convirtiendo imagen a Base64: $e');
      return null;
    }
  }

  static String _mimeFromExtension(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Verifica si un string es Base64 (guardado en BD) o una URL externa
  static bool isBase64(String? value) {
    if (value == null) return false;
    return value.startsWith('data:image');
  }
}

/// Widget unificado para mostrar imágenes que pueden ser Base64 o URL
/// Úsalo en cualquier lugar donde muestres fotos de productos o comprobantes
class AppImage extends StatelessWidget {
  final String? src;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? placeholder;

  const AppImage({
    super.key,
    required this.src,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (src == null || src!.isEmpty) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ImageHelper.isBase64(src)
          ? _buildBase64Image()
          : _buildNetworkImage(),
    );
  }

  Widget _buildBase64Image() {
    try {
      // Extrae solo la parte Base64 (después de la coma)
      final base64Data = src!.split(',').last;
      final bytes = base64Decode(base64Data);
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } catch (_) {
      return _buildPlaceholder();
    }
  }

  Widget _buildNetworkImage() {
    return Image.network(
      src!,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFF5F0E8),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF5A8A5A),
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return placeholder ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFFF5F0E8),
          child: const Center(
            child: Icon(
              Icons.eco_outlined,
              color: Color(0xFF5A8A5A),
              size: 30,
            ),
          ),
        );
  }
}