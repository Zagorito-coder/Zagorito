// ============================================================
//  shops_map_page.dart — Carte dédiée aux magasins de pêche
//  Indépendante de la page Maps (spots), pour ne pas y toucher.
//  ✅ N'affiche que les magasins ayant une image renseignée
//  ✅ MarkerLayer natif flutter_map v8 (pas de dépendance externe de clustering)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/fishing_shop.dart';
import '../services/shop_service.dart';
import '../theme.dart';
import '../theme_controller.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_back_button.dart';

/// 20 images webP locales pour les cartes magasins (bandeau détail).
const _cardAssets = <String>[
  'assets/Shopsimages/peche-01-ocean-arsenal.webp',
  'assets/Shopsimages/peche-02-sunset-catch.webp',
  'assets/Shopsimages/peche-03-lagoon-pro.webp',
  'assets/Shopsimages/peche-04-carbon-elite.webp',
  'assets/Shopsimages/peche-05-flats-hunter.webp',
  'assets/Shopsimages/peche-06-reef-raider.webp',
  'assets/Shopsimages/peche-07-arctic-strike.webp',
  'assets/Shopsimages/peche-08-amber-wave.webp',
  'assets/Shopsimages/peche-09-deep-blue-kit.webp',
  'assets/Shopsimages/peche-10-twilight-rig.webp',
  'assets/Shopsimages/peche-11-tropic-tackle.webp',
  'assets/Shopsimages/peche-12-black-edition.webp',
  'assets/Shopsimages/peche-13-estuary-master.webp',
  'assets/Shopsimages/peche-14-coral-combat.webp',
  'assets/Shopsimages/peche-15-polar-pursuit.webp',
  'assets/Shopsimages/peche-16-golden-hour.webp',
  'assets/Shopsimages/peche-17-offshore-pro.webp',
  'assets/Shopsimages/peche-18-dusk-patrol.webp',
  'assets/Shopsimages/peche-19-reef-edge.webp',
  'assets/Shopsimages/peche-20-coastal-carbon.webp',
];

/// 20 icônes webP locales pour les marqueurs de la carte.
const _pinAssets = <String>[
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-01.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-02.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-03.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-04.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-05.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-06.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-07.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-08.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-09.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-10.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-11.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-12.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-13.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-14.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-15.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-16.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-17.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-18.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-19.webp',
  'assets/Shopsimages/mini tiles marqueurs/fishing-icon-20.webp',
];

String _shopImageAsset(FishingShop shop) {
  final idx = shop.id.hashCode.abs() % _cardAssets.length;
  return _cardAssets[idx];
}

String _shopPinAsset(FishingShop shop) {
  final idx = shop.id.hashCode.abs() % _pinAssets.length;
  return _pinAssets[idx];
}

class ShopsMapPage extends StatefulWidget {
  const ShopsMapPage({super.key});

  @override
  State<ShopsMapPage> createState() => _ShopsMapPageState();
}

class _ShopsMapPageState extends State<ShopsMapPage> {
  final MapController _mapController = MapController();

  List<FishingShop> _shopsWithImage = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final all = await ShopService.loadShops();

