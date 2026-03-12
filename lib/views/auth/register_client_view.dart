import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../controllers/user_controller.dart';
import '../../core/location_helper.dart';
import '../../models/user_model.dart';

/// Pantalla de registro de cliente
/// Principio S de SOLID: solo maneja la UI del registro de cliente
class RegisterClientView extends StatefulWidget {
  const RegisterClientView({super.key});

  @override
  State<RegisterClientView> createState() => _RegisterClientViewState();
}

class _RegisterClientViewState extends State<RegisterClientView> {
  /// Controladores para los campos de texto
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  /// Clave del formulario para validaciones
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Controlador del mapa
  final MapController _mapController = MapController();

  /// Ubicación seleccionada en el mapa
  LatLng? _selectedLocation;

  /// Indica si está cargando la ubicación
  bool _isLoadingLocation = false;

  /// Libera los recursos al destruir el widget
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Obtiene la ubicación actual del dispositivo
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    final location = await LocationHelper.getCurrentLocation();

    if (location != null) {
      setState(() => _selectedLocation = location);

      /// Mueve el mapa a la ubicación actual
      _mapController.move(location, 15);

      /// Convierte las coordenadas a dirección
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

  /// Maneja el tap en el mapa para seleccionar ubicación
  Future<void> _onMapTap(TapPosition tapPosition, LatLng location) async {
    setState(() => _selectedLocation = location);

    /// Convierte las coordenadas a dirección
    final address = await LocationHelper.getAddressFromCoordinates(
      location.latitude,
      location.longitude,
    );

    if (address != null) {
      _addressController.text = address;
    }
  }

  /// Maneja el registro del cliente
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona tu ubicación en el mapa'),
        ),
      );
      return;
    }

    final controller = Provider.of<UserController>(context, listen: false);

    /// Crea el modelo de usuario con rol 0 (cliente)
    final user = UserModel(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: '',
      role: 0,
      cellphone: _phoneController.text.trim(),
    );

    final success = await controller.register(user);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro exitoso, revisa tu email para tu contraseña'),
          backgroundColor: Color(0xFF5A8A5A),
        ),
      );
      /// Regresa al login
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage ?? 'Error al registrar')),
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
              /// Icono superior
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A8A5A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              const SizedBox(height: 16),

              /// Título
              const Text(
                'Registro de Cliente',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),

              const SizedBox(height: 8),

              /// Subtítulo
              const Text(
                'Crea tu cuenta para comenzar a comprar\ningredientes frescos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF888888),
                ),
              ),

              const SizedBox(height: 24),

              /// Formulario
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
                      /// Campo nombre
                      _buildLabel('Nombre'),
                      _buildTextField(
                        controller: _nameController,
                        hint: 'Ej: Restaurante El Buen Sabor',
                        icon: Icons.storefront_outlined,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu nombre';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      /// Campo teléfono
                      _buildLabel('Número de teléfono'),
                      _buildTextField(
                        controller: _phoneController,
                        hint: '+52 123 456 7890',
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

                      /// Campo email
                      _buildLabel('Correo electrónico'),
                      _buildTextField(
                        controller: _emailController,
                        hint: 'contacto@restaurante.com',
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

                      /// Campo dirección
                      _buildLabel('Dirección de entrega inicial'),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Calle, número, colonia, ciudad, estado',
                          hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
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

                      /// Mapa
                      Row(
                        children: [
                          const Text(
                            'Ubicación en mapa',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '(Opcional)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      /// Contenedor del mapa
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          height: 200,
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              /// Ubicación inicial del mapa
                              initialCenter: const LatLng(19.4326, -99.1332),
                              initialZoom: 12,
                              onTap: _onMapTap,
                            ),
                            children: [
                              /// Capa del mapa OpenStreetMap
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.app',
                              ),

                              /// Marcador de la ubicación seleccionada
                              if (_selectedLocation != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _selectedLocation!,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: Color(0xFF5A8A5A),
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

                      /// Botón seleccionar ubicación actual
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
                                      color: Color(0xFF5A8A5A),
                                    ),
                                  )
                                : const Icon(
                                    Icons.my_location,
                                    color: Color(0xFF5A8A5A),
                                    size: 18,
                                  ),
                            const SizedBox(width: 6),
                            const Text(
                              'Seleccionar ubicación',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF5A8A5A),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      /// Botón continuar
                      Consumer<UserController>(
                        builder: (context, controller, child) {
                          return SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed:
                                  controller.isLoading ? null : _handleRegister,
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

              /// Ya tienes cuenta
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
            ],
          ),
        ),
      ),
    );
  }

  /// Widget reutilizable para los labels de los campos
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

  /// Widget reutilizable para los campos de texto
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