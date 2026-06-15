// ============================================================
//  premium_page.dart — Page Premium Hub
// ============================================================

import 'package:flutter/material.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/l10n/app_localizations.dart';

class PremiumPage extends StatelessWidget {
  const PremiumPage({super.key});

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
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: tc.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: tc.gold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        context.tr('premium.title'),
                        style: TextStyle(
                          color: tc.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('premium.elite'),
                      style: AppTextStyles.headlineLarge(context).copyWith(fontSize: 34),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PremiumBadge(
                          icon: Icons.military_tech,
                          label: context.tr('premium.rank'),
                        ),
                        SizedBox(width: 12),
                        _PremiumBadge(
                          icon: Icons.bar_chart,
                          label: context.tr('premium.level'),
                        ),
                      ],
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

class _PremiumBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PremiumBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: tc.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tc.success.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tc.success, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: tc.success.withValues(alpha: 0.92),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
