// ============================================================
//  settings_page.dart — Page Paramètres / Command Center
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/widgets/app_back_button.dart';
import 'package:spots_app/services/auth_service.dart';
import 'package:spots_app/providers/premium_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                    // ── Header ──
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
                        Consumer<AuthService>(
                          builder: (ctx, auth, _) => IconButton(
                            tooltip: 'Déconnexion',
                            icon: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: auth.isLoggedIn
                                    ? Colors.red.withValues(alpha: 0.10)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.logout,
                                color: auth.isLoggedIn ? Colors.redAccent : tc.textMuted,
                                size: 20,
                              ),
                            ),
                            onPressed: auth.isLoggedIn
                                ? () => _confirmLogout(context, auth)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // ── Compte : Google Sign-In ──
                    _buildAccountSection(context, tc),

                    const SizedBox(height: 30),
                    Text(
                      'Mode test',
                      style: AppTextStyles.labelMedium(context).copyWith(letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Consumer<PremiumProvider>(
                      builder: (ctx, provider, _) => _SettingsMenuCard(
                        icon: Icons.admin_panel_settings,
                        iconColor: tc.gold,
                        title: 'Forcer le mode Premium',
                        subtitle: provider.isForcePremium
                            ? 'Zoom 16x activé manuellement'
                            : 'Zoom limité par l\'abonnement',
                        trailingWidget: Switch(
                          value: provider.isForcePremium,
                          onChanged: (_) => provider.toggleForcePremium(),
                          activeThumbColor: tc.gold,
                        ),
                        onTap: null,
                      ),
                    ),

                    const SizedBox(height: 30),
                    // ── Section Confidentialité ──
                    Text(
                      'Confidentialité',
                      style: AppTextStyles.labelMedium(context).copyWith(letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 12),
                    _SettingsMenuCard(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: tc.success,
                      title: context.tr('settings.privacyPolicy'),
                      subtitle: context.tr('settings.privacyPolicySubtitle'),
                      onTap: () => _openPrivacyPolicy(context),
                    ),
                    const SizedBox(height: 12),
                    _SettingsMenuCard(
                      icon: Icons.description_outlined,
                      iconColor: tc.textSecondary,
                      title: 'CGU',
                      subtitle: 'Conditions Générales d\'Utilisation',
                      onTap: () => _openTermsOfService(context),
                    ),
                    if (context.watch<AuthService>().isLoggedIn) ...[
                      const SizedBox(height: 12),
                      _SettingsMenuCard(
                        icon: Icons.delete_forever,
                        iconColor: Colors.redAccent,
                        title: context.tr('settings.deleteAccount'),
                        subtitle: 'Supprime définitivement ton compte et toutes tes données',
                        onTap: () => _confirmDeleteAccount(context),
                      ),
                    ],

                    const SizedBox(height: 30),
                    Text(
                      context.tr('settings.vesselCrew'),
                      style: AppTextStyles.labelMedium(context).copyWith(letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 16),

                    // ── Menu items ──
                    _SettingsMenuCard(
                      icon: Icons.person,
                      iconColor: tc.success,
                      title: context.tr('settings.profile'),
                      subtitle: context.tr('settings.profileSubtitle'),
                      trailing: context.tr('settings.updateCredentials'),
                      onTap: () => _showEditProfileDialog(context, tc),
                    ),
                    const SizedBox(height: 12),
                    _SettingsMenuCard(
                      icon: Icons.anchor,
                      iconColor: tc.oceanLight,
                      title: context.tr('settings.mySpots'),
                      subtitle: context.tr('settings.mySpotsSubtitle'),
                      onTap: () => _showComingSoon(context, 'Mes Spots'),
                    ),
                    const SizedBox(height: 12),
                    _SettingsMenuCard(
                      icon: Icons.people,
                      iconColor: tc.success,
                      title: context.tr('settings.crewManagement'),
                      subtitle: context.tr('settings.crewManagementSubtitle'),
                      onTap: () => _showComingSoon(context, 'Gestion équipage'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, ThemeColors tc) {
    return Consumer<AuthService>(
      builder: (ctx, auth, _) {
        if (auth.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (auth.isLoggedIn) {
          // ── Connecté ──
          return Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundImage: auth.photoUrl != null
                    ? NetworkImage(auth.photoUrl!)
                    : null,
                child: auth.photoUrl == null
                    ? const Icon(Icons.person, size: 32)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.displayName ?? 'Utilisateur',
                      style: AppTextStyles.headlineSmall(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      auth.email ?? '',
                      style: AppTextStyles.bodyMedium(context),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.verified, color: tc.gold, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('settings.member'),
                          style: AppTextStyles.labelMedium(context).copyWith(color: tc.gold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // ── Non connecté : bouton Google (désactivé sur web) ──
        final canSignIn = !kIsWeb && !auth.isLoading;
        return GestureDetector(
          onTap: canSignIn ? () async {
            final auth = context.read<AuthService>();
            final ok = await auth.signInWithGoogle();
            if (ok && auth.uid != null && context.mounted) {
              await context.read<PremiumProvider>().init(auth.uid!);
            } else if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('settings.signInFailed'))),
              );
            }
          } : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(24, 24),
                      painter: _GoogleLogoPainter(),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('settings.signInGoogle'),
                        style: AppTextStyles.titleLarge(context)
                            .copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.tr('settings.signInGoogleSubtitle'),
                        style: AppTextStyles.labelMedium(context)
                            .copyWith(color: const Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey[400], size: 22),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context, AuthService auth) {
    final tc = ThemeColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surface,
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
              auth.signOut();
            },
            child: Text(context.tr('common.confirm'), style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — bientôt disponible')),
    );
  }

  Future<void> _openTermsOfService(BuildContext context) async {
    const url = 'https://zagorito-coder.github.io/boosterfish/terms-of-service/';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le lien')),
        );
      }
    }
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    const url = 'https://zagorito-coder.github.io/boosterfish/privacy-policy/';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le lien')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final tc = ThemeColors.of(context);
    final auth = context.read<AuthService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surface,
        title: Text(context.tr('settings.deleteAccount')),
        content: Text(context.tr('settings.deleteAccountConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.tr('common.confirm'),
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await auth.deleteAccount();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? context.tr('settings.deleteAccountSuccess')
                  : context.tr('settings.deleteAccountError'),
            ),
          ),
        );
      }
    }
  }

  void _showEditProfileDialog(BuildContext context, ThemeColors tc) {
    final auth = context.read<AuthService>();
    final nameCtrl = TextEditingController(text: auth.displayName ?? '');
    final email = auth.email ?? '';
    final photoUrl = auth.photoUrl;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surface,
        title: const Text('Modifier le profil'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? const Icon(Icons.person, size: 40) : null,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nom',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 12),
          Text(email, style: TextStyle(color: tc.textMuted, fontSize: 13)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }
}

class _SettingsMenuCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? trailing;
  final Widget? trailingWidget;
  final VoidCallback? onTap;

  const _SettingsMenuCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.trailingWidget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tc.divider),
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
                  Text(title,
                    style: AppTextStyles.titleLarge(context).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.labelMedium(context)),
                ],
              ),
            ),
            if (trailingWidget != null)
              trailingWidget!
            else if (trailing != null)
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tc.glassBorder, style: BorderStyle.solid),
                ),
                child: Center(
                  child: Text(trailing!,
                    style: TextStyle(color: tc.textMuted, fontSize: 10, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    // Bleu — arc droit
    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(
      Path()
        ..moveTo(w, h * 0.5)
        ..cubicTo(w, h * 0.23, w * 0.78, 0, w * 0.5, 0)
        ..lineTo(w * 0.5, h * 0.27)
        ..cubicTo(w * 0.63, h * 0.27, w * 0.73, h * 0.37, w * 0.73, h * 0.5)
        ..close(),
      paint,
    );
    // Vert — arc bas
    paint.color = const Color(0xFF34A853);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h)
        ..cubicTo(w * 0.78, h, w, h * 0.77, w, h * 0.5)
        ..lineTo(w * 0.73, h * 0.5)
        ..cubicTo(w * 0.73, h * 0.63, w * 0.63, h * 0.73, w * 0.5, h * 0.73)
        ..close(),
      paint,
    );
    // Jaune — arc gauche bas
    paint.color = const Color(0xFFFBBC05);
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.5)
        ..cubicTo(0, h * 0.77, w * 0.22, h, w * 0.5, h)
        ..lineTo(w * 0.5, h * 0.73)
        ..cubicTo(w * 0.37, h * 0.73, w * 0.27, h * 0.63, w * 0.27, h * 0.5)
        ..close(),
      paint,
    );
    // Rouge — arc gauche haut
    paint.color = const Color(0xFFEA4335);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, 0)
        ..cubicTo(w * 0.22, 0, 0, h * 0.23, 0, h * 0.5)
        ..lineTo(w * 0.27, h * 0.5)
        ..cubicTo(w * 0.27, h * 0.37, w * 0.37, h * 0.27, w * 0.5, h * 0.27)
        ..close(),
      paint,
    );
    // Centre blanc
    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.18,
      paint,
    );
    // Barre horizontale bleue (partie droite)
    paint.color = const Color(0xFF4285F4);
    canvas.drawRRect(
      RRect.fromLTRBR(
        w * 0.5, h * 0.41,
        w * 0.96, h * 0.59,
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}