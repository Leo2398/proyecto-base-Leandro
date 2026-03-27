import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Helper para subir imágenes a Cloudinary
/// Guarda la URL resultante en la base de datos (campo picture de Product)
class CloudinaryHelper {
  // ─── Configura estos valores con tu cuenta de Cloudinary ───────────────────
  // 1. Entra a cloudinary.com y crea una cuenta gratis
  // 2. Tu Cloud Name está en el Dashboard principal
  // 3. Ve a Settings → Upload → Upload Presets → Add upload preset
  //    Ponlo en modo "Unsigned" y copia el nombre
  static const String _cloudName = 'dfdezemn1';
  static const String _uploadPreset = 'app_pedidos';
  // ───────────────────────────────────────────────────────────────────────────

  /// Sube una imagen a Cloudinary y retorna la URL pública (https://...)
  /// Esa URL es la que se guarda en la columna `picture` de la tabla Product
  static Future<String?> uploadImage(File imageFile) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final json = jsonDecode(responseBody);

      if (streamedResponse.statusCode == 200) {
        final url = json['secure_url'] as String?;
        print('✓ Imagen subida: $url');
        return url;
      } else {
        print('Error Cloudinary ${streamedResponse.statusCode}: $responseBody');
        return null;
      }
    } catch (e) {
      print('Error en uploadImage: $e');
      return null;
    }
  }

  /// Elimina una imagen de Cloudinary dado su public_id
  /// Útil si el productor cambia la foto de un producto existente
  static Future<bool> deleteImage(String publicId) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/destroy',
      );

      final response = await http.post(
        uri,
        body: {
          'public_id': publicId,
          'upload_preset': _uploadPreset,
        },
      );

      final json = jsonDecode(response.body);
      return json['result'] == 'ok';
    } catch (e) {
      print('Error en deleteImage: $e');
      return false;
    }
  }

  /// Extrae el public_id de una URL de Cloudinary
  /// Ejemplo: https://res.cloudinary.com/demo/image/upload/v123/productos/abc.jpg
  /// Retorna: productos/abc
  static String? extractPublicId(String cloudinaryUrl) {
    try {
      final uri = Uri.parse(cloudinaryUrl);
      final segments = uri.pathSegments;
      // Busca el segmento después de 'upload'
      final uploadIndex = segments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex + 2 >= segments.length) return null;
      // Salta la versión (v123456) y une el resto sin extensión
      final pathParts = segments.sublist(uploadIndex + 2);
      final joined = pathParts.join('/');
      final dotIndex = joined.lastIndexOf('.');
      return dotIndex != -1 ? joined.substring(0, dotIndex) : joined;
    } catch (_) {
      return null;
    }
  }
}