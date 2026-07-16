// ============================================================
//  drawer.dart — Navigation latérale réutilisable
// ============================================================

import 'package:flutter/material.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/l10n/app_localizations.dart';

/// Drawer de navigation global pour toutes les pages
class AppDrawer extends StatelessWidget {
  final String? currentRoute;
  final VoidCallback? onHomeTap;
  final VoidCallback? onTechniquesTap;
  final VoidCallback? onCommunityTap;
  final VoidCallback? onShopsTap;
  final VoidCallback? onPremiumTap;

  const AppDrawer({
    super.key,
    this.currentRoute,
    this.onHomeTap,
    this.onTechniquesTap,
    this.onCommunityTap,
    this.onShopsTap,
    this.onPremiumTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final tc = ThemeColors.of(context);
        return Drawer(
      backgroundColor: tc.background,
      child: SafeArea(
        child: Column(
          children: [
            // Header du drawer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: tc.surface),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [tc.oceanMedium, tc.oceanDeep],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.phishing,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('drawer.title'),
                          style: TextStyle(
                            color: tc.oceanLight,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('drawer.subtitle'),
                          style: TextStyle(
                            color: tc.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Items de navigation
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (onHomeTap != null)
                    _DrawerItem(
                      icon: Icons.home_rounded,
                      label: context.tr('drawer.home'),
                      isActive: currentRoute == 'home',
                      onTap: () {
                        Navigator.of(context).pop();
                        onHomeTap!();
                      },
                    ),
                  if (onTechniquesTap != null)
                    _DrawerItem(
                      icon: Icons.menu_book_rounded,
                      label: context.tr('drawer.techniques'),
                      isActive: currentRoute == 'techniques',
                      onTap: () {
                        Navigator.of(context).pop();
                        onTechniquesTap!();
                      },
                    ),
                  if (onCommunityTap != null)
                    _DrawerItem(
                      icon: Icons.people_alt_rounded,
                      label: context.tr('drawer.community'),
                      isActive: currentRoute == 'community',
                      onTap: () {
                        Navigator.of(context).pop();
                        onCommunityTap!();
                      },
                    ),
                  if (onShopsTap != null)
                    _DrawerItem(
                      icon: Icons.store_rounded,
                      label: context.tr('drawer.shops'),
                      isActive: currentRoute == 'shops',
                      onTap: () {
                        Navigator.of(context).pop();
                        onShopsTap!();
                      },
                    ),
                  if (onPremiumTap != null)
                    _DrawerItem(
                      icon: Icons.workspace_premium,
                      label: context.tr('drawer.premium'),
                      isActive: currentRoute == 'premium',
                      onTap: () {
                        Navigator.of(context).pop();
                        onPremiumTap!();
                      },
                    ),
                ],
              ),
            ),
            // Footer du drawer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tc.surface,
                border: Border(
                  top: BorderSide(color: tc.glassBorder, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.water_drop,
                    size: 16,
                    color: tc.oceanMedium.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('app.version'),
                    style: TextStyle(
                      color: tc.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
);
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive
              ? tc.oceanMedium.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isActive ? tc.oceanLight : tc.textSecondary,
          size: 20,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? tc.textPrimary : tc.textSecondary,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      trailing: isActive
          ? Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: tc.oceanLight,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          : null,
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}
