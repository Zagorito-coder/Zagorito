import 'package:flutter/material.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/widgets/app_back_button.dart';

/// Ancien point d'entrée conservé pour compatibilité avec d'éventuels liens
/// internes. L'application est désormais entièrement gratuite et financée par
/// la publicité ; aucun achat ou abonnement n'est proposé ici.
class PremiumPage extends StatelessWidget {
  const PremiumPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppBackButton(),
              const SizedBox(height: 32),
              Icon(Icons.check_circle_outline, color: tc.success, size: 48),
              const SizedBox(height: 16),
              Text(
                'Accès gratuit',
                style: AppTextStyles.headlineLarge(context),
              ),
              const SizedBox(height: 12),
              Text(
                'Toutes les fonctionnalités de l’application sont disponibles gratuitement. '
                'L’application est financée par la publicité.',
                style: AppTextStyles.bodyLarge(context),
              ),
              const SizedBox(height: 20),
              Text(
                context.tr('settings.privacyPolicySubtitle'),
                style: AppTextStyles.bodyMedium(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
