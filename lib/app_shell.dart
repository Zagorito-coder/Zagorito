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
import 'package:spots_app/pages/premium_page.dart';
import 'package:spots_app/pages/shops_page.dart';
import 'package:spots_app/pages/tide_page.dart';
import 'package:spots_app/pages/windguru_page.dart';
import 'package:spots_app/models.dart';

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
      builder: (context, _) => Scaffold(
        body: Stack(
          children: List.generate(_pages.length, (index) {
            return Visibility(
              visible: _currentIndex == index,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: false,
              child: _pages[index],
            );
          }),
        ),
        bottomNavigationBar: _buildBottomNav(tc),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: LanguageController.instance.isRtl ? 'الرئيسية' : (LanguageController.instance.langCode == 'en' ? 'Home' : 'Accueil'),
                isActive: _currentIndex == 0,
                onTap: () => navigateTo(0),
              ),
              _NavItem(
                icon: Icons.set_meal,
                label: LanguageController.instance.isRtl ? 'الأسماك' : (LanguageController.instance.langCode == 'en' ? 'Fish' : 'Poissons'),
                isActive: _currentIndex == 1,
                onTap: () => navigateTo(1),
              ),
              _NavMapButton(
                onTap: () => navigateTo(3),
              ),
              _NavItem(
                icon: Icons.add_location_alt_rounded,
                label: LanguageController.instance.isRtl ? 'إضافة' : (LanguageController.instance.langCode == 'en' ? 'Add' : 'Ajouter'),
                isActive: _currentIndex == 2,
                onTap: () => navigateTo(2),
              ),
              _NavItem(
                icon: Icons.settings_rounded,
                label: LanguageController.instance.isRtl ? 'الإعدادات' : (LanguageController.instance.langCode == 'en' ? 'Settings' : 'Paramètres'),
                isActive: _currentIndex == 4,
                onTap: () => navigateTo(4),
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

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              style: TextStyle(
                color: isActive ? tc.oceanLight : tc.textMuted,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavMapButton extends StatelessWidget {
  final VoidCallback onTap;

  const _NavMapButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tc.oceanMedium, tc.oceanDeep],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: tc.oceanDeep.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.map_rounded,
          color: ThemeColors.of(context).textPrimary,
          size: 28,
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
      onNavigateToPremium: () => _goTo(context, const PremiumPage()),
      onNavigateToTides: () => _goTo(context, const TidePage()),
      // Debug route / bouton caché : long-press sur "Marées" dans le drawer
      onNavigateToTidesV2: () => _goTo(context, const WindguruPage(spotId: 'casablanca_maroc')),
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
