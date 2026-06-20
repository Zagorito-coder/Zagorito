// ============================================================
//  settings_page.dart — Page Paramètres / Command Center
// ============================================================

import 'package:flutter/material.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/widgets/app_back_button.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, child) {
        final tc = ThemeColors.of(context);

        return Scaffold(
          backgroundColor: tc.background,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        // Header
                        Row(
                          children: [
                            const AppBackButton(toHome: true),
                            const Spacer(),
                            Text(
                              context.tr('settings.title'),
                              style: AppTextStyles.labelLarge(context).copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(context.tr('drawer.logout')),
                                    content: Text(context.tr('settings.logoutConfirm')),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(),
                                        child: Text(context.tr('common.cancel')),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          Navigator.of(context).pop();
                                        },
                                        child: Text(context.tr('common.confirm'), style: const TextStyle(color: Colors.redAccent)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Profil
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tc.surfaceLight,
                                border: Border.all(
                                  color: tc.success.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  context.tr('settings.initials'),
                                  style: TextStyle(
                                    color: tc.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('settings.captainName'),
                                  style: AppTextStyles.headlineSmall(context),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.tr('settings.captainSubtitle'),
                                  style: AppTextStyles.bodyMedium(context),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      color: tc.gold,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.tr('settings.member'),
                                      style: AppTextStyles.labelMedium(context).copyWith(
                                        color: tc.gold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),
                        Text(
                          context.tr('settings.vesselCrew'),
                          style: AppTextStyles.labelMedium(context).copyWith(
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Menu items
                        _SettingsMenuCard(
                          icon: Icons.person,
                          iconColor: tc.success,
                          title: context.tr('settings.profile'),
                          subtitle: context.tr('settings.profileSubtitle'),
                          trailing: context.tr('settings.updateCredentials'),
                        ),
                        const SizedBox(height: 12),
                        _SettingsMenuCard(
                          icon: Icons.anchor,
                          iconColor: tc.oceanLight,
                          title: context.tr('settings.mySpots'),
                          subtitle: context.tr('settings.mySpotsSubtitle'),
                        ),
                        const SizedBox(height: 12),
                        _SettingsMenuCard(
                          icon: Icons.people,
                          iconColor: tc.success,
                          title: context.tr('settings.crewManagement'),
                          subtitle: context.tr('settings.crewManagementSubtitle'),
                        ),
                      ],
                    ),
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

class _SettingsMenuCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? trailing;

  const _SettingsMenuCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tc.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleLarge(context).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.labelMedium(context),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: tc.glassBorder,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Text(
                  trailing!,
                  style: TextStyle(
                    color: tc.textMuted,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
