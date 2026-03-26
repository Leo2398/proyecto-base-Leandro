import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
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

  bool _isInitialized = false;
  bool _isSaving = false;
  bool _isLoadingLocation = false;
  bool _isReloading = false;
  bool _locationVerified = false;

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

  static const Color _background = Color(0xFFF6F1E8);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF4E3426);
  static const Color _textSecondary = Color(0xFF8B7A6A);
  static const Color _border = Color(0xFFE6DACB);
  static const Color _primary = Color(0xFFC69A5B);
  static const Color _primaryDark = Color(0xFF8B6B4A);
  static const Color _green = Color(0xFF4E7A52);
  static const Color _inputBg = Color(0xFFFBF8F3);
  static const Color _danger = Color(0xFFB85C38);

  static const int _maxNameLength = 255;
  static const int _maxEmailLength = 255;
  static const int _maxPhoneLength = 30;
  static const int _maxDescriptionLength = 255;
  static const int _maxImageLength = 255;
  static const int _maxAddressLength = 255;

  @override
  void initState() {
    super.initState();

    _resetSchedulesToDefault();

    _nameController.addListener(_refresh);
    _emailController.addListener(_refresh);
    _phoneController.addListener(_refresh);
    _descriptionController.addListener(_refresh);
    _imageController.addListener(_refresh);
    _addressController.addListener(_refresh);

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
    _imageController.removeListener(_refresh);
    _addressController.removeListener(_refresh);

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
        if (!_isInitialized) {
          _isInitialized = false;
        } else {
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
    } catch (e) {
      _showMessage(
        'No se pudo cargar el perfil del productor',
      );
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
    _nameController.text = user.name.trim();
    _emailController.text = user.email.trim();
    _phoneController.text = (user.cellphone ?? '').trim();
    _descriptionController.text = (user.description ?? '').trim();
    _imageController.text = (user.image ?? '').trim();
  }

  Future<void> _loadSavedLocation(UserModel user) async {
    _clearLocationState(clearAddress: true);

    final pickupId = user.pickUpLocationID;
    if (pickupId == null) {
      return;
    }

    try {
      final pickup = await _locationService.getPickupLocationById(pickupId);

      if (pickup == null) {
        return;
      }

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
          'Se obtuvo la coordenada, pero no la dirección. Intenta nuevamente o usa Buscar',
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

      final addressToUse = (reverseAddress != null && reverseAddress.trim().isNotEmpty)
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
          'No se pudo resolver la dirección de ese punto. Intenta tocar de nuevo o usa Buscar',
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
            'La hora de cierre debe ser mayor que la de apertura en ${_dayNames[i]}',
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
        'La ubicación cambió y aún no está validada. Usa Buscar, tu ubicación actual o toca nuevamente el mapa',
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
              onSurface: _textPrimary,
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
          backgroundColor: isError ? const Color(0xFF6D4C41) : _green,
          content: Text(message),
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

  String? _validateImageUrl(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return null;
    if (text.length > _maxImageLength) {
      return 'Máximo $_maxImageLength caracteres';
    }

    final uri = Uri.tryParse(text);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return 'Ingresa una URL válida';
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
    if (screenWidth >= 1400) return 1120;
    if (screenWidth >= 1100) return 980;
    if (screenWidth >= 850) return 840;
    return screenWidth;
  }

  EdgeInsets _getResponsivePadding(double screenWidth) {
    if (screenWidth >= 1000) {
      return const EdgeInsets.fromLTRB(28, 20, 28, 120);
    }
    return const EdgeInsets.fromLTRB(16, 14, 16, 110);
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

  String _statusText(UserModel? currentUser) {
    if (currentUser == null) return 'Sin datos';
    if (currentUser.state == 1) return 'Activo';
    if (currentUser.state == 0) return 'Inactivo';
    return 'No definido';
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
      backgroundColor: _background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF7F2EA),
              Color(0xFFF4EEE5),
              Color(0xFFF1E9DE),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: !_isInitialized
              ? const Center(
            child: CircularProgressIndicator(color: _primary),
          )
              : RefreshIndicator(
            onRefresh: _reloadData,
            color: _primary,
            child: Stack(
              children: [
                ListView(
                  padding: _getResponsivePadding(screenWidth),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints:
                        BoxConstraints(maxWidth: maxContentWidth),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTopBar(),
                              const SizedBox(height: 18),
                              _buildHeroBanner(currentUser),
                              const SizedBox(height: 16),
                              _buildStatsGrid(currentUser),
                              const SizedBox(height: 18),
                              _buildBasicInfoSection(),
                              const SizedBox(height: 18),
                              _buildContactSection(),
                              const SizedBox(height: 18),
                              _buildDescriptionSection(),
                              const SizedBox(height: 18),
                              _buildImageSection(),
                              const SizedBox(height: 18),
                              _buildLocationSection(),
                              const SizedBox(height: 18),
                              _buildScheduleSection(),
                              const SizedBox(height: 22),
                              _buildSaveButton(userController),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isReloading)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: const LinearProgressIndicator(
                      color: _primary,
                      backgroundColor: Colors.transparent,
                      minHeight: 3,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _textPrimary,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mi perfil productor',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Actualiza la información completa de tu finca o negocio',
                style: TextStyle(
                  fontSize: 12.5,
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: _reloadData,
            icon: const Icon(
              Icons.refresh_rounded,
              color: _primaryDark,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBanner(UserModel? currentUser) {
    final hasImage = _imageController.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFD9CBBB),
            Color(0xFFCDB18C),
            Color(0xFFB88D61),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
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
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      child: hasImage
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.network(
                          _imageController.text.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.agriculture_rounded,
                              color: Colors.white,
                              size: 36,
                            );
                          },
                        ),
                      )
                          : const Icon(
                        Icons.agriculture_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text.trim().isEmpty
                                ? 'Tu negocio productor'
                                : _nameController.text.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _profileSubtitle(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.92),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildHeroMiniTag(
                            icon: Icons.verified_user_outlined,
                            label: _statusText(currentUser),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildHeroChip(
                      icon: Icons.email_outlined,
                      label: _emailController.text.trim().isEmpty
                          ? 'Sin correo'
                          : _emailController.text.trim(),
                    ),
                    _buildHeroChip(
                      icon: Icons.phone_outlined,
                      label: _phoneController.text.trim().isEmpty
                          ? 'Sin teléfono'
                          : _phoneController.text.trim(),
                    ),
                    _buildHeroChip(
                      icon: Icons.location_on_outlined,
                      label: _locationVerified
                          ? 'Ubicación verificada'
                          : 'Ubicación pendiente',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resumen del perfil',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _descriptionController.text.trim().isEmpty
                            ? 'Agrega una descripción atractiva para que los restaurantes conozcan mejor tu producción, tu ubicación y lo que ofreces.'
                            : _descriptionController.text.trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.2,
                          height: 1.42,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 9,
                                value: _completionPercentage() / 100,
                                backgroundColor: Colors.white.withOpacity(0.22),
                                valueColor:
                                const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_completionPercentage()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
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

  Widget _buildHeroMiniTag({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(UserModel? currentUser) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 760;
        const double spacing = 12;
        final double cardWidth = isWide
            ? (constraints.maxWidth - (spacing * 3)) / 4
            : (constraints.maxWidth - spacing) / 2;

        final items = [
          _buildStatCard(
            icon: Icons.calendar_month_outlined,
            title: 'Días activos',
            value: _activeDaysCount().toString(),
            accent: _primary,
          ),
          _buildStatCard(
            icon: Icons.schedule_outlined,
            title: 'Hora base',
            value: _primaryOpeningText(),
            accent: _primaryDark,
          ),
          _buildStatCard(
            icon: Icons.location_on_outlined,
            title: 'Ubicación',
            value: _locationSummary(),
            accent: _green,
          ),
          _buildStatCard(
            icon: Icons.verified_user_outlined,
            title: 'Estado',
            value: _statusText(currentUser),
            accent: const Color(0xFF6D4C41),
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
              width: cardWidth,
              child: item,
            ),
          )
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              color: _textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: _textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSectionCard(
      title: 'Información principal',
      subtitle: 'Nombre del negocio y correo visible en tu perfil productor',
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
      subtitle: 'Tu teléfono ayuda a coordinar pedidos y contacto más rápido',
      icon: Icons.call_outlined,
      accent: _primaryDark,
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
      subtitle: 'Cuenta qué produces, cómo trabajas y qué te diferencia',
      icon: Icons.notes_rounded,
      accent: _green,
      child: _buildInputCard(
        title: 'Descripción',
        hint:
        'Ej. Productor local de verduras frescas, cosecha semanal, atención directa a restaurantes...',
        controller: _descriptionController,
        icon: Icons.edit_note_outlined,
        maxLines: 5,
        validator: _validateDescription,
        maxLength: _maxDescriptionLength,
      ),
    );
  }

  Widget _buildImageSection() {
    final imageUrl = _imageController.text.trim();
    final hasImage = imageUrl.isNotEmpty;

    return _buildSectionCard(
      title: 'Imagen del perfil',
      subtitle:
      'Puedes mostrar una foto de tu finca, logo o imagen representativa',
      icon: Icons.image_outlined,
      accent: _primary,
      child: Column(
        children: [
          _buildInputCard(
            title: 'URL de imagen',
            hint: 'https://...',
            controller: _imageController,
            icon: Icons.link_rounded,
            validator: _validateImageUrl,
            maxLength: _maxImageLength,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _inputBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vista previa',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 210,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFF1E8DA),
                        Color(0xFFE4D4BC),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: hasImage
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                            color: _primaryDark,
                          ),
                        );
                      },
                    ),
                  )
                      : const Center(
                    child: Icon(
                      Icons.image_search_outlined,
                      size: 42,
                      color: _primaryDark,
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

  Widget _buildLocationSection() {
    return _buildSectionCard(
      title: 'Ubicación del negocio',
      subtitle:
      'Busca tu dirección, usa tu ubicación actual o marca el punto exacto en el mapa',
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
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
                      : const Icon(Icons.my_location_rounded),
                  label: const Text('Usar mi ubicación'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF9FB5A3),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoadingLocation ? null : _searchAddressLocation,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Buscar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryDark,
                    side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _inputBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mapa de ubicación',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _locationVerified
                      ? 'Ubicación validada correctamente'
                      : 'Toca el mapa para mover el punto exacto y valida la dirección antes de guardar',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    height: 290,
                    child: FlutterMap(
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
                              width: 60,
                              height: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _locationVerified
                                      ? _green
                                      : _danger,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                          ],
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
                          : 'Dirección pendiente de validar',
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
        color: const Color(0xFFF7F2EA),
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
              color: _textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return _buildSectionCard(
      title: 'Horarios de atención',
      subtitle: 'Activa los días en que atiendes y define apertura y cierre',
      icon: Icons.schedule_outlined,
      accent: _green,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F2EA),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _border),
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
                      color: _textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
        color: isEnabled ? Colors.white : _inputBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isEnabled ? const Color(0xFFCFAE7D) : _border,
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
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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
            Row(
              children: [
                Expanded(
                  child: _buildTimeBox(
                    label: 'Apertura',
                    value: _displayTime(_openingTimes[index]),
                    icon: Icons.wb_sunny_outlined,
                    accent: _primary,
                    onTap: () => _pickTime(dayIndex: index, isOpening: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeBox(
                    label: 'Cierre',
                    value: _displayTime(_closingTimes[index]),
                    icon: Icons.nightlight_round_outlined,
                    accent: _primaryDark,
                    onTap: () => _pickTime(dayIndex: index, isOpening: false),
                  ),
                ),
              ],
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
          color: const Color(0xFFF7F2EA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
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
                      color: _textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      color: _textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(UserController userController) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_isSaving || userController.isLoading) ? null : _saveProfile,
        icon: (_isSaving || userController.isLoading)
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
          (_isSaving || userController.isLoading)
              ? 'Guardando cambios...'
              : 'Guardar perfil completo',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _textPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF958373),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
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
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500,
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
        color: _inputBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
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
              color: _textPrimary,
              fontWeight: FontWeight.w600,
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
                borderSide: const BorderSide(
                  color: _danger,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: _danger,
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
        Icon(
          icon,
          size: 18,
          color: _primaryDark,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }
}