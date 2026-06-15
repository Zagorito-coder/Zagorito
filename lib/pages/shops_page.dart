// ============================================================
//  shops_page.dart — Page Magasins de Pêche
//  Synchronisés avec les spots : affiche par spot proche
//  Itinéraire, téléphone, image, horaires
//  ✅ CORRIGÉ : 100% adaptatif clair/sombre
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../models/fishing_shop.dart';
import '../services/shop_service.dart';
import '../theme.dart';
import '../theme_controller.dart';
import '../l10n/app_localizations.dart';

class ShopsPage extends StatefulWidget {
  const ShopsPage({super.key});

  @override
  State<ShopsPage> createState() => _ShopsPageState();
}

class _ShopsPageState extends State<ShopsPage>
    with SingleTickerProviderStateMixin {
  List<ShopSpotGroup> _groups = [];
  List<FishingShop> _allShops = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final spots = await _loadSpots();
      final shops = await ShopService.loadShops();

      final groups = ShopService.groupShopsBySpot(shops, spots, maxDistanceKm: 60.0);

      if (mounted) {
        setState(() {
          _groups = groups;
          _allShops = shops;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Spot>> _loadSpots() async {
    final raw = await rootBundle.loadString('assets/spots.csv');
    final lines = raw.split('\n');
    final spots = <Spot>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || i == 0) continue;
      try {
        spots.add(Spot.fromCsv(line, index: i));
      } catch (e) {
        debugPrint('[ShopsPage] Ligne CSV ignorée $i: $e');
      }
    }
    return spots;
  }

  List<ShopSpotGroup> get _filteredGroups {
    if (_searchQuery.isEmpty) return _groups;
    final q = _searchQuery.toLowerCase();
    return _groups.where((g) {
      if (g.spotName.toLowerCase().contains(q)) return true;
      for (final s in g.shops) {
        if (s.name.toLowerCase().contains(q) ||
            s.address.toLowerCase().contains(q) ||
            s.tags.any((t) => t.toLowerCase().contains(q))) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final tc = ThemeColors.of(context);
        return Scaffold(
          backgroundColor: tc.background,
          body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(tc)),
            SliverToBoxAdapter(child: _buildSearchBar(tc)),
            if (_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(60),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: tc.oceanMedium,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(child: _buildErrorState(tc))
            else if (_filteredGroups.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState(tc))
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, index) => _buildSpotSection(_filteredGroups[index], index, tc),
                  childCount: _filteredGroups.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  },
);
  }

  // ═══════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader(ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C69).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFF8C69).withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.storefront,
              color: Color(0xFFFF8C69),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('shops.title'),
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.trArgs('shops.syncCount', args: {'count': _allShops.length.toString()}),
                  style: TextStyle(
                    color: tc.textSecondary.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_allShops.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C69).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                context.trArgs('shops.spotCount', args: {'count': _groups.length.toString()}),
                style: const TextStyle(
                  color: Color(0xFFFF8C69),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  BARRE DE RECHERCHE
  // ═══════════════════════════════════════════════════════════

  Widget _buildSearchBar(ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tc.textSecondary.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          style: TextStyle(color: tc.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search,
                color: tc.textSecondary.withValues(alpha: 0.5), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () => setState(() => _searchQuery = ''),
                    child: Icon(Icons.close,
                        color: tc.textSecondary.withValues(alpha: 0.5), size: 18),
                  )
                : null,
            hintText: context.tr('shops.search'),
            hintStyle: TextStyle(
              color: tc.textSecondary.withValues(alpha: 0.4),
              fontSize: 13,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SECTION SPOT — regroupement de magasins
  // ═══════════════════════════════════════════════════════════

  Widget _buildSpotSection(ShopSpotGroup group, int groupIndex, ThemeColors tc) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(
            (groupIndex * 0.1).clamp(0.0, 0.8),
            ((groupIndex * 0.1) + 0.4).clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tc.oceanMedium,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.spotName,
                    style: TextStyle(
                      color: tc.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tc.oceanDeep.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tc.oceanMedium.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    context.trArgs('shops.shopCount', args: {'count': group.shops.length.toString()}),
                    style: TextStyle(
                      color: tc.oceanMedium,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...group.shops.map((shop) => _buildShopCard(shop, tc)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  CARTE MAGASIN
  // ═══════════════════════════════════════════════════════════

  Widget _buildShopCard(FishingShop shop, ThemeColors tc) {
    final now = DateTime.now();
    final openParts = shop.openTime.split(':');
    final closeParts = shop.closeTime.split(':');
    final openH = int.tryParse(openParts[0]) ?? 0;
    final openM = int.tryParse(openParts[1]) ?? 0;
    final closeH = int.tryParse(closeParts[0]) ?? 0;
    final closeM = int.tryParse(closeParts[1]) ?? 0;
    final currentMinutes = now.hour * 60 + now.minute;
    final openMinutes = openH * 60 + openM;
    final closeMinutes = closeH * 60 + closeM;
    final isOpenNow = currentMinutes >= openMinutes && currentMinutes <= closeMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tc.textSecondary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  height: 130,
                  width: double.infinity,
                  color: tc.surfaceElevated,
                  child: Image.network(
                    shop.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: tc.surfaceElevated,
                      child: Center(
                        child: Icon(
                          Icons.storefront,
                          color: tc.textSecondary.withValues(alpha: 0.3),
                          size: 48,
                        ),
                      ),
                    ),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: tc.surfaceElevated,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: tc.oceanMedium.withValues(alpha: 0.3),
                            strokeWidth: 2,
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOpenNow
                        ? const Color(0xFF00E676).withValues(alpha: 0.9)
                        : const Color(0xFFEF5350).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOpenNow ? context.tr('shops.open') : context.tr('shops.closed'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (shop.rating != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFFD700), size: 12),
                        const SizedBox(width: 3),
                        Text(
                          '${shop.rating}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        color: tc.oceanMedium.withValues(alpha: 0.7),
                        size: 13),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        shop.address,
                        style: TextStyle(
                          color: tc.textSecondary.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: shop.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8C69).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                              const Color(0xFFFF8C69).withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFFFF8C69),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        color: tc.textSecondary.withValues(alpha: 0.5), size: 13),
                    const SizedBox(width: 5),
                    Text(
                      '${shop.openTime} — ${shop.closeTime}',
                      style: TextStyle(
                        color: tc.textSecondary.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Builder(builder: (context) {
                      final soonBadge = _buildSoonBadge(openMinutes, closeMinutes, currentMinutes);
                      if (soonBadge != null) return soonBadge;
                      return const SizedBox.shrink();
                    }),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.directions,
                        label: context.tr('shops.route'),
                        color: tc.oceanMedium,
                        onTap: () => _openDirections(shop),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.phone,
                        label: context.tr('shops.call'),
                        color: const Color(0xFF00E676),
                        onTap: () => _callShop(shop),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ActionButtonCompact(
                      icon: Icons.content_copy,
                      color: tc.textSecondary.withValues(alpha: 0.5),
                      onTap: () => _copyCoords(shop),
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

  // ═══════════════════════════════════════════════════════════
  //  BADGE "FERME BIENTÔT / OUVRE BIENTÔT"
  // ═══════════════════════════════════════════════════════════

  Widget? _buildSoonBadge(int openMin, int closeMin, int currentMin) {
    if (currentMin < closeMin && (closeMin - currentMin) <= 30) {
      return _SoonBadge(text: context.tr('shops.closingSoon'), color: const Color(0xFFFF8C69));
    }
    if (currentMin < openMin && (openMin - currentMin) <= 30) {
      return _SoonBadge(text: context.tr('shops.openingSoon'), color: const Color(0xFFFFD700));
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  //  ÉTATS VIDES / ERREURS
  // ═══════════════════════════════════════════════════════════

  Widget _buildErrorState(ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.error_outline,
              color: const Color(0xFFEF5350).withValues(alpha: 0.6), size: 48),
          const SizedBox(height: 16),
          Text(
            context.tr('shops.loadingError'),
            style: TextStyle(
              color: tc.textSecondary.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadData,
            child: Text(context.tr('shops.retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Icon(Icons.search_off,
              color: tc.textSecondary.withValues(alpha: 0.3), size: 56),
          const SizedBox(height: 16),
          Text(
            context.tr('shops.empty'),
            style: TextStyle(
              color: tc.textSecondary.withValues(alpha: 0.6),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('shops.tryOtherSearch'),
            style: TextStyle(
              color: tc.textSecondary.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════════════

  Future<void> _openDirections(FishingShop shop) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${shop.latitude},${shop.longitude}&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showSnack(context.tr('shops.routeError'));
    }
  }

  Future<void> _callShop(FishingShop shop) async {
    final phone = shop.phone.replaceAll(' ', '').replaceAll('-', '');
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) _showSnack(context.tr('shops.callError'));
    }
  }

  Future<void> _copyCoords(FishingShop shop) async {
    final text = '${shop.name}\n${shop.latitude}, ${shop.longitude}\n${shop.address}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _showSnack(context.tr('shops.copied'));
  }

  void _showSnack(String msg) {
    final tc = ThemeColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: tc.textPrimary)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: tc.surfaceElevated,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  WIDGETS INTERNES
// ═══════════════════════════════════════════════════════════

class _SoonBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _SoonBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtonCompact extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButtonCompact({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
