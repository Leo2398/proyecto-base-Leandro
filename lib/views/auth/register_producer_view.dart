import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../controllers/user_controller.dart';
import '../../core/location_helper.dart';
import '../../models/delivery_mode_model.dart';
import '../../models/product_family_model.dart';
import '../../models/user_model.dart';
import '../../services/delivery_mode_service.dart';
import '../../services/product_family_service.dart';
import 'package:geolocator/geolocator.dart';

/// Pantalla de registro de productor
/// Principio S de SOLID: solo maneja la UI del registro de productor
class RegisterProducerView extends StatefulWidget {
  const RegisterProducerView({super.key});

  @override
  State<RegisterProducerView> createState() => _RegisterProducerViewState();
}

class _RegisterProducerViewState extends State<RegisterProducerView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final MapController _mapController = MapController();

  LatLng? _selectedLocation;
  bool _isLoadingLocation = false;
  bool _isLoadingData = true;

  List<ProductFamilyModel> _productFamilies = [];
  List<int> _selectedFamilyIDs = [];
  List<DeliveryModeModel> _deliveryModes = [];
  int? _selectedDeliveryModeID;

  final ProductFamilyService _productFamilyService = ProductFamilyService();
  final DeliveryModeService _deliveryModeService = DeliveryModeService();

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _loadData();
  }

  Future<void> _requestLocationPermission() async {
    await Geolocator.requestPermission();
  }

 Future<void> _loadData() async {
  try {
    setState(() => _isLoadingData = true);

    print('Iniciando carga de datos...');
    final families = await _productFamilyService.getAll();
    print('Familias: ${families.length}');
    final modes = await _deliveryModeService.getAll();
    print('Modos: ${modes.length}');

    if (mounted) {
      setState(() {
        _productFamilies = families;
        _deliveryModes = modes;
        _isLoadingData = false;
      });
    }
  } catch (e) {
    print('Error en _loadData: $e');
    if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }
}

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    final location = await LocationHelper.getCurrentLocation();

    if (location != null) {
      setState(() => _selectedLocation = location);
      _mapController.move(location, 15);

      final address = await LocationHelper.getAddressFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (address != null) {
        _addressController.text = address;
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener la ubicación')),
        );
      }
    }

    setState(() => _isLoadingLocation = false);
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng location) async {
    setState(() => _selectedLocation = location);

    final address = await LocationHelper.getAddressFromCoordinates(
      location.latitude,
      location.longitude,
    );

    if (address != null) {
      _addressController.text = address;
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDeliveryModeID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una modalidad de entrega')),
      );
      return;
    }

    if (_selectedFamilyIDs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecciona al menos una familia de productos')),
      );
      return;
    }

    final controller = Provider.of<UserController>(context, listen: false);

    final user = UserModel(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: '',
      role: 1,
      cellphone: _phoneController.text.trim(),
      description: _descriptionController.text.trim(),
    );

    final success = await controller.registerProducer(
      user: user,
      latitude: _selectedLocation?.latitude,
      longitude: _selectedLocation?.longitude,
      address: _addressController.text.trim(),
      deliveryModeID: _selectedDeliveryModeID!,
      familyIDs: _selectedFamilyIDs,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro exitoso, revisa tu email para tu contraseña'),
          backgroundColor: Color(0xFF5A8A5A),
        ),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage ?? 'Error al registrar'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFB8860B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.energy_savings_leaf_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Registro de Productor',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Registra tu empresa y comienza a vender\na restaurantes',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Nombre de la empresa'),
                      _buildTextField(
                        controller: _nameController,
                        hint: 'Ej: Finca Los Robles',
                        icon: Icons.storefront_outlined,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa el nombre de tu empresa';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      _buildLabel('Descripción de la empresa'),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Describe tu empresa agrícola...',
                          hintStyle:
                              const TextStyle(color: Color(0xFFAAAAAA)),
                          filled: true,
                          fillColor: const Color(0xFFF5F0E8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa una descripción';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      _buildLabel('Número de teléfono'),
                      _buildTextField(
                        controller: _phoneController,
                        hint: '+57 300 123 4567',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu teléfono';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      _buildLabel('Correo electrónico'),
                      _buildTextField(
                        controller: _emailController,
                        hint: 'empresa@ejemplo.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu correo';
                          }
                          if (!value.contains('@')) {
                            return 'Ingresa un correo válido';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      _buildLabel('Ubicación de recogida'),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Dirección completa',
                          hintStyle:
                              const TextStyle(color: Color(0xFFAAAAAA)),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 24),
                            child: Icon(Icons.location_on_outlined,
                                color: Color(0xFF888888)),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F0E8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu dirección';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: const [
                          Text(
                            'Ubicación en mapa',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '(Opcional)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          height: 200,
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: const LatLng(19.4326, -99.1332),
                              initialZoom: 12,
                              onTap: _onMapTap,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.example.app_pedidos',
                              ),
                              if (_selectedLocation != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _selectedLocation!,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: Color(0xFFB8860B),
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      GestureDetector(
                        onTap: _isLoadingLocation ? null : _getCurrentLocation,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _isLoadingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFB8860B),
                                    ),
                                  )
                                : const Icon(
                                    Icons.my_location,
                                    color: Color(0xFFB8860B),
                                    size: 18,
                                  ),
                            const SizedBox(width: 6),
                            const Text(
                              'Seleccionar ubicación en mapa',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFB8860B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      /// Familias de productos
                      _buildLabel('Familias de productos que comercializa'),
                      _isLoadingData
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF5A8A5A),
                              ),
                            )
                          : _productFamilies.isEmpty
                              ? const Text(
                                  'No se pudieron cargar las familias',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF888888),
                                  ),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _productFamilies.map((family) {
                                    final isSelected =
                                        _selectedFamilyIDs.contains(family.id);
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedFamilyIDs
                                                .remove(family.id);
                                          } else {
                                            _selectedFamilyIDs.add(family.id!);
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF5A8A5A)
                                              : const Color(0xFFF5F0E8),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          family.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF2D2D2D),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),

                      const SizedBox(height: 24),

                      /// Modalidad de entrega
                      _buildLabel('Modalidad de entrega'),
                      _isLoadingData
                          ? const SizedBox()
                          : _deliveryModes.isEmpty
                              ? const Text(
                                  'No se pudieron cargar las modalidades',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF888888),
                                  ),
                                )
                              : Column(
                                  children: _deliveryModes.map((mode) {
                                    return RadioListTile<int>(
                                      title: Text(
                                        mode.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF2D2D2D),
                                        ),
                                      ),
                                      value: mode.id!,
                                      groupValue: _selectedDeliveryModeID,
                                      activeColor: const Color(0xFF5A8A5A),
                                      contentPadding: EdgeInsets.zero,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedDeliveryModeID = value;
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),

                      const SizedBox(height: 24),

                      /// Botón continuar
                      Consumer<UserController>(
                        builder: (context, controller, child) {
                          return SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: controller.isLoading
                                  ? null
                                  : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5A8A5A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: controller.isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text(
                                      'Continuar',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '¿Ya tienes cuenta? ',
                    style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.popUntil(
                      context,
                      (route) => route.isFirst,
                    ),
                    child: const Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5A8A5A),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2D2D2D),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        prefixIcon: Icon(icon, color: const Color(0xFF888888)),
        filled: true,
        fillColor: const Color(0xFFF5F0E8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }
}