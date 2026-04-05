import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/coin_movement_controller.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/user_controller.dart';
import '../../core/image_helper.dart';
import '../../models/product_family_model.dart';
import '../../models/product_model.dart';
import '../../services/product_family_service.dart';

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

  final ProductFamilyService _productFamilyService = ProductFamilyService();
  final ImagePicker _picker = ImagePicker();

  List<ProductFamilyModel> _families = [];
  int? _selectedFamilyId;
  bool _isLoadingFamilies = false;

  File? _selectedImageFile;
  String? _imageBase64;
  bool _isPickingImage = false;
  bool _isSubmitting = false;

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
    _loadFamilies();
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshPreview);
    _descriptionController.removeListener(_refreshPreview);
    _priceController.removeListener(_refreshPreview);
    _stockController.removeListener(_refreshPreview);

    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _loadFamilies() async {
    try {
      setState(() {
        _isLoadingFamilies = true;
      });

      final families = await _productFamilyService.getAll();

      if (!mounted) return;

      setState(() {
        _families = families;
        if (_families.isNotEmpty) {
          _selectedFamilyId = _families.first.id;
        }
        _isLoadingFamilies = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingFamilies = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF4E3426),
          content: Text('Error cargando familias: $e'),
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final initialDate = _harvestDate ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(2023),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFC69A5B),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF4E3426),
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      setState(() {
        _harvestDate = date;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isPickingImage = true;
      });

      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1400,
        maxHeight: 1400,
      );

      if (picked == null) {
        if (!mounted) return;
        setState(() {
          _isPickingImage = false;
        });
        return;
      }

      final file = File(picked.path);
      final base64 = await ImageHelper.toBase64(file);

      if (!mounted) return;

      if (base64 == null || base64.isEmpty) {
        setState(() {
          _isPickingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF4E3426),
            content: Text('No se pudo procesar la imagen seleccionada'),
          ),
        );
        return;
      }

      await precacheImage(FileImage(file), context);

      if (!mounted) return;

      setState(() {
        _selectedImageFile = file;
        _imageBase64 = base64;
        _isPickingImage = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isPickingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF4E3426),
          content: Text('Error seleccionando imagen: $e'),
        ),
      );
    }
  }

  Future<void> _showImageSourceSheet() async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seleccionar imagen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4E3426),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Puedes tomar una foto o elegir una imagen desde tu galería.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8C7B6B),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildImageSourceOption(
                    icon: Icons.photo_camera_back_rounded,
                    title: 'Tomar foto',
                    subtitle: 'Usar la cámara del dispositivo',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _pickImage(ImageSource.camera);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildImageSourceOption(
                    icon: Icons.photo_library_rounded,
                    title: 'Elegir de la galería',
                    subtitle: 'Seleccionar una imagen guardada',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _pickImage(ImageSource.gallery);
                    },
                  ),
                  if (_selectedImageFile != null) ...[
                    const SizedBox(height: 10),
                    _buildImageSourceOption(
                      icon: Icons.delete_outline_rounded,
                      title: 'Quitar imagen',
                      subtitle: 'Eliminar la imagen seleccionada',
                      iconColor: const Color(0xFFD96C2F),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _clearSelectedImage();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImageFile = null;
      _imageBase64 = null;
    });
  }

  Future<void> _publishProduct() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (_families.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF4E3426),
          content: Text('No hay familias disponibles para seleccionar'),
        ),
      );
      return;
    }

    if (_selectedFamilyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF4E3426),
          content: Text('Selecciona la familia del producto'),
        ),
      );
      return;
    }

    if (_harvestDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF4E3426),
          content: Text('Selecciona la fecha de cosecha'),
        ),
      );
      return;
    }

    if (_imageBase64 == null || _imageBase64!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF4E3426),
          content: Text('Debes seleccionar o tomar una foto del producto'),
        ),
      );
      return;
    }

    final userController = Provider.of<UserController>(context, listen: false);
    final productController =
    Provider.of<ProductController>(context, listen: false);
    final coinController =
    Provider.of<CoinMovementController>(context, listen: false);

    final currentUser = userController.currentUser;

    if (currentUser == null || currentUser.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF4E3426),
          content: Text('No hay un productor logueado'),
        ),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());

    if (price == null || stock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF4E3426),
          content: Text('Verifica el precio y el stock'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await coinController.loadCoinData(currentUser.id!);

      if (!coinController.hasEnoughBalance(1)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF4E3426),
            content: Text(
              'No tienes monedas suficientes para publicar este producto',
            ),
          ),
        );
        return;
      }

      final discountSuccess = await coinController.useCoinsForProductPublication(
        userId: currentUser.id!,
        amount: 1,
        productName: _nameController.text.trim(),
      );

      if (!mounted) return;

      if (!discountSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF4E3426),
            content: Text(
              coinController.errorMessage ??
                  'No se pudo descontar la moneda para publicar',
            ),
          ),
        );
        return;
      }

      final newProduct = ProductModel(
        id: null,
        name: _nameController.text.trim(),
        picture: _imageBase64,
        description: _normalizeOptionalText(_descriptionController.text),
        price: price,
        unit: _selectedUnit,
        stock: stock,
        state: _selectedStatus == 'Activo' ? 1 : 0,
        harvestDate: _harvestDate,
        userID: currentUser.id!,
        // TODO: cuando actualices ProductModel y ProductService,
        // agrega aquí: familyID: _selectedFamilyId,
      );

      final success = await productController.createProduct(newProduct);

      if (!mounted) return;

      if (success) {
        await coinController.loadCoinData(currentUser.id!);
        await userController.reloadCurrentUser();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF4E3426),
            content: Text(
              'Producto publicado correctamente. Se descontó 1 moneda',
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        final rollbackSuccess = await userController.updateBalance(1);

        if (rollbackSuccess) {
          await coinController.loadCoinData(currentUser.id!);
          await userController.reloadCurrentUser();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF4E3426),
            content: Text(
              rollbackSuccess
                  ? 'No se pudo publicar el producto. Se revirtió el descuento de 1 moneda.'
                  : (productController.errorMessage ??
                  'Error al publicar producto'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _normalizeOptionalText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obligatorio';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obligatorio';
    }

    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Ingresa un precio válido';
    }
    if (parsed <= 0) {
      return 'El precio debe ser mayor a 0';
    }
    return null;
  }

  String? _validateStock(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obligatorio';
    }

    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Ingresa un stock válido';
    }
    if (parsed < 0) {
      return 'El stock no puede ser negativo';
    }
    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha seleccionada';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  double _getMaxContentWidth(double screenWidth) {
    if (screenWidth >= 1400) return 1020;
    if (screenWidth >= 1100) return 920;
    if (screenWidth >= 800) return 780;
    return screenWidth;
  }

  Color _getStatusColor() {
    return _selectedStatus == 'Activo'
        ? const Color(0xFF2E8B57)
        : const Color(0xFF8F8F8F);
  }

  String _getSelectedFamilyName() {
    if (_selectedFamilyId == null) return 'Familia pendiente';

    final family = _families.cast<ProductFamilyModel?>().firstWhere(
          (item) => item?.id == _selectedFamilyId,
      orElse: () => null,
    );

    return family?.name ?? 'Familia pendiente';
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
              hintStyle: const TextStyle(
                color: Color(0xFFAA9B8A),
                fontSize: 13,
              ),
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
                borderSide: const BorderSide(
                  color: Color(0xFFC69A5B),
                  width: 1.4,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFD96C2F),
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFD96C2F),
                  width: 1.4,
                ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(title: title, icon: icon),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: value,
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ),
            )
                .toList(),
            onChanged: onChanged,
            validator: (value) =>
            value == null || value.isEmpty ? 'Campo obligatorio' : null,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF8A6A45),
            ),
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
                borderSide: const BorderSide(
                  color: Color(0xFFC69A5B),
                  width: 1.4,
                ),
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

  Widget _buildFamilyDropdownCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(
            title: 'Familia del producto',
            icon: Icons.category_outlined,
          ),
          const SizedBox(height: 14),
          if (_isLoadingFamilies)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(
                  color: Color(0xFFC69A5B),
                ),
              ),
            )
          else
            DropdownButtonFormField<int>(
              value: _selectedFamilyId,
              items: _families
                  .map(
                    (family) => DropdownMenuItem<int>(
                  value: family.id,
                  child: Text(family.name),
                ),
              )
                  .toList(),
              onChanged: _families.isEmpty
                  ? null
                  : (value) {
                setState(() {
                  _selectedFamilyId = value;
                });
              },
              validator: (value) => value == null ? 'Campo obligatorio' : null,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF8A6A45),
              ),
              dropdownColor: Colors.white,
              decoration: InputDecoration(
                hintText: _families.isEmpty
                    ? 'No hay familias disponibles'
                    : 'Selecciona una familia',
                hintStyle: const TextStyle(
                  color: Color(0xFFAA9B8A),
                  fontSize: 13,
                ),
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
                  borderSide: const BorderSide(
                    color: Color(0xFFC69A5B),
                    width: 1.4,
                  ),
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

  Widget _buildImagePickerCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(
            title: 'Foto del producto',
            icon: Icons.photo_camera_back_outlined,
          ),
          const SizedBox(height: 10),
          const Text(
            'Selecciona una foto desde la galería o toma una con tu cámara.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF8C7B6B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _selectedImageFile != null
                ? ClipRRect(
              key: const ValueKey('image_selected'),
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                _selectedImageFile!,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5EF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 42,
                        color: Color(0xFF8A6A45),
                      ),
                    ),
                  );
                },
              ),
            )
                : Container(
              key: const ValueKey('image_placeholder'),
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5EF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE6DDCF)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 42,
                    color: Color(0xFFC69A5B),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Aún no seleccionaste una imagen',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8C7B6B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isPickingImage ? null : _showImageSourceSheet,
                  icon: _isPickingImage
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(
                    _selectedImageFile == null
                        ? 'Elegir foto'
                        : 'Cambiar foto',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC69A5B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              if (_selectedImageFile != null) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _isPickingImage ? null : _clearSelectedImage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD96C2F),
                    side: const BorderSide(color: Color(0xFFE6DDCF)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Quitar'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFFC69A5B),
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF8F3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9DFD1)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4E3426),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8C7B6B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldHeader({
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F0E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFC69A5B),
            size: 20,
          ),
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

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF5A3E2B),
            size: 20,
          ),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(
                Icons.storefront_outlined,
                color: Color(0xFFC7942E),
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                'Nuevo',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4E3426),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFD6CCBE),
            Color(0xFFC8B9A7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -20,
            right: -8,
            child: Container(
              width: 125,
              height: 125,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -22,
            left: -12,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Colors.black.withOpacity(0.03),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBannerChip(
                      Icons.eco_outlined,
                      'Producto orgánico',
                    ),
                    _buildBannerChip(
                      Icons.inventory_2_outlined,
                      'Catálogo del productor',
                    ),
                    _buildBannerChip(
                      Icons.auto_awesome_outlined,
                      'Publicación premium',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Agrega un producto atractivo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Completa los datos, fotografía real, familia, stock y fecha de cosecha para que tu publicación se vea más profesional.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildHeroMiniStat(
                        icon: Icons.photo_camera_back_outlined,
                        label: 'Foto',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildHeroMiniStat(
                        icon: Icons.category_outlined,
                        label: 'Familia',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildHeroMiniStat(
                        icon: Icons.event_available_outlined,
                        label: 'Cosecha',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMiniStat({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTips() {
    return Row(
      children: [
        Expanded(
          child: _buildTipCard(
            icon: Icons.image_outlined,
            title: 'Usa foto real',
            subtitle: 'Da más confianza al comprador',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTipCard(
            icon: Icons.sell_outlined,
            title: 'Precio claro',
            subtitle: 'Ayuda a vender más rápido',
          ),
        ),
      ],
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0E8DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFC69A5B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4E3426),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF8C7B6B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard() {
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
                      horizontal: 14,
                      vertical: 12,
                    ),
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

  Widget _buildStatusCard() {
    final statusColor = _getStatusColor();

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
                  color: const Color(0xFF2E8B57),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSelectableStatus(
                  label: 'Pausado',
                  value: 'Pausado',
                  color: const Color(0xFF8F8F8F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      onTap: () {
        setState(() {
          _selectedStatus = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : const Color(0xFFF8F5EF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : const Color(0xFFE6DDCF),
          ),
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
                color: selected ? color : const Color(0xFF5A3E2B),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final hasImage = _selectedImageFile != null;

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
              Icon(
                Icons.visibility_outlined,
                color: Color(0xFFC69A5B),
                size: 20,
              ),
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
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F0E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: hasImage
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        _selectedImageFile!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(0xFF888888),
                            size: 38,
                          );
                        },
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
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor().withOpacity(0.11),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _getStatusColor().withOpacity(0.18),
                                ),
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
                          Icons.category_outlined,
                          _getSelectedFamilyName(),
                          const Color(0xFF8A6A45),
                        ),
                        const SizedBox(height: 6),
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
                          Icons.straighten_rounded,
                          _selectedUnit == null
                              ? 'Unidad pendiente'
                              : 'Unidad: $_selectedUnit',
                          const Color(0xFF2E8B57),
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

  Widget _buildPublishButton() {
    return Consumer<ProductController>(
      builder: (context, productController, child) {
        final isBusy =
            productController.isLoading || _isSubmitting || _isLoadingFamilies;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isBusy ? null : _publishProduct,
            icon: isBusy
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.publish_rounded),
            label: Text(
              isBusy ? 'Publicando...' : 'Publicar producto',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
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
            padding: EdgeInsets.zero,
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
                        _buildHeroBanner(),
                        const SizedBox(height: 18),
                        _buildQuickTips(),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
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
                                  Icon(
                                    Icons.edit_note_rounded,
                                    color: Color(0xFFC69A5B),
                                    size: 22,
                                  ),
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
                              const SizedBox(height: 6),
                              const Text(
                                'Completa cada campo para que tu publicación se vea clara, atractiva y profesional.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF8C7B6B),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (isWide) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildInputCard(
                                        title: 'Nombre del producto',
                                        hint: 'Ej. Tomate Cherry Orgánico',
                                        controller: _nameController,
                                        icon: Icons.shopping_basket_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _buildDropdownCard(
                                        title: 'Unidad de medida',
                                        icon: Icons.straighten_rounded,
                                        value: _selectedUnit!,
                                        items: _units,
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedUnit = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                _buildFamilyDropdownCard(),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildInputCard(
                                        title: 'Precio',
                                        hint: 'Ej. 4.5',
                                        controller: _priceController,
                                        icon: Icons.attach_money_rounded,
                                        type:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
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
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedUnit = value;
                                    });
                                  },
                                ),
                                _buildFamilyDropdownCard(),
                                _buildInputCard(
                                  title: 'Precio',
                                  hint: 'Ej. 4.5',
                                  controller: _priceController,
                                  icon: Icons.attach_money_rounded,
                                  type: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
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