      // Géolocalisation pour trier par distance
      Position? userPos;
      try {
        userPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {}

      final markers = all.toList();
      if (userPos != null) {
        final userLatLng = LatLng(userPos.latitude, userPos.longitude);
        markers.sort((a, b) {
          final dA = const Distance().as(LengthUnit.Kilometer,
              userLatLng, LatLng(a.latitude, a.longitude));
          final dB = const Distance().as(LengthUnit.Kilometer,
              userLatLng, LatLng(b.latitude, b.longitude));
          return dA.compareTo(dB);
        });
      }


      if (mounted) {
        setState(() {
          _shopsWithImage = markers;
          _isLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final tc = ThemeColors.of(context);
        return Scaffold(
          backgroundColor: tc.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(tc),
                Expanded(child: _buildBody(tc)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 10),
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
            child: const Icon(Icons.storefront, color: Color(0xFFFF8C69), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('shopsMap.title'),
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.trArgs('shopsMap.count', args: {'count': _shopsWithImage.length.toString()}),
                  style: TextStyle(
                    color: tc.textSecondary.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeColors tc) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: tc.oceanMedium, strokeWidth: 2.5),
            const SizedBox(height: 12),
            Text(
              context.tr('shopsMap.loading'),
              style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.7), fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: const Color(0xFFEF5350).withValues(alpha: 0.6), size: 48),
            const SizedBox(height: 12),
            Text(context.tr('shopsMap.loadingError'),
                style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.7))),
            TextButton(onPressed: _loadShops, child: Text(context.tr('shops.retry'))),
          ],
        ),
      );
    }

    if (_shopsWithImage.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront,
                  color: tc.textSecondary.withValues(alpha: 0.3), size: 56),
              const SizedBox(height: 16),
              Text(
                context.tr('shopsMap.empty'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tc.textSecondary.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(30.0, 20.0),
        initialZoom: 3.5,
        minZoom: 2,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.zagorito.spots_app',
        ),
        MarkerLayer(
          markers: _shopsWithImage.map((shop) {
            return Marker(
              width: 40,
              height: 40,
              point: LatLng(shop.latitude, shop.longitude),
              child: GestureDetector(
                onTap: () => _showShopDetails(shop, tc),
                child: _ShopPin(imageAsset: _shopPinAsset(shop)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showShopDetails(FishingShop shop, ThemeColors tc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ShopDetailsSheet(shop: shop, tc: tc),
    );
  }
}

class _ShopPin extends StatelessWidget {
  final String imageAsset;
  const _ShopPin({required this.imageAsset});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          imageAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFFF8C69),
            child: const Icon(Icons.storefront, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _ShopDetailsSheet extends StatelessWidget {
  final FishingShop shop;
  final ThemeColors tc;

  const _ShopDetailsSheet({required this.shop, required this.tc});

  bool get _hasPhone => shop.phone.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tc.textSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Container(
              height: 180,
              width: double.infinity,
              margin: const EdgeInsets.only(top: 14),
                  color: tc.surfaceElevated,
                  child: Image.asset(
                    _shopImageAsset(shop),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(Icons.storefront,
                          color: tc.textSecondary.withValues(alpha: 0.3), size: 48),
                    ),
                  ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: TextStyle(
                      color: tc.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(icon: Icons.location_on, text: shop.address, tc: tc),
                  const SizedBox(height: 6),
                  _InfoRow(icon: Icons.access_time, text: '${shop.openTime} — ${shop.closeTime}', tc: tc),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.directions,
                          label: context.tr('shops.route'),
                          color: tc.oceanMedium,
                          onTap: () => _openDirections(context),
                        ),
                      ),
                      if (_hasPhone) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.phone,
                            label: context.tr('shops.call'),
                            color: const Color(0xFF00E676),
                            onTap: () => _callShop(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.chat,
                            label: 'WhatsApp',
                            color: const Color(0xFF25D366),
                            onTap: () => _openWhatsApp(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _digitsOnlyPhone => shop.phone.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _openDirections(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${shop.latitude},${shop.longitude}&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      _showSnack(context, context.tr('shops.routeError'));
    }
  }

  Future<void> _callShop(BuildContext context) async {
    final uri = Uri.parse('tel:${shop.phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      _showSnack(context, context.tr('shops.callError'));
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/$_digitsOnlyPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      _showSnack(context, context.tr('shopsMap.whatsappError'));
    }
  }

  void _showSnack(BuildContext context, String msg) {
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final ThemeColors tc;

  const _InfoRow({required this.icon, required this.text, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: tc.oceanMedium.withValues(alpha: 0.7), size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.8), fontSize: 13)),
        ),
      ],
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
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}