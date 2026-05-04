import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/product_controller.dart';
import '../../core/image_helper.dart';
import '../../models/product_family_model.dart';
import '../../models/product_model.dart';
import '../../services/product_family_service.dart';

class ProducerEditProductView extends StatefulWidget {
  final ProductModel product;

  const ProducerEditProductView({
    super.key,
    required this.product,
  });

  @override
  State<ProducerEditProductView> createState() =>
      _ProducerEditProductViewState();
}

class _ProducerEditProductViewState extends State<ProducerEditProductView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  final ImagePicker _picker = ImagePicker();
  final ProductFamilyService _productFamilyService = ProductFamilyService();

  DateTime? _harvestDate;
  String _selectedUnit = 'kg';
  String _selectedStatus = 'Activo';

  File? _selectedImageFile;
  String? _imageBase64OrUrl;

  List<ProductFamilyModel> _families = [];
  int? _selectedFamilyId;

  bool _isLoadingFamilies = false;
  bool _isPickingImage = false;
  bool _isSubmitting = false;
  bool _isRefreshing = false;

  final List<String> _units = const [
    'kg',
    'unidad',
    'caja',
    'bolsa',
    'docena',
    'litro',
  ];

  // ─── Paleta visual del productor ───────────────────────────────────────────
  static const Color _bgTop = Color(0xFFF7F2EA);
  static const Color _bgBottom = Color(0xFFE8DAC9);

  static const Color _surface = Colors.white;
  static const Color _surfaceSoft = Color(0xFFFFFCF8);
  static const Color _surfaceMuted = Color(0xFFF7EFE5);

  static const Color _primary = Color(0xFFC69A5B);
  static const Color _primaryDark = Color(0xFF8A6848);
  static const Color _gold = Color(0xFFE0B56E);
  static const Color _green = Color(0xFF43795C);
  static const Color _orange = Color(0xFFD97A33);
  static const Color _red = Color(0xFFBC5F39);
  static const Color _blue = Color(0xFF5E7FA3);
  static const Color _purple = Color(0xFF7A67A8);

  static const Color _textDark = Color(0xFF4B3427);
  static const Color _textSoft = Color(0xFF857261);
  static const Color _border = Color(0xFFEEE3D5);
  static const Color _divider = Color(0xFFE7DACA);

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _nameController = TextEditingController(text: product.name);
    _descriptionController =
        TextEditingController(text: product.description ?? '');
    _priceController = TextEditingController(
      text: product.price.toStringAsFixed(product.price % 1 == 0 ? 0 : 2),
    );
    _stockController = TextEditingController(text: product.stock.toString());

    _selectedUnit = product.unit != null && _units.contains(product.unit)
        ? product.unit!
        : _units.first;

    _selectedStatus = product.state == 1 ? 'Activo' : 'Pausado';
    _harvestDate = product.harvestDate;
    _imageBase64OrUrl = _normalizeOptionalText(product.picture);
    _selectedFamilyId = product.familyID;

    _nameController.addListener(_refreshPreview);
    _descriptionController.addListener(_refreshPreview);
    _priceController.addListener(_refreshPreview);
    _stockController.addListener(_refreshPreview);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadInitialData();
    });
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

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    setState(() => _isRefreshing = true);

    try {
      await _loadFamilies();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _loadFamilies() async {
    try {
      if (mounted) {
        setState(() => _isLoadingFamilies = true);
      }

      final families = await _productFamilyService.getAll();

      if (!mounted) return;

      setState(() {
        _families = families;

        if (_families.isNotEmpty) {
          final exists = _families.any((f) => f.id == _selectedFamilyId);
          _selectedFamilyId = exists ? _selectedFamilyId : _families.first.id;
        } else {
          _selectedFamilyId = null;
        }

        _isLoadingFamilies = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoadingFamilies = false);
      _showMessage('Error cargando familias: $e');
    }
  }

  Future<void> _selectDate() async {
    FocusScope.of(context).unfocus();

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
              primary: _primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _textDark,
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

  Future<void> _showImageSourceSheet() async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F2EA),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6C6B3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: _primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Foto del producto',
                            style: TextStyle(
                              color: _textDark,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Actualiza la imagen desde cámara o galería.',
                            style: TextStyle(
                              color: _textSoft,
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildImageSourceOption(
                  icon: Icons.photo_camera_outlined,
                  color: _green,
                  title: 'Tomar foto',
                  subtitle: 'Usar la cámara del dispositivo',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 10),
                _buildImageSourceOption(
                  icon: Icons.photo_library_outlined,
                  color: _primary,
                  title: 'Elegir desde galería',
                  subtitle: 'Seleccionar una imagen guardada',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickImage(ImageSource.gallery);
                  },
                ),
                if (_hasImage()) ...[
                  const SizedBox(height: 10),
                  _buildImageSourceOption(
                    icon: Icons.delete_outline_rounded,
                    color: _red,
                    title: 'Quitar imagen',
                    subtitle: 'Eliminar la imagen actual del producto',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _clearSelectedImage();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _textSoft,
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: _textSoft,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (mounted) setState(() => _isPickingImage = true);

      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1300,
        maxHeight: 1300,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (picked == null) {
        if (mounted) setState(() => _isPickingImage = false);
        return;
      }

      final file = File(picked.path);
      final base64 = await ImageHelper.toBase64(file);

      if (!mounted) return;

      if (base64 == null || base64.trim().isEmpty) {
        setState(() => _isPickingImage = false);
        _showMessage('No se pudo procesar la imagen seleccionada');
        return;
      }

      await precacheImage(FileImage(file), context);

      if (!mounted) return;

      setState(() {
        _selectedImageFile = file;
        _imageBase64OrUrl = base64;
        _isPickingImage = false;
      });

      _showMessage('Imagen actualizada correctamente', isError: false);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isPickingImage = false);
      _showMessage('Error seleccionando imagen: $e');
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImageFile = null;
      _imageBase64OrUrl = null;
    });

    _showMessage('Imagen quitada', isError: false);
  }

  Future<void> _saveProduct() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) return;

    final formIsValid = _formKey.currentState?.validate() ?? false;
    if (!formIsValid) return;

    if (_families.isEmpty) {
      _showMessage('No hay familias disponibles para seleccionar');
      return;
    }

    if (_selectedFamilyId == null) {
      _showMessage('Selecciona la familia del producto');
      return;
    }

    if (_harvestDate == null) {
      _showMessage('Selecciona la fecha de cosecha');
      return;
    }

    if (_imageBase64OrUrl == null || _imageBase64OrUrl!.trim().isEmpty) {
      _showMessage('Debes seleccionar o mantener una foto del producto');
      return;
    }

    final price = _parsePrice(_priceController.text);
    final stock = int.tryParse(_stockController.text.trim());

    if (price == null || stock == null) {
      _showMessage('Verifica el precio y el stock');
      return;
    }

    final productController = context.read<ProductController>();

    setState(() => _isSubmitting = true);

    try {
      final updatedProduct = ProductModel(
        id: widget.product.id,
        name: _nameController.text.trim(),
        description: _normalizeOptionalText(_descriptionController.text),
        picture: _imageBase64OrUrl,
        price: price,
        unit: _selectedUnit,
        stock: stock,
        state: _selectedStatus == 'Activo' ? 1 : 0,
        harvestDate: _harvestDate,
        userID: widget.product.userID,
        familyID: _selectedFamilyId,
      );

      final success = await productController.updateProduct(updatedProduct);

      if (!mounted) return;

      if (success) {
        _showMessage('Producto actualizado correctamente', isError: false);
        Navigator.pop(context, true);
      } else {
        _showMessage(
          productController.errorMessage ?? 'Error al actualizar producto',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _normalizeOptionalText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _parsePrice(String? value) {
    if (value == null) return null;
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obligatorio';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Campo obligatorio';
    if (text.length < 10) {
      return 'Agrega una descripción un poco más clara';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obligatorio';
    }

    final parsed = _parsePrice(value);
    if (parsed == null) return 'Ingresa un precio válido';
    if (parsed <= 0) return 'El precio debe ser mayor a 0';
    return null;
  }

  String? _validateStock(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obligatorio';
    }

    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Ingresa un stock válido';
    if (parsed < 0) return 'El stock no puede ser negativo';
    return null;
  }

  double _getMaxContentWidth(double screenWidth) {
    if (screenWidth >= 1500) return 1320;
    if (screenWidth >= 1200) return 1080;
    if (screenWidth >= 1000) return 920;
    return screenWidth;
  }

  EdgeInsets _getResponsivePadding(double screenWidth) {
    if (screenWidth >= 1200) return const EdgeInsets.fromLTRB(28, 16, 28, 120);
    if (screenWidth >= 800) return const EdgeInsets.fromLTRB(20, 14, 20, 120);
    return const EdgeInsets.fromLTRB(16, 12, 16, 120);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatMoney(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Color _getStatusColor() {
    return _selectedStatus == 'Activo' ? _green : const Color(0xFF8F8F8F);
  }

  bool _hasImage() {
    return _selectedImageFile != null ||
        (_imageBase64OrUrl != null && _imageBase64OrUrl!.trim().isNotEmpty);
  }

  bool _isNetworkImage(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  Uint8List? _tryDecodeBase64(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final raw = value.trim();
    if (_isNetworkImage(raw)) return null;

    try {
      final normalized = raw.startsWith('data:image') ? raw.split(',').last : raw;
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  String _getSelectedFamilyName() {
    if (_selectedFamilyId == null) return 'Familia pendiente';

    final family = _families.cast<ProductFamilyModel?>().firstWhere(
          (item) => item?.id == _selectedFamilyId,
      orElse: () => null,
    );

    return family?.name ?? 'Familia pendiente';
  }

  int _completionPercentage() {
    int completed = 0;
    const int total = 7;

    if (_nameController.text.trim().isNotEmpty) completed++;
    if (_descriptionController.text.trim().isNotEmpty) completed++;
    if (_priceController.text.trim().isNotEmpty) completed++;
    if (_stockController.text.trim().isNotEmpty) completed++;
    if (_selectedFamilyId != null) completed++;
    if (_harvestDate != null) completed++;
    if (_hasImage()) completed++;

    return ((completed / total) * 100).round();
  }

  List<String> _missingRequirements() {
    final missing = <String>[];

    if (_nameController.text.trim().isEmpty) missing.add('nombre');
    if (_descriptionController.text.trim().isEmpty) missing.add('descripción');
    if (_priceController.text.trim().isEmpty) missing.add('precio');
    if (_stockController.text.trim().isEmpty) missing.add('stock');
    if (_selectedFamilyId == null) missing.add('familia');
    if (_harvestDate == null) missing.add('cosecha');
    if (!_hasImage()) missing.add('foto');

    return missing;
  }

  bool _canSaveVisually() {
    return _missingRequirements().isEmpty;
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? _red : _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final productController = context.watch<ProductController>();

    final screenWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = _getMaxContentWidth(screenWidth);
    final isWide = screenWidth >= 900;

    final isBusy = _isSubmitting ||
        _isPickingImage ||
        _isLoadingFamilies ||
        _isRefreshing ||
        productController.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF6EFE6),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -50,
              child: _buildDecorBubble(180, _primary.withOpacity(0.10)),
            ),
            Positioned(
              top: 130,
              right: -55,
              child: _buildDecorBubble(170, _gold.withOpacity(0.13)),
            ),
            Positioned(
              bottom: 140,
              left: -65,
              child: _buildDecorBubble(180, _green.withOpacity(0.07)),
            ),
            SafeArea(
              child: RefreshIndicator(
                color: _primary,
                onRefresh: _loadInitialData,
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.zero,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: Padding(
                          padding: _getResponsivePadding(screenWidth),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTopBar(isBusy),
                                const SizedBox(height: 18),
                                _buildHeroBanner(isBusy: isBusy),
                                const SizedBox(height: 20),
                                _buildProgressSection(),
                                const SizedBox(height: 20),
                                if (isWide)
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: Column(
                                          children: [
                                            _buildMainInfoSection(),
                                            const SizedBox(height: 20),
                                            _buildImageSection(),
                                            const SizedBox(height: 20),
                                            _buildDescriptionSection(),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        flex: 5,
                                        child: Column(
                                          children: [
                                            _buildSaleConfigSection(),
                                            const SizedBox(height: 20),
                                            _buildHarvestAndStatusSection(),
                                            const SizedBox(height: 20),
                                            _buildPreviewSection(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  _buildMainInfoSection(),
                                  const SizedBox(height: 20),
                                  _buildSaleConfigSection(),
                                  const SizedBox(height: 20),
                                  _buildImageSection(),
                                  const SizedBox(height: 20),
                                  _buildHarvestAndStatusSection(),
                                  const SizedBox(height: 20),
                                  _buildDescriptionSection(),
                                  const SizedBox(height: 20),
                                  _buildPreviewSection(),
                                ],
                                const SizedBox(height: 24),
                                _buildSaveButton(isBusy),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isRefreshing)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  color: _primary,
                  backgroundColor: Colors.transparent,
                  minHeight: 3,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isBusy) {
    return Row(
      children: [
        _buildAppBarButton(
          icon: Icons.arrow_back_ios_new_rounded,
          color: _textDark,
          onTap: isBusy ? null : () => Navigator.pop(context),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editar producto',
                style: TextStyle(
                  color: _textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Actualiza tu publicación de forma clara y profesional',
                style: TextStyle(
                  color: _textSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildAppBarButton(
          icon: _isRefreshing ? Icons.sync_rounded : Icons.refresh_rounded,
          color: _primary,
          onTap: isBusy ? null : _loadInitialData,
        ),
      ],
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _surface.withOpacity(0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: onTap == null ? _textSoft.withOpacity(0.45) : color,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildHeroBanner({required bool isBusy}) {
    final name = _nameController.text.trim().isEmpty
        ? 'Producto sin nombre'
        : _nameController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5A4A41), Color(0xFF443832), Color(0xFF302826)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: 18,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _HeroTag(
                    icon: Icons.edit_outlined,
                    label: 'Edición',
                  ),
                  _HeroTag(
                    icon: Icons.storefront_outlined,
                    label: 'Catálogo',
                  ),
                  _HeroTag(
                    icon: Icons.photo_camera_back_outlined,
                    label: 'Foto editable',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: isBusy ? null : _showImageSourceSheet,
                    child: _buildHeroImagePreview(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _descriptionController.text.trim().isEmpty
                              ? 'Actualiza la información para mantener tu catálogo claro, atractivo y confiable.'
                              : _descriptionController.text.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.76),
                            fontSize: 12.8,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildHeroMiniTag(
                              label: '${_completionPercentage()}% completo',
                              color: const Color(0xFFFFE1B0),
                            ),
                            _buildHeroMiniTag(
                              label: _selectedStatus,
                              color: _selectedStatus == 'Activo'
                                  ? const Color(0xFFCDE8D9)
                                  : Colors.white70,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Familia',
                      value: _getSelectedFamilyName(),
                      icon: Icons.category_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Precio',
                      value: _priceController.text.trim().isEmpty
                          ? 'Pendiente'
                          : '${_priceController.text.trim()} mon.',
                      icon: Icons.payments_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Stock',
                      value: _stockController.text.trim().isEmpty
                          ? 'Pendiente'
                          : _stockController.text.trim(),
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Cosecha',
                      value: _harvestDate == null
                          ? 'Pendiente'
                          : _formatDate(_harvestDate),
                      icon: Icons.calendar_month_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImagePreview() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withOpacity(0.10),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: _buildProductImage(
            width: 88,
            height: 88,
            borderRadius: BorderRadius.circular(24),
            placeholderIcon: Icons.add_photo_alternate_outlined,
            placeholderIconColor: Colors.white,
            placeholderBackground: Colors.white.withOpacity(0.08),
            placeholderIconSize: 34,
          ),
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              color: Colors.white,
              size: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroStatBox({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMiniTag({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final missing = _missingRequirements();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: _primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado de la edición',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      missing.isEmpty
                          ? 'Todo listo para guardar los cambios.'
                          : 'Falta completar: ${missing.join(', ')}.',
                      style: const TextStyle(
                        color: _textSoft,
                        fontSize: 12.4,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTinyStatusChip(
                '${_completionPercentage()}%',
                _canSaveVisually() ? _green : _orange,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: (_completionPercentage() / 100).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFE8DCCB),
              valueColor: AlwaysStoppedAnimation<Color>(
                _canSaveVisually() ? _green : _primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainInfoSection() {
    return _buildSectionCard(
      title: 'Información principal',
      subtitle: 'Actualiza el nombre, familia y unidad de venta.',
      icon: Icons.edit_note_rounded,
      accent: _primaryDark,
      child: Column(
        children: [
          _buildInputCard(
            title: 'Nombre del producto',
            hint: 'Ej. Tomate cherry orgánico',
            controller: _nameController,
            icon: Icons.shopping_basket_outlined,
            validator: _validateRequired,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          _buildFamilyDropdownCard(),
          const SizedBox(height: 14),
          _buildDropdownCard(
            title: 'Unidad de medida',
            icon: Icons.straighten_rounded,
            value: _selectedUnit,
            items: _units,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedUnit = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaleConfigSection() {
    return _buildSectionCard(
      title: 'Precio y stock',
      subtitle: 'Mantén actualizado el precio y la disponibilidad real.',
      icon: Icons.sell_outlined,
      accent: _gold,
      child: Column(
        children: [
          _buildInputCard(
            title: 'Precio',
            hint: 'Ej. 4.5',
            controller: _priceController,
            icon: Icons.payments_outlined,
            type: const TextInputType.numberWithOptions(decimal: true),
            suffixText: 'monedas',
            validator: _validatePrice,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
          ),
          const SizedBox(height: 14),
          _buildInputCard(
            title: 'Stock disponible',
            hint: 'Ej. 25',
            controller: _stockController,
            icon: Icons.inventory_2_outlined,
            type: TextInputType.number,
            validator: _validateStock,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return _buildSectionCard(
      title: 'Descripción',
      subtitle: 'Mejora el texto para que el comprador entienda mejor el producto.',
      icon: Icons.notes_rounded,
      accent: _green,
      child: _buildInputCard(
        title: 'Descripción del producto',
        hint:
        'Ej. Producto fresco de cosecha reciente, ideal para restaurantes...',
        controller: _descriptionController,
        icon: Icons.edit_note_outlined,
        maxLines: 5,
        validator: _validateDescription,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  Widget _buildImageSection() {
    return _buildSectionCard(
      title: 'Foto del producto',
      subtitle: 'Cambia la imagen para mantener tu publicación atractiva.',
      icon: Icons.photo_camera_back_outlined,
      accent: _primary,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surfaceMuted,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _divider),
            ),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _hasImage()
                      ? _buildProductImage(
                    key: ValueKey(
                      _selectedImageFile?.path ??
                          _imageBase64OrUrl ??
                          'stored_image',
                    ),
                    width: double.infinity,
                    height: 230,
                    borderRadius: BorderRadius.circular(22),
                    placeholderIcon: Icons.broken_image_outlined,
                    placeholderIconColor: _primaryDark,
                    placeholderBackground: const Color(0xFFF1E8DA),
                    placeholderIconSize: 42,
                  )
                      : _buildImagePlaceholder(
                    key: const ValueKey('image_placeholder'),
                    height: 210,
                    icon: Icons.add_photo_alternate_outlined,
                    title: 'Aún no seleccionaste una imagen',
                    subtitle:
                    'Puedes tomar una foto o elegir desde galería',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                        _isPickingImage ? null : _showImageSourceSheet,
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
                        label: Text(_hasImage() ? 'Cambiar foto' : 'Elegir foto'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFD0B48C),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    if (_hasImage()) ...[
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _isPickingImage ? null : _clearSelectedImage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _red,
                          side: BorderSide(color: _red.withOpacity(0.35)),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Quitar',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder({
    Key? key,
    required double height,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF1E8DA),
            Color(0xFFE4D4BC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 46, color: _primaryDark),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textDark,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHarvestAndStatusSection() {
    return _buildSectionCard(
      title: 'Cosecha y estado',
      subtitle: 'Actualiza la fecha de cosecha y si estará visible o pausado.',
      icon: Icons.event_available_outlined,
      accent: _green,
      child: Column(
        children: [
          _buildDateCard(),
          const SizedBox(height: 14),
          _buildStatusSelector(),
        ],
      ),
    );
  }

  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: _green,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fecha de cosecha',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _harvestDate == null
                      ? 'Selecciona la fecha'
                      : _formatDate(_harvestDate),
                  style: TextStyle(
                    color: _harvestDate == null ? _textSoft : _textDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _selectDate,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Elegir'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() {
    final statusColor = _getStatusColor();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _selectedStatus == 'Activo'
                      ? Icons.check_circle_outline_rounded
                      : Icons.pause_circle_outline_rounded,
                  color: statusColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Estado de publicación',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildTinyStatusChip(_selectedStatus, statusColor),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSelectableStatus(
                  label: 'Activo',
                  value: 'Activo',
                  color: _green,
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
          _buildInfoStrip(
            icon: _selectedStatus == 'Activo'
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: statusColor,
            text: _selectedStatus == 'Activo'
                ? 'El producto seguirá visible en tu catálogo.'
                : 'El producto quedará oculto temporalmente.',
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
        setState(() => _selectedStatus = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : _border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? color : _textSoft,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : _textDark,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return _buildSectionCard(
      title: 'Vista previa',
      subtitle: 'Así quedará resumido el producto después de guardar.',
      icon: Icons.visibility_outlined,
      accent: _blue,
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceSoft,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _divider),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: _surfaceMuted,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _hasImage()
                  ? _buildProductImage(
                width: 104,
                height: 104,
                borderRadius: BorderRadius.circular(20),
                placeholderIcon: Icons.image_not_supported_outlined,
                placeholderIconColor: _textSoft,
                placeholderBackground: _surfaceMuted,
                placeholderIconSize: 38,
              )
                  : const Icon(
                Icons.inventory_2_outlined,
                color: _primary,
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
                          fontWeight: FontWeight.w900,
                          color: _textDark,
                        ),
                      ),
                      _buildTinyStatusChip(_selectedStatus, _getStatusColor()),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _descriptionController.text.trim().isEmpty
                        ? 'Aquí aparecerá la descripción del producto.'
                        : _descriptionController.text.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _textSoft,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPreviewInfo(
                    Icons.category_outlined,
                    _getSelectedFamilyName(),
                    _primaryDark,
                  ),
                  const SizedBox(height: 6),
                  _buildPreviewInfo(
                    Icons.payments_outlined,
                    _priceController.text.trim().isEmpty
                        ? 'Precio pendiente'
                        : '${_priceController.text.trim()} monedas / $_selectedUnit',
                    _gold,
                  ),
                  const SizedBox(height: 6),
                  _buildPreviewInfo(
                    Icons.inventory_2_outlined,
                    _stockController.text.trim().isEmpty
                        ? 'Stock pendiente'
                        : 'Stock: ${_stockController.text.trim()} $_selectedUnit',
                    _green,
                  ),
                  const SizedBox(height: 6),
                  _buildPreviewInfo(
                    Icons.calendar_month_outlined,
                    _harvestDate == null
                        ? 'Fecha de cosecha pendiente'
                        : 'Cosecha: ${_formatDate(_harvestDate)}',
                    _blue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage({
    Key? key,
    required double width,
    required double height,
    required BorderRadius borderRadius,
    BoxFit fit = BoxFit.cover,
    IconData placeholderIcon = Icons.image_outlined,
    double placeholderIconSize = 42,
    Color placeholderIconColor = _primary,
    Color placeholderBackground = _surfaceMuted,
  }) {
    Widget child;

    if (_selectedImageFile != null) {
      child = Image.file(
        _selectedImageFile!,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) {
          return _buildImageFallback(
            width: width,
            height: height,
            background: placeholderBackground,
            icon: Icons.broken_image_outlined,
            iconColor: _primaryDark,
            iconSize: placeholderIconSize,
          );
        },
      );
    } else if (_imageBase64OrUrl != null &&
        _imageBase64OrUrl!.trim().isNotEmpty) {
      final rawImage = _imageBase64OrUrl!.trim();

      if (_isNetworkImage(rawImage)) {
        child = Image.network(
          rawImage,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) {
            return _buildImageFallback(
              width: width,
              height: height,
              background: placeholderBackground,
              icon: Icons.broken_image_outlined,
              iconColor: _primaryDark,
              iconSize: placeholderIconSize,
            );
          },
        );
      } else {
        final bytes = _tryDecodeBase64(rawImage);

        if (bytes != null) {
          child = Image.memory(
            bytes,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) {
              return _buildImageFallback(
                width: width,
                height: height,
                background: placeholderBackground,
                icon: Icons.broken_image_outlined,
                iconColor: _primaryDark,
                iconSize: placeholderIconSize,
              );
            },
          );
        } else {
          child = _buildImageFallback(
            width: width,
            height: height,
            background: placeholderBackground,
            icon: placeholderIcon,
            iconColor: placeholderIconColor,
            iconSize: placeholderIconSize,
          );
        }
      }
    } else {
      child = _buildImageFallback(
        width: width,
        height: height,
        background: placeholderBackground,
        icon: placeholderIcon,
        iconColor: placeholderIconColor,
        iconSize: placeholderIconSize,
      );
    }

    return ClipRRect(
      key: key,
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: child,
      ),
    );
  }

  Widget _buildImageFallback({
    required double width,
    required double height,
    required Color background,
    required IconData icon,
    required Color iconColor,
    required double iconSize,
  }) {
    return Container(
      width: width,
      height: height,
      color: background,
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: iconSize,
        color: iconColor,
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
              color: _textSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isBusy) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.72)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: isBusy ? null : _saveProduct,
          icon: isBusy
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Colors.white,
            ),
          )
              : const Icon(Icons.save_outlined),
          label: Text(isBusy ? 'Guardando cambios...' : 'Guardar cambios'),
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFD0B48C),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: _textSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
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
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: _surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(title: title, icon: icon),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            keyboardType: type,
            maxLines: maxLines,
            validator: validator ?? _validateRequired,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            style: const TextStyle(
              color: _textDark,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hint,
              suffixText: suffixText,
              suffixStyle: const TextStyle(
                color: _primaryDark,
                fontWeight: FontWeight.w800,
              ),
              hintStyle: const TextStyle(
                color: Color(0xFFAA9B8A),
                fontSize: 13,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: maxLines > 1 ? 16 : 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: _primary,
                  width: 1.2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: _red,
                  width: 1.2,
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: _surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(title: title, icon: icon),
          const SizedBox(height: 12),
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
              color: _primaryDark,
            ),
            dropdownColor: Colors.white,
            decoration: _dropdownDecoration(),
            style: const TextStyle(
              color: _textDark,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyDropdownCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: _surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(
            title: 'Familia del producto',
            icon: Icons.category_outlined,
          ),
          const SizedBox(height: 12),
          if (_isLoadingFamilies)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: _primary),
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
                setState(() => _selectedFamilyId = value);
              },
              validator: (value) => value == null ? 'Campo obligatorio' : null,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _primaryDark,
              ),
              dropdownColor: Colors.white,
              decoration: _dropdownDecoration(
                hintText: _families.isEmpty
                    ? 'No hay familias disponibles'
                    : 'Selecciona una familia',
              ),
              style: const TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFAA9B8A),
        fontSize: 13,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: _primary,
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: _red,
          width: 1.2,
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
        Icon(icon, size: 18, color: _primaryDark),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: _textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTinyStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildInfoStrip({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12.2,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorBubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: _ProducerEditProductViewState._gold,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _ProducerEditProductViewState._gold,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}