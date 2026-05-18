import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../controllers/user_controller.dart';
import '../../core/location_helper.dart';
import '../../models/schedule_model.dart';
import '../../models/user_model.dart';
import '../../services/location_service.dart';

class ProducerProfileView extends StatefulWidget {
  const ProducerProfileView({super.key});

  @override
  State<ProducerProfileView> createState() => _ProducerProfileViewState();
}

class _ProducerProfileViewState extends State<ProducerProfileView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isInitialized = false;
  bool _isSaving = false;
  bool _isLoadingLocation = false;
  bool _isReloading = false;
  bool _locationVerified = false;

  Uint8List? _profileImageBytes;
  LatLng? _selectedLocation;
  String? _lastResolvedAddress;

  final List<String> _dayNames = const [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  late List<bool> _enabledDays;
  late List<TimeOfDay> _openingTimes;
  late List<TimeOfDay> _closingTimes;

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

  static const int _maxNameLength = 255;
  static const int _maxEmailLength = 255;
  static const int _maxPhoneLength = 30;
  static const int _maxDescriptionLength = 255;
  static const int _maxAddressLength = 255;

  @override
  void initState() {
    super.initState();

    _resetSchedulesToDefault();

    _nameController.addListener(_refresh);
    _emailController.addListener(_refresh);
    _phoneController.addListener(_refresh);
    _descriptionController.addListener(_refresh);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_refresh);
    _emailController.removeListener(_refresh);
    _phoneController.removeListener(_refresh);
    _descriptionController.removeListener(_refresh);

    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _imageController.dispose();
    _addressController.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _resetSchedulesToDefault() {
    _enabledDays = List.generate(7, (_) => false);
    _openingTimes = List.generate(
      7,
          (_) => const TimeOfDay(hour: 8, minute: 0),
    );
    _closingTimes = List.generate(
      7,
          (_) => const TimeOfDay(hour: 18, minute: 0),
    );
  }

  void _clearLocationState({bool clearAddress = true}) {
    _selectedLocation = null;
    _locationVerified = false;
    _lastResolvedAddress = null;

    if (clearAddress) {
      _addressController.text = '';
    }
  }

  void _markAddressAsDirty(String value) {
    final trimmed = value.trim();
    final resolved = (_lastResolvedAddress ?? '').trim();

    final isSameAsResolved =
        resolved.isNotEmpty && trimmed.toLowerCase() == resolved.toLowerCase();

    if (!isSameAsResolved) {
      _locationVerified = false;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _setVerifiedLocation({
    required LatLng point,
    required String address,
  }) {
    _selectedLocation = point;
    _locationVerified = true;
    _lastResolvedAddress = address.trim();
    _addressController.text = address.trim();

    if (mounted) {
      setState(() {});
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(point, 15);
      }
    });
  }

  Future<void> _loadInitialData() async {
    final userController = context.read<UserController>();

    if (mounted) {
      setState(() {
        if (_isInitialized) {
          _isReloading = true;
        }
      });
    }

    try {
      _clearLocationState();
      _resetSchedulesToDefault();

      await userController.loadProducerSchedules();

      final currentUser = userController.currentUser;
      if (currentUser?.id == null) {
        throw Exception('No se encontró un productor logueado');
      }

      final freshUser = await userController.getFreshCurrentUser();
      final userToUse = freshUser ?? currentUser!;

      _fillUserData(userToUse);
      _fillSchedules(userController.producerSchedules);
      await _loadSavedLocation(userToUse);
    } catch (_) {
      _showMessage('No se pudo cargar el perfil del productor');
    } finally {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isReloading = false;
        });
      }
    }
  }

  void _fillUserData(UserModel user) {
    final imageValue = (user.image ?? '').trim();

    _nameController.text = user.name.trim();
    _emailController.text = user.email.trim();
    _phoneController.text = (user.cellphone ?? '').trim();
    _descriptionController.text = (user.description ?? '').trim();
    _imageController.text = imageValue;
    _profileImageBytes = _decodeImageBytes(imageValue);
  }

  Future<void> _loadSavedLocation(UserModel user) async {
    _clearLocationState(clearAddress: true);

    final pickupId = user.pickUpLocationID;
    if (pickupId == null) return;

    try {
      final pickup = await _locationService.getPickupLocationById(pickupId);

      if (pickup == null) return;

      final address = (pickup.address ?? '').trim();
      final latitude = pickup.latitude;
      final longitude = pickup.longitude;

      if (address.isEmpty || latitude == null || longitude == null) {
        _clearLocationState(clearAddress: true);
        return;
      }

      _setVerifiedLocation(
        point: LatLng(latitude, longitude),
        address: address,
      );
    } catch (_) {
      _clearLocationState(clearAddress: true);
    }
  }

  void _fillSchedules(List<ScheduleModel> schedules) {
    _resetSchedulesToDefault();

    for (final schedule in schedules) {
      if (schedule.day < 0 || schedule.day > 6) continue;

      _enabledDays[schedule.day] = true;
      _openingTimes[schedule.day] = _parseTime(schedule.openingTime);
      _closingTimes[schedule.day] = _parseTime(schedule.closingTime);
    }
  }

  Uint8List? _decodeImageBytes(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (_isNetworkImage(value)) return null;

    try {
      final raw = value.trim();
      final normalized =
      raw.contains(',') ? raw.substring(raw.indexOf(',') + 1) : raw;
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  bool _isNetworkImage(String? value) {
    if (value == null) return false;
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }

  Future<void> _showImageSourceSheet() async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final hasImage = _imageController.text.trim().isNotEmpty;

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
                    _buildProfilePhoto(
                      size: 58,
                      radius: 18,
                      showEditBadge: false,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Foto del perfil',
                            style: TextStyle(
                              color: _textDark,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Elige una imagen desde galería o toma una foto nueva.',
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
                _buildSheetOption(
                  icon: Icons.photo_library_outlined,
                  color: _primary,
                  title: 'Elegir desde galería',
                  subtitle: 'Selecciona una foto guardada en tu celular',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickProfileImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 10),
                _buildSheetOption(
                  icon: Icons.photo_camera_outlined,
                  color: _green,
                  title: 'Tomar foto',
                  subtitle: 'Abre la cámara para capturar una imagen nueva',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickProfileImage(ImageSource.camera);
                  },
                ),
                if (hasImage) ...[
                  const SizedBox(height: 10),
                  _buildSheetOption(
                    icon: Icons.delete_outline_rounded,
                    color: _red,
                    title: 'Quitar foto',
                    subtitle: 'Dejar el perfil sin imagen personalizada',
                    onTap: () {
                      Navigator.pop(ctx);
                      _removeProfileImage();
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

  Widget _buildSheetOption({
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

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1100,
        maxHeight: 1100,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      if (bytes.isEmpty) {
        _showMessage('No se pudo leer la imagen seleccionada');
        return;
      }

      final encoded = base64Encode(bytes);

      setState(() {
        _profileImageBytes = bytes;
        _imageController.text = encoded;
      });

      _showMessage('Foto actualizada. No olvides guardar el perfil.', isError: false);
    } catch (_) {
      _showMessage('No se pudo seleccionar la imagen');
    }
  }

  void _removeProfileImage() {
    setState(() {
      _profileImageBytes = null;
      _imageController.clear();
    });

    _showMessage('Foto quitada. Guarda el perfil para aplicar el cambio.', isError: false);
  }

  Future<bool> _requestLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Activa el GPS o los servicios de ubicación');
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _showMessage('Debes conceder permiso de ubicación');
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      _showMessage(
        'El permiso de ubicación está bloqueado. Habilítalo desde la configuración del dispositivo',
      );
      return false;
    }

    return true;
  }

  Future<void> _getCurrentLocation() async {
    FocusScope.of(context).unfocus();

    final allowed = await _requestLocationPermission();
    if (!allowed) return;

    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
      });
    }

    try {
      final location = await LocationHelper.getCurrentLocation();

      if (location == null) {
        _showMessage('No se pudo obtener tu ubicación actual');
        return;
      }

      final address = await LocationHelper.getAddressFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (address == null || address.trim().isEmpty) {
        _selectedLocation = location;
        _locationVerified = false;
        _lastResolvedAddress = null;
        _addressController.text = '';

        if (mounted) {
          setState(() {});
        }

        _mapController.move(location, 15);
        _showMessage(
          'Se obtuvo la coordenada, pero no la dirección. Intenta buscar o tocar el mapa.',
        );
        return;
      }

      _setVerifiedLocation(point: location, address: address);
    } catch (_) {
      _showMessage('Ocurrió un error al obtener tu ubicación actual');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _searchAddressLocation() async {
    FocusScope.of(context).unfocus();

    final typedAddress = _addressController.text.trim();
    if (typedAddress.isEmpty) {
      _showMessage('Ingresa una dirección para buscar');
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
      });
    }

    try {
      final result = await LocationHelper.getCoordinatesFromAddress(
        typedAddress,
      );

      if (result == null) {
        _locationVerified = false;
        if (mounted) setState(() {});
        _showMessage('No se pudo encontrar esa dirección');
        return;
      }

      final reverseAddress = await LocationHelper.getAddressFromCoordinates(
        result.latitude,
        result.longitude,
      );

      final addressToUse =
      reverseAddress != null && reverseAddress.trim().isNotEmpty
          ? reverseAddress.trim()
          : typedAddress;

      _setVerifiedLocation(
        point: result,
        address: addressToUse,
      );
    } catch (_) {
      _showMessage('Ocurrió un error al buscar la dirección');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    FocusScope.of(context).unfocus();

    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
      });
    }

    try {
      _mapController.move(point, _mapController.camera.zoom);

      final address = await LocationHelper.getAddressFromCoordinates(
        point.latitude,
        point.longitude,
      );

      if (address == null || address.trim().isEmpty) {
        _selectedLocation = point;
        _locationVerified = false;
        _lastResolvedAddress = null;
        _addressController.text = '';

        if (mounted) {
          setState(() {});
        }

        _showMessage(
          'No se pudo resolver la dirección de ese punto. Intenta tocar otra zona o usa Buscar.',
        );
        return;
      }

      _setVerifiedLocation(
        point: point,
        address: address.trim(),
      );
    } catch (_) {
      _showMessage('Ocurrió un error al seleccionar la ubicación');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  TimeOfDay _parseTime(String value) {
    try {
      final clean = value.trim();
      if (clean.isEmpty) return const TimeOfDay(hour: 8, minute: 0);

      final parts = clean.split(':');
      if (parts.length < 2) return const TimeOfDay(hour: 8, minute: 0);

      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts[1]) ?? 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  String _displayTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  List<ScheduleModel> _buildSchedules(int producerID) {
    final List<ScheduleModel> schedules = [];

    for (int day = 0; day < 7; day++) {
      if (_enabledDays[day]) {
        schedules.add(
          ScheduleModel(
            day: day,
            openingTime: _formatTimeOfDay(_openingTimes[day]),
            closingTime: _formatTimeOfDay(_closingTimes[day]),
            producerID: producerID,
          ),
        );
      }
    }

    return schedules;
  }

  bool _validateSchedules() {
    final hasAtLeastOneDay = _enabledDays.any((enabled) => enabled);
    if (!hasAtLeastOneDay) {
      _showMessage('Debes habilitar al menos un día de atención');
      return false;
    }

    for (int i = 0; i < 7; i++) {
      if (_enabledDays[i]) {
        final open = _openingTimes[i].hour * 60 + _openingTimes[i].minute;
        final close = _closingTimes[i].hour * 60 + _closingTimes[i].minute;

        if (close <= open) {
          _showMessage(
            'La hora de cierre debe ser mayor que la apertura en ${_dayNames[i]}',
          );
          return false;
        }
      }
    }

    return true;
  }

  bool _validateLocation() {
    if (_addressController.text.trim().isEmpty) {
      _showMessage('Debes ingresar o seleccionar una ubicación');
      return false;
    }

    if (_selectedLocation == null) {
      _showMessage('Debes marcar una ubicación válida en el mapa');
      return false;
    }

    if (!_locationVerified) {
      _showMessage(
        'La ubicación cambió y aún no está validada. Usa Buscar, tu ubicación actual o toca el mapa.',
      );
      return false;
    }

    return true;
  }

  Future<void> _pickTime({
    required int dayIndex,
    required bool isOpening,
  }) async {
    final initialTime =
    isOpening ? _openingTimes[dayIndex] : _closingTimes[dayIndex];

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
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

    if (picked != null && mounted) {
      setState(() {
        if (isOpening) {
          _openingTimes[dayIndex] = picked;
        } else {
          _closingTimes[dayIndex] = picked;
        }
      });
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    if (!_validateSchedules()) return;
    if (!_validateLocation()) return;

    final userController = context.read<UserController>();
    final currentUser = userController.currentUser;

    if (currentUser == null || currentUser.id == null) {
      _showMessage('No se encontró un productor logueado');
      return;
    }

    final schedules = _buildSchedules(currentUser.id!);

    if (mounted) {
      setState(() {
        _isSaving = true;
      });
    }

    try {
      final success = await userController.updateProducerProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        cellphone: _phoneController.text.trim(),
        description: _descriptionController.text.trim(),
        image: _imageController.text.trim().isEmpty
            ? null
            : _imageController.text.trim(),
        schedules: schedules,
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        address: _addressController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        await _loadInitialData();
        if (!mounted) return;

        _showMessage(
          'Perfil del productor actualizado correctamente',
          isError: false,
        );
      } else {
        _showMessage(
          userController.errorMessage ??
              'Ocurrió un error al actualizar el perfil',
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Ocurrió un error inesperado al guardar el perfil');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _reloadData() async {
    await _loadInitialData();
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

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return 'Campo obligatorio';
    if (text.length > _maxNameLength) {
      return 'Máximo $_maxNameLength caracteres';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return 'Ingresa tu correo';
    if (text.length > _maxEmailLength) {
      return 'Máximo $_maxEmailLength caracteres';
    }

    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(text)) {
      return 'Ingresa un correo válido';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return 'Campo obligatorio';
    if (text.length > _maxPhoneLength) {
      return 'Máximo $_maxPhoneLength caracteres';
    }

    final validChars = RegExp(r'^[0-9+\-()\s]+$');
    if (!validChars.hasMatch(text)) {
      return 'Teléfono inválido';
    }

    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 7) {
      return 'Ingresa un teléfono válido';
    }

    return null;
  }

  String? _validateDescription(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return 'Campo obligatorio';
    if (text.length > _maxDescriptionLength) {
      return 'Máximo $_maxDescriptionLength caracteres';
    }

    return null;
  }

  String? _validateAddressText(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return 'Campo obligatorio';
    if (text.length > _maxAddressLength) {
      return 'Máximo $_maxAddressLength caracteres';
    }

    return null;
  }

  double _getMaxContentWidth(double screenWidth) {
    if (screenWidth >= 1500) return 1320;
    if (screenWidth >= 1200) return 1080;
    if (screenWidth >= 1000) return 920;
    return screenWidth;
  }

  EdgeInsets _getResponsivePadding(double screenWidth) {
    if (screenWidth >= 1200) {
      return const EdgeInsets.fromLTRB(28, 16, 28, 120);
    }
    if (screenWidth >= 800) {
      return const EdgeInsets.fromLTRB(20, 14, 20, 120);
    }
    return const EdgeInsets.fromLTRB(16, 12, 16, 120);
  }

  int _activeDaysCount() {
    return _enabledDays.where((e) => e).length;
  }

  String _profileSubtitle() {
    final activeDays = _activeDaysCount();
    if (activeDays == 0) return 'Aún no definiste horarios de atención';
    if (activeDays == 1) return 'Atiendes 1 día por semana';
    return 'Atiendes $activeDays días por semana';
  }

  String _locationSummary() {
    return _locationVerified ? 'Lista' : 'Pendiente';
  }

  Color _locationSummaryColor() {
    return _locationVerified ? _green : _orange;
  }

  String _statusText(UserModel? currentUser) {
    if (currentUser == null) return 'Sin datos';
    if (currentUser.state == 1) return 'Activo';
    if (currentUser.state == 0) return 'Inactivo';
    return 'No definido';
  }

  Color _statusColor(UserModel? currentUser) {
    if (currentUser == null) return _textSoft;
    if (currentUser.state == 1) return _green;
    if (currentUser.state == 0) return _red;
    return _textSoft;
  }

  String _primaryOpeningText() {
    for (int i = 0; i < 7; i++) {
      if (_enabledDays[i]) return _displayTime(_openingTimes[i]);
    }
    return '--:--';
  }

  int _completionPercentage() {
    int completed = 0;
    const int total = 7;

    if (_nameController.text.trim().isNotEmpty) completed++;
    if (_emailController.text.trim().isNotEmpty) completed++;
    if (_phoneController.text.trim().isNotEmpty) completed++;
    if (_descriptionController.text.trim().isNotEmpty) completed++;
    if (_imageController.text.trim().isNotEmpty) completed++;
    if (_addressController.text.trim().isNotEmpty &&
        _selectedLocation != null &&
        _locationVerified) {
      completed++;
    }
    if (_enabledDays.any((e) => e)) completed++;

    return ((completed / total) * 100).round();
  }

  LatLng _initialCenter() {
    return _selectedLocation ?? const LatLng(-17.3935, -66.1570);
  }

  @override
  Widget build(BuildContext context) {
    final userController = context.watch<UserController>();
    final currentUser = userController.currentUser;

    final screenWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = _getMaxContentWidth(screenWidth);

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
              child: !_isInitialized
                  ? _buildLoadingState()
                  : RefreshIndicator(
                onRefresh: _reloadData,
                color: _primary,
                child: Stack(
                  children: [
                    ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: EdgeInsets.zero,
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxContentWidth,
                            ),
                            child: Padding(
                              padding:
                              _getResponsivePadding(screenWidth),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    _buildTopBar(currentUser),
                                    const SizedBox(height: 18),
                                    _buildHeroBanner(currentUser),
                                    const SizedBox(height: 20),
                                    _buildStatsGrid(currentUser),
                                    const SizedBox(height: 20),
                                    _buildBasicInfoSection(),
                                    const SizedBox(height: 20),
                                    _buildContactSection(),
                                    const SizedBox(height: 20),
                                    _buildDescriptionSection(),
                                    const SizedBox(height: 20),
                                    _buildImageSection(),
                                    const SizedBox(height: 20),
                                    _buildLocationSection(),
                                    const SizedBox(height: 20),
                                    _buildScheduleSection(),
                                    const SizedBox(height: 24),
                                    _buildSaveButton(userController),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isReloading)
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _primary),
            SizedBox(height: 16),
            Text(
              'Cargando perfil...',
              style: TextStyle(
                color: _textDark,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(UserModel? currentUser) {
    final name = _nameController.text.trim().isEmpty
        ? 'Productor'
        : _nameController.text.trim();
    final firstName = name.split(' ').first;

    return Row(
      children: [
        _buildAppBarButton(
          icon: Icons.arrow_back_ios_new_rounded,
          color: _textDark,
          onTap: () async => Navigator.pop(context),
        ),
        const SizedBox(width: 10),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _showImageSourceSheet,
          child: _buildProfilePhoto(
            size: 54,
            radius: 18,
            showEditBadge: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mi perfil productor',
                style: TextStyle(
                  color: _textSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Perfil de $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTinyStatusChip(
                    _statusText(currentUser),
                    _statusColor(currentUser),
                  ),
                  _buildTinyStatusChip(
                    '${_completionPercentage()}% completo',
                    _primaryDark,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildAppBarButton(
          icon: _isReloading ? Icons.sync_rounded : Icons.refresh_rounded,
          color: _primary,
          onTap: _reloadData,
        ),
      ],
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required Color color,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onTap(),
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
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildHeroBanner(UserModel? currentUser) {
    final name = _nameController.text.trim().isEmpty
        ? 'Tu negocio productor'
        : _nameController.text.trim();
    final description = _descriptionController.text.trim();

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
                    icon: Icons.storefront_outlined,
                    label: 'Perfil productor',
                  ),
                  _HeroTag(
                    icon: Icons.location_on_outlined,
                    label: 'Ubicación real',
                  ),
                  _HeroTag(
                    icon: Icons.schedule_rounded,
                    label: 'Horarios',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: _showImageSourceSheet,
                    child: _buildProfilePhoto(
                      size: 88,
                      radius: 26,
                      showEditBadge: true,
                    ),
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
                          _profileSubtitle(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.76),
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildHeroMiniTag(
                              label: _statusText(currentUser),
                              color: _statusColor(currentUser) == _green
                                  ? const Color(0xFFCDE8D9)
                                  : const Color(0xFFFFC4B5),
                            ),
                            _buildHeroMiniTag(
                              label: _locationVerified
                                  ? 'Ubicación verificada'
                                  : 'Ubicación pendiente',
                              color: _locationVerified
                                  ? const Color(0xFFCDE8D9)
                                  : const Color(0xFFFFD6A8),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Text(
                  description.isEmpty
                      ? 'Agrega una descripción atractiva para que los restaurantes conozcan mejor tu producción, tu ubicación y lo que ofreces.'
                      : description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Completitud',
                      value: '${_completionPercentage()}%',
                      icon: Icons.task_alt_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Días activos',
                      value: _activeDaysCount().toString(),
                      icon: Icons.calendar_month_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Apertura',
                      value: _primaryOpeningText(),
                      icon: Icons.access_time_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Ubicación',
                      value: _locationSummary(),
                      icon: Icons.pin_drop_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _showImageSourceSheet,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: const Text('Cambiar foto'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () async {
                        await _saveProfile();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _textDark,
                        disabledBackgroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Guardar'),
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
                    fontSize: 17,
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

  Widget _buildProfilePhoto({
    required double size,
    required double radius,
    required bool showEditBadge,
  }) {
    final imageValue = _imageController.text.trim();
    final bytes = _profileImageBytes ?? _decodeImageBytes(imageValue);
    final initial = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : 'P';

    Widget content;

    if (bytes != null) {
      content = Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitialPhoto(initial),
      );
    } else if (_isNetworkImage(imageValue)) {
      content = Image.network(
        imageValue,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitialPhoto(initial),
      );
    } else {
      content = _buildInitialPhoto(initial);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.22),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: content,
          ),
        ),
        if (showEditBadge)
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: size <= 60 ? 24 : 30,
              height: size <= 60 ? 24 : 30,
              decoration: BoxDecoration(
                color: _primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.photo_camera_outlined,
                color: Colors.white,
                size: size <= 60 ? 13 : 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitialPhoto(String initial) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, Color(0xFFB9854A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(UserModel? currentUser) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        double childAspectRatio = constraints.maxWidth < 390 ? 1.05 : 1.15;

        if (constraints.maxWidth >= 960) {
          crossAxisCount = 4;
          childAspectRatio = 1.12;
        } else if (constraints.maxWidth >= 700) {
          crossAxisCount = 4;
          childAspectRatio = 1.0;
        }

        final items = [
          _ProfileStatItem(
            icon: Icons.calendar_month_outlined,
            title: 'Días activos',
            value: _activeDaysCount().toString(),
            subtitle: 'Atención semanal',
            color: _primary,
          ),
          _ProfileStatItem(
            icon: Icons.schedule_outlined,
            title: 'Hora base',
            value: _primaryOpeningText(),
            subtitle: 'Primera apertura',
            color: _primaryDark,
          ),
          _ProfileStatItem(
            icon: Icons.location_on_outlined,
            title: 'Ubicación',
            value: _locationSummary(),
            subtitle: _locationVerified ? 'Verificada' : 'Por validar',
            color: _locationSummaryColor(),
          ),
          _ProfileStatItem(
            icon: Icons.verified_user_outlined,
            title: 'Estado',
            value: _statusText(currentUser),
            subtitle: 'Cuenta productor',
            color: _statusColor(currentUser),
          ),
        ];

        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (_, index) => _buildStatCard(items[index]),
        );
      },
    );
  }

  Widget _buildStatCard(_ProfileStatItem item) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.color, size: 21),
          ),
          const Spacer(),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              color: _textDark,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: _textDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: _textSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSectionCard(
      title: 'Información principal',
      subtitle: 'Nombre del negocio y correo visible en tu perfil productor.',
      icon: Icons.badge_outlined,
      accent: _primaryDark,
      child: Column(
        children: [
          _buildInputCard(
            title: 'Nombre del negocio o finca',
            hint: 'Ej. Finca Los Pinos',
            controller: _nameController,
            icon: Icons.store_mall_directory_outlined,
            validator: _validateName,
            maxLength: _maxNameLength,
          ),
          const SizedBox(height: 14),
          _buildInputCard(
            title: 'Correo electrónico',
            hint: 'productor@email.com',
            controller: _emailController,
            icon: Icons.email_outlined,
            type: TextInputType.emailAddress,
            validator: _validateEmail,
            maxLength: _maxEmailLength,
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return _buildSectionCard(
      title: 'Contacto',
      subtitle: 'Tu teléfono ayuda a coordinar pedidos de forma rápida.',
      icon: Icons.call_outlined,
      accent: _blue,
      child: _buildInputCard(
        title: 'Celular o teléfono',
        hint: 'Ej. 71234567',
        controller: _phoneController,
        icon: Icons.phone_outlined,
        type: TextInputType.phone,
        validator: _validatePhone,
        maxLength: _maxPhoneLength,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-()\s]')),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return _buildSectionCard(
      title: 'Descripción del negocio',
      subtitle: 'Cuenta qué produces, cómo trabajas y qué te diferencia.',
      icon: Icons.notes_rounded,
      accent: _green,
      child: _buildInputCard(
        title: 'Descripción',
        hint:
        'Ej. Productor local de verduras frescas, cosecha semanal y atención directa a restaurantes...',
        controller: _descriptionController,
        icon: Icons.edit_note_outlined,
        maxLines: 5,
        validator: _validateDescription,
        maxLength: _maxDescriptionLength,
      ),
    );
  }

  Widget _buildImageSection() {
    final hasImage = _imageController.text.trim().isNotEmpty;

    return _buildSectionCard(
      title: 'Imagen del perfil',
      subtitle: 'Usa una foto real de tu finca, tu producto, tu equipo o tu logo.',
      icon: Icons.image_outlined,
      accent: _primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    height: 230,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFF1E8DA),
                          Color(0xFFE4D4BC),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: hasImage
                        ? _buildLargePhotoPreview()
                        : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 46,
                            color: _primaryDark,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Aún no agregaste una foto',
                            style: TextStyle(
                              color: _textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Puedes tomar una foto o elegir desde galería',
                            style: TextStyle(
                              color: _textSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _pickProfileImage(ImageSource.gallery),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Galería'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _pickProfileImage(ImageSource.camera),
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Cámara'),
                      ),
                    ),
                  ],
                ),
                if (hasImage) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _removeProfileImage,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _red,
                        side: BorderSide(color: _red.withOpacity(0.35)),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text(
                        'Quitar foto',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoStrip(
            icon: Icons.info_outline_rounded,
            color: _primaryDark,
            text:
            'La imagen se guarda en tu perfil y se mostrará también en dashboard, monedas, pedidos y demás vistas donde aparece tu avatar.',
          ),
        ],
      ),
    );
  }

  Widget _buildLargePhotoPreview() {
    final imageValue = _imageController.text.trim();
    final bytes = _profileImageBytes ?? _decodeImageBytes(imageValue);

    if (bytes != null) {
      return Image.memory(
        bytes,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: _primaryDark,
            size: 42,
          ),
        ),
      );
    }

    if (_isNetworkImage(imageValue)) {
      return Image.network(
        imageValue,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: _primaryDark,
            size: 42,
          ),
        ),
      );
    }

    return const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: _primaryDark,
        size: 42,
      ),
    );
  }

  Widget _buildLocationSection() {
    return _buildSectionCard(
      title: 'Ubicación del negocio',
      subtitle: 'Busca tu dirección, usa tu ubicación actual o marca el punto exacto en el mapa.',
      icon: Icons.location_on_outlined,
      accent: _green,
      child: Column(
        children: [
          _buildInputCard(
            title: 'Dirección o referencia',
            hint: 'Ej. Av. Blanco Galindo km 8, Tiquipaya',
            controller: _addressController,
            icon: Icons.pin_drop_outlined,
            maxLines: 2,
            validator: _validateAddressText,
            maxLength: _maxAddressLength,
            onChanged: _markAddressAsDirty,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final vertical = constraints.maxWidth < 540;

              final currentButton = FilledButton.icon(
                onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                icon: _isLoadingLocation
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('Usar mi ubicación'),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF9FB5A3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              );

              final searchButton = OutlinedButton.icon(
                onPressed: _isLoadingLocation ? null : _searchAddressLocation,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Buscar dirección'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryDark,
                  side: const BorderSide(color: _border),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              );

              if (vertical) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: currentButton),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: searchButton),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: currentButton),
                  const SizedBox(width: 12),
                  Expanded(child: searchButton),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceMuted,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Mapa de ubicación',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _textDark,
                        ),
                      ),
                    ),
                    _buildTinyStatusChip(
                      _locationVerified ? 'Verificada' : 'Pendiente',
                      _locationVerified ? _green : _orange,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _locationVerified
                      ? 'Ubicación validada correctamente.'
                      : 'Toca el mapa para mover el punto exacto y valida la dirección antes de guardar.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _textSoft,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    height: 290,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _initialCenter(),
                            initialZoom: 13,
                            onTap: _onMapTap,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.agromarket',
                            ),
                            MarkerLayer(
                              markers: _selectedLocation == null
                                  ? []
                                  : [
                                Marker(
                                  point: _selectedLocation!,
                                  width: 62,
                                  height: 62,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _locationVerified
                                          ? _green
                                          : _red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.18),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.location_on_rounded,
                                      color: Colors.white,
                                      size: 31,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_isLoadingLocation)
                          Container(
                            color: Colors.white.withOpacity(0.55),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: _primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildLocationChip(
                      icon: Icons.location_searching_outlined,
                      text: _selectedLocation == null
                          ? 'Sin coordenadas'
                          : '${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                    ),
                    _buildLocationChip(
                      icon: _locationVerified
                          ? Icons.verified_rounded
                          : Icons.warning_amber_rounded,
                      text: _locationVerified
                          ? 'Dirección verificada'
                          : 'Dirección pendiente',
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

  Widget _buildLocationChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _primaryDark),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: _textDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return _buildSectionCard(
      title: 'Horarios de atención',
      subtitle: 'Activa los días en que atiendes y define apertura y cierre.',
      icon: Icons.schedule_outlined,
      accent: _green,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _surfaceMuted,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.access_time_filled_rounded,
                    color: _green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _profileSubtitle(),
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _buildTinyStatusChip(
                  '${_activeDaysCount()} días',
                  _activeDaysCount() > 0 ? _green : _orange,
                ),
              ],
            ),
          ),
          ...List.generate(7, (index) => _buildDayScheduleCard(index)),
        ],
      ),
    );
  }

  Widget _buildDayScheduleCard(int index) {
    final isEnabled = _enabledDays[index];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.white : _surfaceMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isEnabled ? const Color(0xFFCFAE7D) : _divider,
          width: isEnabled ? 1.25 : 1,
        ),
        boxShadow: isEnabled
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ]
            : [],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? _primary.withOpacity(0.15)
                      : const Color(0xFFECE3D8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isEnabled
                      ? Icons.calendar_today_rounded
                      : Icons.event_busy_outlined,
                  color: isEnabled ? _primaryDark : const Color(0xFFAA9B8A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _dayNames[index],
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Switch.adaptive(
                value: isEnabled,
                activeColor: _green,
                onChanged: (value) {
                  setState(() {
                    _enabledDays[index] = value;
                  });
                },
              ),
            ],
          ),
          if (isEnabled) ...[
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final vertical = constraints.maxWidth < 460;

                final open = _buildTimeBox(
                  label: 'Apertura',
                  value: _displayTime(_openingTimes[index]),
                  icon: Icons.wb_sunny_outlined,
                  accent: _primary,
                  onTap: () => _pickTime(dayIndex: index, isOpening: true),
                );

                final close = _buildTimeBox(
                  label: 'Cierre',
                  value: _displayTime(_closingTimes[index]),
                  icon: Icons.nightlight_round_outlined,
                  accent: _primaryDark,
                  onTap: () => _pickTime(dayIndex: index, isOpening: false),
                );

                if (vertical) {
                  return Column(
                    children: [
                      open,
                      const SizedBox(height: 10),
                      close,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: open),
                    const SizedBox(width: 12),
                    Expanded(child: close),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeBox({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: _surfaceMuted,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _divider),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      color: _textDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _textSoft,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(UserController userController) {
    final busy = _isSaving || userController.isLoading;

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
          onPressed: busy ? null : _saveProfile,
          icon: busy
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
            busy ? 'Guardando cambios...' : 'Guardar perfil completo',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _textDark,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF958373),
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
    int? maxLength,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
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
            maxLength: maxLength,
            validator: validator,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            style: const TextStyle(
              color: _textDark,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
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
          Icon(icon, color: _ProducerProfileViewState._gold, size: 14),
          const SizedBox(width: 6),
          const Text(
            '',
            style: TextStyle(fontSize: 0),
          ),
          Text(
            label,
            style: const TextStyle(
              color: _ProducerProfileViewState._gold,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatItem {
  const _ProfileStatItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
}