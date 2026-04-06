import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/product_controller.dart';
import '../../models/product_model.dart';

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
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _imageController;

  DateTime? _harvestDate;
  String _selectedUnit = 'kg';
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

    final product = widget.product;

    _nameController = TextEditingController(text: product.name);
    _descriptionController =
        TextEditingController(text: product.description ?? '');
    _priceController = TextEditingController(
      text: product.price.toStringAsFixed(product.price % 1 == 0 ? 0 : 2),
    );
    _stockController = TextEditingController(text: product.stock.toString());
    _imageController = TextEditingController(text: product.picture ?? '');

    _selectedUnit = (product.unit != null && _units.contains(product.unit))
        ? product.unit!
        : _units.first;

    _selectedStatus = product.state == 1 ? 'Activo' : 'Pausado';
    _harvestDate = product.harvestDate;

    _nameController.addListener(_refresh);
    _descriptionController.addListener(_refresh);
    _priceController.addListener(_refresh);
    _stockController.addListener(_refresh);
    _imageController.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_refresh);
    _descriptionController.removeListener(_refresh);
    _priceController.removeListener(_refresh);
    _stockController.removeListener(_refresh);
    _imageController.removeListener(_refresh);

    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _harvestDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
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

  Future<void> _saveProduct() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_harvestDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF4E3426),
          content: Text('Selecciona la fecha de cosecha'),
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

    final productController =
    Provider.of<ProductController>(context, listen: false);

    final updatedProduct = ProductModel(
      id: widget.product.id,
      name: _nameController.text.trim(),
      description: _normalizeOptionalText(_descriptionController.text),
      picture: _normalizeOptionalText(_imageController.text),
      price: price,
      unit: _selectedUnit,
      stock: stock,
      state: _selectedStatus == 'Activo' ? 1 : 0,
      harvestDate: _harvestDate,
      userID: widget.product.userID,
    );

    final success = await productController.updateProduct(updatedProduct);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF4E3426),
          content: Text('Producto actualizado correctamente'),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF4E3426),
          content: Text(
            productController.errorMessage ?? 'Error al actualizar producto',
          ),
        ),
      );
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

  String? _validateImageUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obligatorio';
    }

    final uri = Uri.tryParse(value.trim());
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return 'Ingresa una URL válida';
    }

    return null;
  }

  double _getMaxContentWidth(double screenWidth) {
    if (screenWidth >= 1400) return 1020;
    if (screenWidth >= 1100) return 920;
    if (screenWidth >= 800) return 780;
    return screenWidth;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha seleccionada';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _statusColor() {
    return _selectedStatus == 'Activo'
        ? const Color(0xFF2E8B57)
        : const Color(0xFF8F8F8F);
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
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
                'Editar producto',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E3426),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Actualiza la información de tu publicación',
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
                Icons.edit_outlined,
                color: Color(0xFFC7942E),
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                'Edición',
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
    final hasImage = _imageController.text.trim().isNotEmpty;

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
            child: Row(
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.24),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),
                  child: hasImage
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.network(
                      _imageController.text.trim(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white,
                          size: 40,
                        );
                      },
                    ),
                  )
                      : const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildBannerChip(
                            Icons.auto_awesome_outlined,
                            'Edición premium',
                          ),
                          _buildBannerChip(
                            Icons.inventory_2_outlined,
                            'Catálogo productor',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _nameController.text.trim().isEmpty
                            ? 'Producto sin nombre'
                            : _nameController.text.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _descriptionController.text.trim().isEmpty
                            ? 'Actualiza la información del producto para mantener tu catálogo al día.'
                            : _descriptionController.text.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeroMiniStat(
                              icon: Icons.payments_outlined,
                              label: _priceController.text.trim().isEmpty
                                  ? '--'
                                  : '${_priceController.text.trim()} mon.',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildHeroMiniStat(
                              icon: Icons.inventory_2_outlined,
                              label: _stockController.text.trim().isEmpty
                                  ? 'Stock --'
                                  : 'Stock ${_stockController.text.trim()}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildQuickCards() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickCard(
            icon: Icons.image_outlined,
            title: 'Vista previa',
            subtitle: 'Revisa cómo se verá',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickCard(
            icon: Icons.edit_note_rounded,
            title: 'Datos del producto',
            subtitle: 'Actualiza y guarda cambios',
          ),
        ),
      ],
    );
  }

  Widget _buildQuickCard({
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
    final color = _statusColor();

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
            title: 'Estado del producto',
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
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedStatus == 'Activo'
                      ? Icons.check_circle_outline_rounded
                      : Icons.pause_circle_outline_rounded,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedStatus == 'Activo'
                        ? 'El producto seguirá visible en tu catálogo.'
                        : 'El producto quedará oculto temporalmente.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: color,
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
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? color : const Color(0xFF5A3E2B),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final hasImage = _imageController.text.trim().isNotEmpty;

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
                      child: Image.network(
                        _imageController.text.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
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
                                color: _statusColor().withOpacity(0.11),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _statusColor().withOpacity(0.18),
                                ),
                              ),
                              child: Text(
                                _selectedStatus,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _statusColor(),
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
                              : '${_priceController.text.trim()} monedas / $_selectedUnit',
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
                          'Unidad: $_selectedUnit',
                          const Color(0xFF2E8B57),
                        ),
                        const SizedBox(height: 6),
                        _buildPreviewInfo(
                          Icons.calendar_month_outlined,
                          _harvestDate == null
                              ? 'Fecha pendiente'
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

  Widget _buildSaveButton() {
    return Consumer<ProductController>(
      builder: (context, productController, child) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: productController.isLoading ? null : _saveProduct,
            icon: productController.isLoading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.save_outlined),
            label: Text(
              productController.isLoading ? 'Guardando...' : 'Guardar cambios',
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
                        _buildQuickCards(),
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
                                'Actualiza los datos principales, el inventario y la presentación visual del producto.',
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
                                        value: _selectedUnit,
                                        items: _units,
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(() {
                                            _selectedUnit = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
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
                                  value: _selectedUnit,
                                  items: _units,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _selectedUnit = value;
                                    });
                                  },
                                ),
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
                              _buildInputCard(
                                title: 'URL de la imagen',
                                hint: 'https://...',
                                controller: _imageController,
                                icon: Icons.image_outlined,
                                customValidator: _validateImageUrl,
                              ),
                              _buildDateCard(),
                              _buildPreviewCard(),
                              const SizedBox(height: 22),
                              _buildSaveButton(),
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