import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spots_app/services/auth_service.dart';
import 'package:spots_app/providers/premium_provider.dart';

class AuthPromptModal extends StatelessWidget {
  const AuthPromptModal({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AuthPromptModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).colorScheme;
    final textColor = tc.onSurface;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: tc.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tc.outline.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.lock_outline, size: 56, color: tc.primary),
            const SizedBox(height: 16),
            Text(
              'Authentification requise',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Connectez-vous pour débloquer le zoom 16X et bénéficier de 30 jours d\'essai gratuits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.75),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            Consumer<AuthService>(
              builder: (ctx, auth, _) {
                if (auth.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final canSignIn = !kIsWeb;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canSignIn
                        ? () async {
                            final ok = await auth.signInWithGoogle();
                            if (ok && auth.uid != null && ctx.mounted) {
                              await ctx.read<PremiumProvider>().init(auth.uid!);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            }
                          }
                        : null,
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      width: 24,
                      height: 24,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.login, size: 24),
                    ),
                    label: const Text(
                      'Continuer avec Google',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tc.primary,
                      foregroundColor: tc.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Continuer sans compte',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
