// ============================================================
//  premium_page.dart — Page Premium Hub
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spots_app/services/auth_service.dart';
import 'package:spots_app/services/subscription_service.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/widgets/app_back_button.dart';

class PremiumPage extends StatelessWidget {
  const PremiumPage({super.key});

  Future<void> _activate(BuildContext context, Future<void> Function(String) activate) async {
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final loc = context.tr;

    if (!auth.isLoggedIn || auth.uid == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(loc('premium.loginRequired'))),
      );
      return;
    }

    try {
      await activate(auth.uid!);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(loc('premium.activated'))),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${loc('premium.activationError')}: $e')),
      );
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
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const AppBackButton(),
                        const SizedBox(height: 28),
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
                            const SizedBox(width: 12),
                            _PremiumBadge(
                              icon: Icons.bar_chart,
                              label: context.tr('premium.level'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        _PlanCard(
                          title: context.tr('premium.monthly'),
                          price: context.tr('premium.monthlyPrice'),
                          icon: Icons.calendar_month,
                          onActivate: () => _activate(context, SubscriptionService.activateMonthly),
                        ),
                        const SizedBox(height: 16),
                        _PlanCard(
                          title: context.tr('premium.annual'),
                          price: context.tr('premium.annualPrice'),
                          icon: Icons.event_repeat,
                          isPopular: true,
                          onActivate: () => _activate(context, SubscriptionService.activateAnnual),
                        ),
                        const SizedBox(height: 16),
                        _PlanCard(
                          title: context.tr('premium.lifetime'),
                          price: context.tr('premium.lifetimePrice'),
                          icon: Icons.all_inclusive,
                          onActivate: () => _activate(context, SubscriptionService.activateLifetime),
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

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final IconData icon;
  final bool isPopular;
  final VoidCallback onActivate;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.icon,
    this.isPopular = false,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPopular ? tc.gold.withValues(alpha: 0.6) : tc.glassBorder,
          width: isPopular ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: tc.shadowColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tc.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                context.tr('premium.popular'),
                style: TextStyle(
                  color: tc.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (isPopular) const SizedBox(height: 12),
          Row(
            children: [
              Icon(icon, color: tc.oceanLight, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: tc.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      price,
                      style: TextStyle(
                        color: tc.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onActivate,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPopular ? tc.gold : tc.oceanMedium,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                context.tr('premium.activate'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
