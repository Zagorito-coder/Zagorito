// ============================================================
//  app_shell.dart — Shell de navigation principal
//  BottomNavBar custom avec : Home, Fish, Add, Map, Settings
//  + Bouton toggle thème Clair/Sombre intégré
// ============================================================

import 'package:flutter/material.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/pages/home_page.dart';
import 'package:spots_app/pages/species_page.dart';
import 'package:spots_app/pages/settings_page.dart';
import 'package:spots_app/pages/spot_finder_page.dart';
import 'package:spots_app/pages/techniques_page.dart';
import 'package:spots_app/pages/community_page.dart';
import 'package:spots_app/pages/shops_page.dart';
import 'package:spots_app/pages/tide_page.dart';
import 'package:spots_app/pages/forecast_page.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/services/ad_service.dart';
import 'package:spots_app/widgets/adaptive_banner_ad.dart';

/// Clé globale pour accéder au state de navigation
final GlobalKey<AppShellState> appShellKey = GlobalKey<AppShellState>();

/// Shell principal de l'application avec navigation par onglets
class AppShell extends StatefulWidget {
  final List<Spot>? initialSpots;
  const AppShell({super.key, this.initialSpots});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _currentIndex = 3;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePageWrapper(initialSpots: widget.initialSpots),
      const SpeciesPageWrapper(),
      const AddSpotPlaceholder(),
      SpotFinderPage(initialSpots: widget.initialSpots),
      const SettingsPageWrapper(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Le cœur de l'application est déjà chargé et l'activité Android est
      // attachée avant d'afficher, si nécessaire, le formulaire UMP.
      AdService.instance.initialize();
    });
  }

  /// Navigue vers un onglet spécifique
  void navigateTo(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.instance,
        LanguageController.instance,
      ]),
      builder: (context, _) => PopScope(
        canPop: _currentIndex == 3,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _currentIndex != 3) navigateTo(3);
        },
        child: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: List.generate(_pages.length, (index) {
                    return Visibility(
                      visible: _currentIndex == index,
                      maintainState: true,
                      // Keep each page's state, but stop hidden animations.
                      // The home mini-map has its own pulse ticker; leaving it
                      // active while the full map renders thousands of spots
                      // causes avoidable CPU/GPU pressure on low-end devices.
                      maintainAnimation: false,
                      maintainSize: false,
                      child: _pages[index],
                    );
                  }),
                ),
              ),
              const AdaptiveBannerAd(),
            ],
          ),
          bottomNavigationBar: _buildBottomNav(tc),
        ),
      ),
    );
  }

  Widget _buildBottomNav(ThemeColors tc) {
    return Container(
      decoration: BoxDecoration(
        color: tc.background.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: tc.navOverlay,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: tc.glassBorder.withValues(alpha: 0.75),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: tc.shadowColor.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: SizedBox(
                height: 66,
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: _NavItem(
                          icon: Icons.home_rounded,
                          label: context.tr('bottomNav.home'),
                          isActive: _currentIndex == 0,
                          onTap: () => navigateTo(0),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _NavItem(
                          icon: Icons.set_meal,
                          label: context.tr('bottomNav.fish'),
                          isActive: _currentIndex == 1,
                          onTap: () => navigateTo(1),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _NavMapButton(
                          label: context.tr('bottomNav.map'),
                          isActive: _currentIndex == 3,
                          onTap: () => navigateTo(3),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _NavItem(
                          icon: Icons.add_location_alt_rounded,
                          label: context.tr('bottomNav.addSpot'),
                          isActive: _currentIndex == 2,
                          onTap: () => navigateTo(2),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _NavItem(
                          icon: Icons.settings_rounded,
                          label: context.tr('bottomNav.settings'),
                          isActive: _currentIndex == 4,
                          onTap: () => navigateTo(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  WIDGETS INTERNES
// ─────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // Equal-width slots keep every label centered, including the
          // localized strings with different lengths.
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? tc.oceanMedium.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? tc.oceanLight : tc.textMuted,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: isActive ? tc.oceanLight : tc.textMuted,
                  fontSize: 9.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavMapButton extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavMapButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavMapButton> createState() => _NavMapButtonState();
}

class _NavMapButtonState extends State<_NavMapButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return Semantics(
      button: true,
      selected: widget.isActive,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 70,
          height: 66,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final phase = _pulseController.value;
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (widget.isActive)
                    for (final ring in [0.0, 0.46])
                      Opacity(
                        opacity: (0.22 * (1 - phase)).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 1.0 + ring + phase * 0.16,
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: tc.oceanLight,
                                width: ring == 0 ? 1.3 : 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [tc.oceanMedium, tc.oceanDeep],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tc.oceanDeep.withValues(alpha: 0.42),
                          blurRadius: 13,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.map_rounded,
                      color: tc.textPrimary,
                      size: 30,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  WRAPPERS — utilisent la GlobalKey pour la navigation
// ─────────────────────────────────────────────────────────────

class HomePageWrapper extends StatelessWidget {
  final List<Spot>? initialSpots;
  const HomePageWrapper({super.key, this.initialSpots});

  @override
  Widget build(BuildContext context) {
    return HomePage(
      initialSpots: initialSpots,
      onNavigateToSpots: () => appShellKey.currentState?.navigateTo(3),
      onNavigateToSpecies: () => appShellKey.currentState?.navigateTo(1),
      onNavigateToTechniques: () => _goTo(context, const TechniquesPage()),
      onNavigateToCommunity: () => _goTo(context, const CommunityPage()),
      onNavigateToShops: () => _goTo(context, const ShopsPage()),
      onNavigateToTides: () => _goTo(context, const TidePage()),
      // Debug route / bouton caché : long-press sur "Marées" dans le drawer
      onNavigateToTidesV2: () => _goTo(context, const ForecastPage()),
    );
  }

  void _goTo(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class SpeciesPageWrapper extends StatelessWidget {
  const SpeciesPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const SpeciesPage();
  }
}

class SettingsPageWrapper extends StatelessWidget {
  const SettingsPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsPage();
  }
}

class AddSpotPlaceholder extends StatelessWidget {
  const AddSpotPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, child) {
        final tc = ThemeColors.of(context);

        return Scaffold(
          backgroundColor: tc.background,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: tc.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.add_location_alt,
                    size: 48,
                    color: tc.oceanMedium,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Ajouter un Spot',
                  style: AppTextStyles.headlineMedium(context),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fonctionnalité à venir...',
                  style: AppTextStyles.bodyMedium(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
