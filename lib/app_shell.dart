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
    final isDark = ThemeController.instance.isDark;
    return ColoredBox(
      color: tc.background,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(9, 7, 9, 8),
        child: SizedBox(
          key: const ValueKey<String>('bottom-navigation-shell'),
          height: 76,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 66,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tc.surface.withValues(alpha: isDark ? 0.94 : 0.97),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isDark
                          ? tc.oceanLight.withValues(alpha: 0.5)
                          : tc.oceanDeep.withValues(alpha: 0.24),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? tc.oceanDeep.withValues(alpha: 0.22)
                            : tc.shadowColor.withValues(alpha: 0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _NavItem(
                          itemKey: const ValueKey<String>('bottom-nav-home'),
                          icon: Icons.home_rounded,
                          label: context.tr('bottomNav.home'),
                          isActive: _currentIndex == 0,
                          onTap: () => navigateTo(0),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          itemKey: const ValueKey<String>('bottom-nav-fish'),
                          icon: Icons.set_meal_rounded,
                          label: context.tr('bottomNav.fish'),
                          isActive: _currentIndex == 1,
                          onTap: () => navigateTo(1),
                        ),
                      ),
                      Expanded(
                        child: _NavMapButton(
                          key: const ValueKey<String>('bottom-nav-spots'),
                          label: context.tr('drawer.spots'),
                          isActive: _currentIndex == 3,
                          onTap: () => navigateTo(3),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          itemKey:
                              const ValueKey<String>('bottom-nav-my-spots'),
                          icon: Icons.add_location_alt_rounded,
                          label: context.tr('bottomNav.addSpot'),
                          isActive: _currentIndex == 2,
                          onTap: () => navigateTo(2),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          itemKey:
                              const ValueKey<String>('bottom-nav-settings'),
                          icon: Icons.settings_rounded,
                          label: context.tr('bottomNav.settings'),
                          isActive: _currentIndex == 4,
                          onTap: () => navigateTo(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
  final Key itemKey;
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.itemKey,
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
      child: InkResponse(
        key: itemKey,
        onTap: onTap,
        radius: 31,
        containedInkWell: true,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 66,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 8, 3, 7),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: isActive ? tc.oceanLight : tc.textMuted,
                      size: 25,
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: isActive ? tc.oceanLight : tc.textSecondary,
                          fontSize: 10.5,
                          height: 1,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: 43,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: tc.oceanLight,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: tc.oceanLight.withValues(alpha: 0.55),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavMapButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavMapButton({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final isDark = ThemeController.instance.isDark;

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 38,
        customBorder: const CircleBorder(),
        child: SizedBox(
          height: 76,
          child: Align(
            alignment: Alignment.topCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isDark ? tc.background.withValues(alpha: 0.98) : tc.surface,
                border: Border.all(
                  color: tc.oceanLight,
                  width: isActive ? 2.2 : 1.7,
                ),
                boxShadow: [
                  BoxShadow(
                    color: tc.oceanLight.withValues(
                      alpha: isActive ? 0.48 : 0.3,
                    ),
                    blurRadius: isActive ? 15 : 10,
                  ),
                  BoxShadow(
                    color: tc.shadowColor.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    color: tc.oceanLight,
                    size: 30,
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: isActive ? tc.oceanLight : tc.textPrimary,
                        fontSize: 10.5,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
