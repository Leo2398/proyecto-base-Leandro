import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/product_controller.dart';
import '../../controllers/user_controller.dart';
import '../../core/cloudinary_helper.dart';
import '../../models/product_model.dart';

class ProducerCreateProductView extends StatefulWidget {
  const ProducerCreateProductView({super.key});

  @override
  State<ProducerCreateProductView> createState() =>
      _ProducerCreateProductViewState();
}

class _ProducerCreateProductViewState
    extends State<ProducerCreateProductView> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  // ── Imagen ──────────────────────────────────────────────────────────────────
  File? _selectedImage;        // archivo local elegido por el usuario
  String? _uploadedImageUrl;   // URL de Cloudinary → se guarda en la BD
  bool _isUploadingImage = false;
  // ────────────────────────────────────────────────────────────────────────────

  DateTime? _harvestDate;
  String? _selectedUnit;
  String _selectedStatus = 'Activo';

  final List<String> _units = [
    'kg',
    'unidad',
    'caja',
    'bolsa',
    'docena',
    'litro',
  ];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refreshPreview);
    _descriptionController.addListener(_refreshPreview);
    _priceController.addListener(_refreshPreview);
    _stockController.addListener(_refreshPreview);
    _selectedUnit = _units.first;
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_refreshPreview)
      ..dispose();
    _descriptionController
      ..removeListener(_refreshPreview)
      ..dispose();
    _priceController
      ..removeListener(_refreshPreview)
      ..dispose();
    _stockController
      ..removeListener(_refreshPreview)
      ..dispose();
    super.dispose();
  }

  // ── Imagen: elegir y subir ──────────────────────────────────────────────────

  Future<void> _pickAndUploadImage() async {
    // Pregunta si galería o cámara
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() {
      _selectedImage = File(picked.path);
      _isUploadingImage = true;
      _uploadedImageUrl = null;
    });

    final url = await CloudinaryHelper.uploadImage(_selectedImage!);

    if (!mounted) return;
    setState(() {
      _isUploadingImage = false;
      _uploadedImageUrl = url;
    });

    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF4E3426),
          content: Text('Error al subir la imagen. Intenta de nuevo.'),
        ),
      );
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0D8CE),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Text(
                'Seleccionar imagen',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E3426),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF5F0E8),
                  child: Icon(Icons.photo_library_outlined,
                      color: Color(0xFFC69A5B)),
                ),
                title: const Text('Galería de fotos'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF5F0E8),
                  child: Icon(Icons.camera_alt_outlined,
                      color: Color(0xFFC69A5B)),
                ),
                title: const Text('Cámara'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Fecha ───────────────────────────────────────────────────────────────────

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _harvestDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFC69A5B),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF4E3426),
          ),
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) setState(() => _harvestDate = date);
  }

  // ── Publicar ────────────────────────────────────────────────────────────────

  Future<void> _publishProduct() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_harvestDate == null) {
      _showSnack('Selecciona la fecha de cosecha');
      return;
    }

    if (_uploadedImageUrl == null) {
      _showSnack('Selecciona una foto del producto');
      return;
    }

    final userController = Provider.of<UserController>(context, listen: false);
    final productController =
        Provider.of<ProductController>(context, listen: false);

    final currentUser = userController.currentUser;
    if (currentUser == null || currentUser.id == null) {
      _showSnack('No hay un productor logueado');
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());
    if (price == null || stock == null) {
      _showSnack('Verifica el precio y el stock');
      return;
    }

    final newProduct = ProductModel(
      id: null,
      name: _nameController.text.trim(),
      picture: _uploadedImageUrl, // ← URL de Cloudinary → se guarda en BD
      description: _normalizeOptionalText(_descriptionController.text),
      price: price,
      unit: _selectedUnit,
      stock: stock,
      state: _selectedStatus == 'Activo' ? 1 : 0,
      harvestDate: _harvestDate,
      userID: currentUser.id!,
    );

    final success = await productController.createProduct(newProduct);
    if (!mounted) return;

    if (success) {
      _showSnack('Producto publicado correctamente');
      Navigator.pop(context, true);
    } else {
      _showSnack(productController.errorMessage ?? 'Error al publicar producto');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF4E3426),
        content: Text(message),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String? _normalizeOptionalText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _validateRequired(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Campo obligatorio' : null;

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obligatorio';
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Ingresa un precio válido';
    if (parsed <= 0) return 'El precio debe ser mayor a 0';
    return null;
  }

  String? _validateStock(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obligatorio';
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Ingresa un stock válido';
    if (parsed < 0) return 'El stock no puede ser negativo';
    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha seleccionada';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  double _getMaxContentWidth(double screenWidth) {
    if (screenWidth >= 1400) return 1020;
    if (screenWidth >= 1100) return 920;
    if (screenWidth >= 800) return 780;
    return screenWidth;
  }

  Color _getStatusColor() => _selectedStatus == 'Activo'
      ? const Color(0xFF2E8B57)
      : const Color(0xFF8F8F8F);

  // ── Widgets de campo ────────────────────────────────────────────────────────

  Widget _buildFieldHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F0E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFC69A5B), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4E3426),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8DED0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInputCard({
    required String title,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    String? suffixText,
    String? Function(String?)? customValidator,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(title: title, icon: icon),
          const SizedBox(height: 14),
          TextFormField(
            controller: controller,
            keyboardType: type,
            maxLines: maxLines,
            validator: customValidator ?? _validateRequired,
            style: const TextStyle(
              color: Color(0xFF4E3426),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: Color(0xFFAA9B8A), fontSize: 13),
              suffixText: suffixText,
              suffixStyle: const TextStyle(
                color: Color(0xFF8A6A45),
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: const Color(0xFFF8F5EF),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: maxLines > 1 ? 16 : 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE6DDCF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE6DDCF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFFC69A5B), width: 1.4),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFD96C2F)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFFD96C2F), width: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownCard({
    required String title,
    required IconData icon,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(title: title, icon: icon),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: value,
            items: items
                .map((item) =>
                    DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: onChanged,
            validator: (v) =>
                v == null || v.isEmpty ? 'Campo obligatorio' : null,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF8A6A45)),
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8F5EF),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE6DDCF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE6DDCF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFFC69A5B), width: 1.4),
              ),
            ),
            style: const TextStyle(
              color: Color(0xFF4E3426),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Image Picker Card ───────────────────────────────────────────────────────

  Widget _buildImagePickerCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(
            title: 'Foto del producto',
            icon: Icons.image_outlined,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _isUploadingImage ? null : _pickAndUploadImage,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5EF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _uploadedImageUrl != null
                      ? const Color(0xFF2E8B57)
                      : const Color(0xFFE6DDCF),
                  width: _uploadedImageUrl != null ? 1.5 : 1,
                ),
              ),
              child: _buildImageContent(),
            ),
          ),
          if (_uploadedImageUrl != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF2E8B57), size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Imagen subida correctamente',
                    style: TextStyle(
                      color: Color(0xFF2E8B57),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Cambiar'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFC69A5B),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_uploadedImageUrl == null && !_isUploadingImage) ...[
            const SizedBox(height: 8),
            const Text(
              '* La foto es obligatoria para publicar el producto',
              style: TextStyle(
                color: Color(0xFFAA9B8A),
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    // Subiendo
    if (_isUploadingImage) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFFC69A5B),
            strokeWidth: 2.5,
          ),
          SizedBox(height: 12),
          Text(
            'Subiendo imagen...',
            style: TextStyle(
              color: Color(0xFF8A6A45),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    // Imagen seleccionada (muestra preview local)
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    // Sin imagen
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFF0EBE0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.add_photo_alternate_outlined,
            size: 34,
            color: Color(0xFFC69A5B),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Toca para elegir una foto',
          style: TextStyle(
            color: Color(0xFF8A6A45),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Galería o cámara',
          style: TextStyle(color: Color(0xFFAA9B8A), fontSize: 12),
        ),
      ],
    );
  }

  // ── Date Card ───────────────────────────────────────────────────────────────

  Widget _buildDateCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(
            title: 'Fecha de cosecha',
            icon: Icons.calendar_month_outlined,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5EF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE6DDCF)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _harvestDate == null
                        ? 'Selecciona la fecha de cosecha'
                        : 'Cosecha: ${_formatDate(_harvestDate)}',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: _harvestDate == null
                          ? const Color(0xFFAA9B8A)
                          : const Color(0xFF4E3426),
                      fontWeight: _harvestDate == null
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.event_available_outlined, size: 18),
                  label: const Text('Elegir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC69A5B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Status Card ─────────────────────────────────────────────────────────────

  Widget _buildStatusCard() {
    final statusColor = _getStatusColor();
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(
            title: 'Estado de publicación',
            icon: Icons.toggle_on_outlined,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _buildSelectableStatus(
                      label: 'Activo',
                      value: 'Activo',
                      color: const Color(0xFF2E8B57))),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildSelectableStatus(
                      label: 'Pausado',
                      value: 'Pausado',
                      color: const Color(0xFF8F8F8F))),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedStatus == 'Activo'
                      ? Icons.check_circle_outline_rounded
                      : Icons.pause_circle_outline_rounded,
                  size: 18,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedStatus == 'Activo'
                        ? 'El producto se mostrará inmediatamente en tu catálogo.'
                        : 'El producto se guardará en estado pausado.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableStatus({
    required String label,
    required String value,
    required Color color,
  }) {
    final selected = _selectedStatus == value;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _selectedStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.12)
              : const Color(0xFFF8F5EF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? color : const Color(0xFFE6DDCF)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? color : const Color(0xFF9A8E80),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color:
                    selected ? color : const Color(0xFF5A3E2B),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preview Card ────────────────────────────────────────────────────────────

  Widget _buildPreviewCard() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.visibility_outlined,
                  color: Color(0xFFC69A5B), size: 20),
              SizedBox(width: 8),
              Text(
                'Vista previa rápida',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E3426),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFEFC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF0E8DC)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagen preview: muestra el archivo local si existe
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F0E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.inventory_2_outlined,
                            color: Color(0xFFC69A5B),
                            size: 38,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _nameController.text.trim().isEmpty
                                  ? 'Nombre del producto'
                                  : _nameController.text.trim(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4E3426),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor().withOpacity(0.11),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color:
                                        _getStatusColor().withOpacity(0.18)),
                              ),
                              child: Text(
                                _selectedStatus,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _getStatusColor(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _descriptionController.text.trim().isEmpty
                              ? 'Aquí aparecerá la descripción del producto.'
                              : _descriptionController.text.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF8C7B6B),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildPreviewInfo(
                          Icons.monetization_on_outlined,
                          _priceController.text.trim().isEmpty
                              ? 'Precio pendiente'
                              : '${_priceController.text.trim()} monedas / ${_selectedUnit ?? '-'}',
                          const Color(0xFFC7942E),
                        ),
                        const SizedBox(height: 6),
                        _buildPreviewInfo(
                          Icons.inventory_2_outlined,
                          _stockController.text.trim().isEmpty
                              ? 'Stock pendiente'
                              : 'Stock: ${_stockController.text.trim()}',
                          const Color(0xFF8A6A45),
                        ),
                        const SizedBox(height: 6),
                        _buildPreviewInfo(
                          Icons.calendar_month_outlined,
                          _harvestDate == null
                              ? 'Fecha de cosecha pendiente'
                              : _formatDate(_harvestDate),
                          const Color(0xFF2E8B57),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewInfo(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF7A6D60),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ── Top bar y banner (sin cambios) ──────────────────────────────────────────

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF5A3E2B), size: 20),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(10),
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.08),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Publicar producto',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E3426),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Crea un nuevo producto para tu catálogo',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8C7B6B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Publish Button ──────────────────────────────────────────────────────────

  Widget _buildPublishButton() {
    return Consumer<ProductController>(
      builder: (context, productController, _) {
        final isDisabled = productController.isLoading || _isUploadingImage;
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isDisabled ? null : _publishProduct,
            icon: isDisabled
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.publish_rounded),
            label: Text(
              isDisabled ? 'Procesando...' : 'Publicar producto',
              style: const TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC69A5B),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFD0B48C),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = _getMaxContentWidth(screenWidth);
    final isWide = screenWidth >= 860;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF5F0E8),
              Color(0xFFF7F2EA),
              Color(0xFFF2ECE2),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.fromLTRB(16, 18, 16, 22),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.edit_note_rounded,
                                      color: Color(0xFFC69A5B), size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'Información del producto',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4E3426),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              if (isWide) ...[
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildInputCard(
                                        title: 'Nombre del producto',
                                        hint: 'Ej. Tomate Cherry Orgánico',
                                        controller: _nameController,
                                        icon:
                                            Icons.shopping_basket_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _buildDropdownCard(
                                        title: 'Unidad de medida',
                                        icon: Icons.straighten_rounded,
                                        value: _selectedUnit!,
                                        items: _units,
                                        onChanged: (v) => setState(
                                            () => _selectedUnit = v),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildInputCard(
                                        title: 'Precio',
                                        hint: 'Ej. 4.5',
                                        controller: _priceController,
                                        icon: Icons.attach_money_rounded,
                                        type: const TextInputType
                                            .numberWithOptions(
                                            decimal: true),
                                        suffixText: 'monedas',
                                        customValidator: _validatePrice,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _buildInputCard(
                                        title: 'Stock disponible',
                                        hint: 'Ej. 25',
                                        controller: _stockController,
                                        icon: Icons.inventory_2_outlined,
                                        type: TextInputType.number,
                                        customValidator: _validateStock,
                                      ),
                                    ),
                                  ],
                                ),
                                _buildStatusCard(),
                              ] else ...[
                                _buildInputCard(
                                  title: 'Nombre del producto',
                                  hint: 'Ej. Tomate Cherry Orgánico',
                                  controller: _nameController,
                                  icon: Icons.shopping_basket_outlined,
                                ),
                                _buildDropdownCard(
                                  title: 'Unidad de medida',
                                  icon: Icons.straighten_rounded,
                                  value: _selectedUnit!,
                                  items: _units,
                                  onChanged: (v) =>
                                      setState(() => _selectedUnit = v),
                                ),
                                _buildInputCard(
                                  title: 'Precio',
                                  hint: 'Ej. 4.5',
                                  controller: _priceController,
                                  icon: Icons.attach_money_rounded,
                                  type: const TextInputType
                                      .numberWithOptions(decimal: true),
                                  suffixText: 'monedas',
                                  customValidator: _validatePrice,
                                ),
                                _buildInputCard(
                                  title: 'Stock disponible',
                                  hint: 'Ej. 25',
                                  controller: _stockController,
                                  icon: Icons.inventory_2_outlined,
                                  type: TextInputType.number,
                                  customValidator: _validateStock,
                                ),
                                _buildStatusCard(),
                              ],
                              _buildInputCard(
                                title: 'Descripción',
                                hint:
                                    'Describe el producto, calidad, uso o beneficio principal',
                                controller: _descriptionController,
                                icon: Icons.notes_rounded,
                                maxLines: 4,
                              ),
                              // ← AQUÍ: picker en lugar del campo URL
                              _buildImagePickerCard(),
                              _buildDateCard(),
                              _buildPreviewCard(),
                              const SizedBox(height: 22),
                              _buildPublishButton(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}