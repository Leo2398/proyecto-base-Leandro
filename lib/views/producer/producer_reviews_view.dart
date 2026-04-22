import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/order_controller.dart';
import '../../controllers/review_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/order_model.dart';
import '../../models/review_model.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';

class ProducerReviewsView extends StatefulWidget {
  const ProducerReviewsView({super.key});

  @override
  State<ProducerReviewsView> createState() => _ProducerReviewsViewState();
}

enum _ReviewFilter { all, withComment, fiveStars, lowScore }

class _ProducerReviewsViewState extends State<ProducerReviewsView> {
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

  final UserService _userService = UserService();

  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastUpdatedAt;

  List<_ProducerReviewEntry> _entries = [];
  Map<int, UserModel> _reviewers = {};
  _ReviewFilter _selectedFilter = _ReviewFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducerReviews();
    });
  }

  Future<void> _loadProducerReviews() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final userController = context.read<UserController>();
      final orderController = context.read<OrderController>();
      final reviewController = context.read<ReviewController>();

      final currentUser = userController.currentUser;
      final producerId = currentUser?.id;

      if (producerId == null || producerId <= 0) {
        throw Exception('No se encontró la sesión del productor.');
      }

      await orderController.loadOrdersByProducer(producerId);

      final completedOrders = orderController.producerOrders
          .where((order) =>
      order.id != null && order.state == OrderController.stateCompleted)
          .toList()
        ..sort((a, b) {
          final aDate = a.registerDate ?? DateTime(2000);
          final bDate = b.registerDate ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });

      final List<_ProducerReviewEntry> loadedEntries = [];
      final Set<int> reviewerIds = <int>{};

      for (final order in completedOrders) {
        final reviews = await reviewController.getReviewsByOrderId(order.id!);
        if (reviews.isNotEmpty) {
          loadedEntries.add(_ProducerReviewEntry(order: order, reviews: reviews));
          for (final review in reviews) {
            if (review.userId > 0) {
              reviewerIds.add(review.userId);
            }
          }
        }
      }

      final Map<int, UserModel> loadedReviewers = {};
      for (final userId in reviewerIds) {
        final user = await _userService.getUserById(userId);
        if (user != null && user.id != null) {
          loadedReviewers[user.id!] = user;
        }
      }

      if (!mounted) return;
      setState(() {
        _entries = loadedEntries;
        _reviewers = loadedReviewers;
        _lastUpdatedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron cargar las reseñas. $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<_FlatReviewItem> get _allReviewItems {
    final List<_FlatReviewItem> items = [];
    for (final entry in _entries) {
      for (final review in entry.reviews) {
        items.add(_FlatReviewItem(order: entry.order, review: review));
      }
    }
    items.sort((a, b) {
      final aDate = a.order.registerDate ?? DateTime(2000);
      final bDate = b.order.registerDate ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
    return items;
  }

  List<_FlatReviewItem> get _filteredItems {
    final items = _allReviewItems;
    switch (_selectedFilter) {
      case _ReviewFilter.all:
        return items;
      case _ReviewFilter.withComment:
        return items.where((item) => item.review.hasComment).toList();
      case _ReviewFilter.fiveStars:
        return items.where((item) => item.review.value == 5).toList();
      case _ReviewFilter.lowScore:
        return items.where((item) => item.review.value <= 3).toList();
    }
  }

  double get _averageRating {
    final items = _allReviewItems;
    if (items.isEmpty) return 0;
    final total = items.fold<int>(0, (sum, item) => sum + item.review.value);
    return total / items.length;
  }

  int get _totalReviews => _allReviewItems.length;

  int get _commentedReviews =>
      _allReviewItems.where((item) => item.review.hasComment).length;

  int get _fiveStarReviews =>
      _allReviewItems.where((item) => item.review.value == 5).length;

  int get _lowScoreReviews =>
      _allReviewItems.where((item) => item.review.value <= 3).length;

  int get _completedOrdersCount => _entries.length;

  Map<int, int> get _distribution {
    final Map<int, int> data = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final item in _allReviewItems) {
      data[item.review.value] = (data[item.review.value] ?? 0) + 1;
    }
    return data;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatHour(DateTime? date) {
    if (date == null) return '--:--';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${_formatDate(date)} • ${_formatHour(date)}';
  }

  String _bs(double value) {
    if (value == value.truncateToDouble()) {
      return 'Bs ${value.toStringAsFixed(0)}';
    }
    return 'Bs ${value.toStringAsFixed(2)}';
  }

  Color _ratingColor(int value) {
    if (value >= 5) return _green;
    if (value == 4) return _blue;
    if (value == 3) return _gold;
    if (value == 2) return _orange;
    return _red;
  }

  String _ratingLabel(int value) {
    switch (value) {
      case 5:
        return 'Excelente';
      case 4:
        return 'Muy buena';
      case 3:
        return 'Buena';
      case 2:
        return 'Regular';
      default:
        return 'Baja';
    }
  }

  Uint8List? _decodeImageBytes(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    try {
      final raw = value.trim();
      final normalized = raw.contains(',')
          ? raw.substring(raw.indexOf(',') + 1)
          : raw;
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  bool _isNetworkImage(String? value) {
    if (value == null) return false;
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('http://') || normalized.startsWith('https://');
  }

  Widget _buildAvatar({
    required String name,
    required String? image,
    double size = 52,
  }) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';
    final bytes = _decodeImageBytes(image);

    if (_isNetworkImage(image)) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.16),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.network(
            image!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialAvatar(initial, size),
          ),
        ),
      );
    }

    if (bytes != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.16),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialAvatar(initial, size),
          ),
        ),
      );
    }

    return _buildInitialAvatar(initial, size);
  }

  Widget _buildInitialAvatar(String initial, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [_primary, Color(0xFFB9854A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 720;

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
              top: 120,
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
                onRefresh: _loadProducerReviews,
                color: _primary,
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      _buildLoadingCard()
                    else if (_errorMessage != null)
                      _buildErrorCard()
                    else ...[
                        _buildHero(isMobile),
                        const SizedBox(height: 18),
                        _buildMetricGrid(screenWidth),
                        const SizedBox(height: 18),
                        _buildDistributionCard(),
                        const SizedBox(height: 18),
                        _buildFilterSection(),
                        const SizedBox(height: 18),
                        _buildReviewList(),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final syncText = _lastUpdatedAt == null
        ? 'Actualiza para ver nuevas opiniones'
        : 'Actualizado ${_formatDateTime(_lastUpdatedAt)}';

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _surface.withOpacity(0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reseñas y calificaciones',
                style: TextStyle(
                  color: _textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                syncText,
                style: const TextStyle(
                  color: _textSoft,
                  fontSize: 12.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _surface.withOpacity(0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: IconButton(
            onPressed: _isLoading ? null : _loadProducerReviews,
            icon: const Icon(Icons.refresh_rounded, color: _primary),
          ),
        ),
      ],
    );
  }

  Widget _buildDecorBubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: _primary),
          SizedBox(height: 16),
          Text(
            'Cargando reseñas...',
            style: TextStyle(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Estamos revisando tus pedidos completados y trayendo las calificaciones de tus clientes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSoft,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _red.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded, color: _red, size: 30),
          ),
          const SizedBox(height: 14),
          const Text(
            'No se pudo abrir esta vista',
            style: TextStyle(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Ocurrió un error inesperado.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 12.8,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadProducerReviews,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Intentar de nuevo'),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(bool isMobile) {
    final averageText = _averageRating == 0 ? '0.0' : _averageRating.toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5A4A41), Color(0xFF443832), Color(0xFF302826)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroTag(Icons.star_rounded, '$averageText promedio'),
              _buildHeroTag(Icons.reviews_outlined, '$_totalReviews reseñas'),
              _buildHeroTag(Icons.chat_bubble_outline_rounded, '$_commentedReviews comentarios'),
              _buildHeroTag(Icons.inventory_2_outlined, '$_completedOrdersCount pedidos calificados'),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Así están viendo tu atención y tus entregas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _totalReviews == 0
                ? 'Aún no tienes reseñas registradas. Cuando un cliente complete y califique un pedido, aparecerá aquí.'
                : 'Aquí puedes ver tus estrellas, comentarios y el detalle de cada pedido calificado para entender mejor la experiencia de tus clientes.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.80),
              fontSize: 12.8,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          isMobile
              ? Column(
            children: [
              _buildHeroScoreCard(averageText),
              const SizedBox(height: 10),
              _buildHeroSecondaryCard(),
            ],
          )
              : Row(
            children: [
              Expanded(child: _buildHeroScoreCard(averageText)),
              const SizedBox(width: 10),
              Expanded(child: _buildHeroSecondaryCard()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroScoreCard(String averageText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.star_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Calificación general',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$averageText / 5',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                _buildStarsRow(_averageRating.round().clamp(0, 5), starSize: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSecondaryCard() {
    final positivePercent = _totalReviews == 0
        ? 0
        : ((_fiveStarReviews / _totalReviews) * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pulso de satisfacción',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$positivePercent% en 5 estrellas',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _totalReviews == 0
                ? 'Todavía no hay datos para medir tendencia.'
                : 'Tus clientes dejaron $_commentedReviews comentarios y $_lowScoreReviews reseñas por revisar con más atención.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.80),
              fontSize: 12.4,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(double screenWidth) {
    final metrics = [
      _MetricItem(
        title: 'Reseñas',
        value: _totalReviews.toString(),
        subtitle: 'Total recibido',
        icon: Icons.reviews_outlined,
        color: _primary,
      ),
      _MetricItem(
        title: 'Promedio',
        value: _averageRating == 0 ? '0.0' : _averageRating.toStringAsFixed(1),
        subtitle: 'Sobre 5 estrellas',
        icon: Icons.star_rounded,
        color: _gold,
      ),
      _MetricItem(
        title: 'Comentadas',
        value: _commentedReviews.toString(),
        subtitle: 'Con opinión escrita',
        icon: Icons.mode_comment_outlined,
        color: _blue,
      ),
      _MetricItem(
        title: 'Por revisar',
        value: _lowScoreReviews.toString(),
        subtitle: '3 estrellas o menos',
        icon: Icons.visibility_outlined,
        color: _orange,
      ),
    ];

    final crossAxisCount = screenWidth >= 1200
        ? 4
        : screenWidth >= 780
        ? 2
        : 2;

    return GridView.builder(
      itemCount: metrics.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: screenWidth < 500 ? 1.12 : 1.42,
      ),
      itemBuilder: (_, index) => _buildMetricCard(metrics[index]),
    );
  }

  Widget _buildMetricCard(_MetricItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: item.color.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    color: _textSoft,
                    fontSize: 11.5,
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

  Widget _buildDistributionCard() {
    final distribution = _distribution;
    final maxValue = distribution.values.fold<int>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribución de estrellas',
            style: TextStyle(
              color: _textDark,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mira rápido en qué rango te están calificando más tus clientes.',
            style: TextStyle(color: _textSoft, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          ...[5, 4, 3, 2, 1].map((star) {
            final count = distribution[star] ?? 0;
            final factor = maxValue == 0 ? 0.0 : count / maxValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Row(
                      children: [
                        Text(
                          '$star',
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.star_rounded, color: _gold, size: 16),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: factor,
                        minHeight: 10,
                        backgroundColor: _surfaceMuted,
                        valueColor: AlwaysStoppedAnimation<Color>(_ratingColor(star)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 30,
                    child: Text(
                      count.toString(),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtrar reseñas',
            style: TextStyle(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cambia rápido entre todas, comentadas, excelentes o las que necesitan más atención.',
            style: TextStyle(color: _textSoft, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildFilterChip(_ReviewFilter.all, 'Todas', Icons.grid_view_rounded),
              _buildFilterChip(_ReviewFilter.withComment, 'Con comentario', Icons.chat_bubble_outline_rounded),
              _buildFilterChip(_ReviewFilter.fiveStars, '5 estrellas', Icons.star_rounded),
              _buildFilterChip(_ReviewFilter.lowScore, 'Por revisar', Icons.visibility_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(_ReviewFilter filter, String label, IconData icon) {
    final isSelected = _selectedFilter == filter;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primary : _surfaceSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? _primary : _divider),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: _primary.withOpacity(0.16),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : _textDark),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : _textDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewList() {
    final items = _filteredItems;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Opiniones de clientes',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${items.length} resultado${items.length == 1 ? '' : 's'} en esta vista',
                      style: const TextStyle(
                        color: _textSoft,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _divider),
                ),
                child: Text(
                  '${_totalReviews} total',
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: _surfaceSoft,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _divider),
              ),
              child: const Column(
                children: [
                  Icon(Icons.rate_review_outlined, size: 54, color: _textSoft),
                  SizedBox(height: 12),
                  Text(
                    'No hay reseñas para este filtro',
                    style: TextStyle(
                      color: _textDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Prueba con otro filtro o espera a que más clientes completen y califiquen pedidos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textSoft,
                      fontSize: 12.8,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            )
          else
            ...items.map(_buildReviewCard),
        ],
      ),
    );
  }

  Widget _buildReviewCard(_FlatReviewItem item) {
    final review = item.review;
    final order = item.order;
    final reviewer = _reviewers[review.userId];
    final reviewerName = reviewer?.name.trim().isNotEmpty == true
        ? reviewer!.name
        : 'Cliente #${review.userId}';
    final ratingColor = _ratingColor(review.value);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(name: reviewerName, image: reviewer?.image),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reviewerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: ratingColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: ratingColor.withOpacity(0.22)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 16, color: ratingColor),
                              const SizedBox(width: 4),
                              Text(
                                '${review.value}.0',
                                style: TextStyle(
                                  color: ratingColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSoftInfoChip(
                          icon: Icons.star_border_rounded,
                          text: _ratingLabel(review.value),
                        ),
                        _buildSoftInfoChip(
                          icon: Icons.receipt_long_rounded,
                          text: 'Pedido #${order.id ?? '-'}',
                        ),
                        _buildSoftInfoChip(
                          icon: Icons.payments_outlined,
                          text: _bs(order.amount),
                        ),
                        _buildSoftInfoChip(
                          icon: Icons.schedule_rounded,
                          text: _formatDateTime(order.registerDate),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildStarsRow(review.value),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Text(
              review.hasComment
                  ? review.comment!.trim()
                  : 'El cliente dejó una calificación sin comentario escrito.',
              style: TextStyle(
                color: review.hasComment ? _textDark : _textSoft,
                fontSize: 13,
                fontWeight: review.hasComment ? FontWeight.w600 : FontWeight.w500,
                height: 1.48,
                fontStyle: review.hasComment ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoftInfoChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _primaryDark),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _textDark,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarsRow(int value, {double starSize = 20}) {
    return Row(
      children: List.generate(5, (index) {
        return Padding(
          padding: EdgeInsets.only(right: index == 4 ? 0 : 2),
          child: Icon(
            index < value ? Icons.star_rounded : Icons.star_border_rounded,
            size: starSize,
            color: _gold,
          ),
        );
      }),
    );
  }
}

class _ProducerReviewEntry {
  final OrderModel order;
  final List<ReviewModel> reviews;

  const _ProducerReviewEntry({
    required this.order,
    required this.reviews,
  });
}

class _FlatReviewItem {
  final OrderModel order;
  final ReviewModel review;

  const _FlatReviewItem({
    required this.order,
    required this.review,
  });
}

class _MetricItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
