// ============================================================
//  settings_page.dart — Page Paramètres / Command Center
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/widgets/app_back_button.dart';
import 'package:spots_app/services/ad_service.dart';
import 'package:spots_app/services/auth_service.dart';
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
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHero(context, tc)),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAccountSection(context, tc),
                    _buildSectionHeading(
                      context,
                      tc,
                      Icons.shield_outlined,
                      context.tr('settings.privacySection'),
                    ),
                    _SettingsGroup(
                      children: [
                        _SettingsRow(
                          icon: Icons.privacy_tip_outlined,
                          iconColor: tc.success,
                          title: context.tr('settings.privacyPolicy'),
                          subtitle:
                              context.tr('settings.privacyPolicySubtitle'),
                          onTap: () => _openPrivacyPolicy(context),
                        ),
                        _SettingsRow(
                          icon: Icons.description_outlined,
                          iconColor: tc.textSecondary,
                          title: context.tr('settings.termsOfService'),
                          subtitle:
                              context.tr('settings.termsOfServiceSubtitle'),
                          onTap: () => _openTermsOfService(context),
                        ),
                        const _AdvertisingPrivacyEntry(),
                        if (context.watch<AuthService>().isLoggedIn)
                          _SettingsRow(
                            icon: Icons.delete_forever,
                            iconColor: tc.error,
                            title: context.tr('settings.deleteAccount'),
                            subtitle:
                                context.tr('settings.deleteAccountSubtitle'),
                            onTap: () => _confirmDeleteAccount(context),
                          ),
                      ],
                    ),
                    _buildSectionHeading(
                      context,
                      tc,
                      Icons.sailing_outlined,
                      context.tr('settings.vesselCrew'),
                    ),
                    _SettingsGroup(
                      children: [
                        _SettingsRow(
                          icon: Icons.person,
                          iconColor: tc.success,
                          title: context.tr('settings.profile'),
                          subtitle: context.tr('settings.profileSubtitle'),
                          trailing: _UpdatePill(
                            text: context.tr('settings.updateCredentials'),
                          ),
                          onTap: () => _showEditProfileDialog(context, tc),
                        ),
                        _SettingsRow(
                          icon: Icons.anchor,
                          iconColor: tc.oceanLight,
                          title: context.tr('settings.mySpots'),
                          subtitle: context.tr('settings.mySpotsSubtitle'),
                          onTap: () => _showComingSoon(
                              context, context.tr('settings.mySpots')),
                        ),
                        _SettingsRow(
                          icon: Icons.people,
                          iconColor: const Color(0xFF7C3AED),
                          title: context.tr('settings.crewManagement'),
                          subtitle:
                              context.tr('settings.crewManagementSubtitle'),
                          onTap: () => _showComingSoon(
                              context, context.tr('settings.crewManagement')),
                        ),
                      ],
                    ),
                    _GoodFishingBanner(
                      title: context.tr('settings.goodFishingTitle'),
                      subtitle: context.tr('settings.goodFishingSubtitle'),
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

  Widget _buildHero(BuildContext context, ThemeColors tc) {
    return SizedBox(
      height: 125,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF071A3A)),
          Image.asset('assets/settings_hero.png', fit: BoxFit.cover),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xCC071A3A),
                    tc.oceanDeep.withValues(alpha: 0.58),
                    const Color(0xAA073B63),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AppBackButton(toHome: true, color: Colors.white),
                    Consumer<AuthService>(
                      builder: (ctx, auth, _) => IconButton(
                        tooltip: context.tr('drawer.logout'),
                        onPressed: auth.isLoggedIn
                            ? () => _confirmLogout(context, auth)
                            : null,
                        icon: Icon(
                          Icons.logout_rounded,
                          color: auth.isLoggedIn
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  context.tr('settings.title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr('settings.subtitle'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 42,
                  height: 3,
                  decoration: BoxDecoration(
                    color: tc.oceanLight,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(
    BuildContext context,
    ThemeColors tc,
    IconData icon,
    String title,
  ) {
    return Row(
      children: [
        Icon(icon, color: tc.oceanDeep, size: 18),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: tc.oceanDeep,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
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
          return _CommandAccountCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
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
                        (auth.displayName?.isNotEmpty ?? false)
                            ? auth.displayName!
                            : context.tr('settings.userFallback'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        auth.email ?? '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.verified, color: tc.gold, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('settings.member'),
                            style: TextStyle(
                              color: tc.gold,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white, size: 22),
              ],
            ),
          );
        }

        // ── Non connecté : bouton Google (désactivé sur web) ──
        final canSignIn = !kIsWeb && !auth.isLoading;
        return GestureDetector(
          onTap: canSignIn
              ? () async {
                  final auth = context.read<AuthService>();
                  final ok = await auth.signInWithGoogle();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.tr(_signInFailureKey(auth.lastSignInFailure)),
                        ),
                      ),
                    );
                  }
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [tc.oceanDeep, const Color(0xFF0A3562)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: tc.oceanDeep.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(20, 20),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.tr('settings.signInGoogleSubtitle'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white, size: 22),
              ],
            ),
          ),
        );
      },
    );
  }

  String _signInFailureKey(SignInFailure? failure) {
    switch (failure) {
      case SignInFailure.interrupted:
        return 'settings.signInInterrupted';
      case SignInFailure.googleClientConfiguration:
      case SignInFailure.googleProviderConfiguration:
      case SignInFailure.missingIdToken:
        return 'settings.signInConfigurationError';
      case SignInFailure.uiUnavailable:
        return 'settings.signInUnavailable';
      case SignInFailure.network:
        return 'settings.signInNetworkError';
      case SignInFailure.providerDisabled:
        return 'settings.signInProviderDisabled';
      case SignInFailure.credentialRejected:
        return 'settings.signInCredentialRejected';
      case SignInFailure.userDisabled:
        return 'settings.signInUserDisabled';
      case SignInFailure.tooManyRequests:
        return 'settings.signInTooManyRequests';
      case SignInFailure.canceled:
        return 'settings.signInCanceled';
      case SignInFailure.firebase:
      case SignInFailure.unexpected:
      case null:
        return 'settings.signInFailed';
    }
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
            child: Text(context.tr('common.confirm'),
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.trArgs('settings.comingSoon', args: {'feature': feature}),
        ),
      ),
    );
  }

  Future<void> _openTermsOfService(BuildContext context) async {
    const url =
        'https://zagorito-coder.github.io/boosterfish/terms-of-service/';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('settings.linkOpenError'))),
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
          SnackBar(content: Text(context.tr('settings.linkOpenError'))),
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
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
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

  Future<void> _showEditProfileDialog(
      BuildContext context, ThemeColors tc) async {
    final auth = context.read<AuthService>();
    final nameCtrl = TextEditingController(text: auth.displayName ?? '');
    final email = auth.email ?? '';
    final photoUrl = auth.photoUrl;
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: tc.surface,
          title: Text(context.tr('settings.editProfile')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child:
                  photoUrl == null ? const Icon(Icons.person, size: 40) : null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: context.tr('settings.name'),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            Text(email, style: TextStyle(color: tc.textMuted, fontSize: 13)),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('common.close'))),
          ],
        ),
      );
    } finally {
      nameCtrl.dispose();
    }
  }
}

class _CommandAccountCard extends StatelessWidget {
  final Widget child;

  const _CommandAccountCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [tc.oceanDeep, const Color(0xFF0A3562)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: tc.oceanDeep.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: tc.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                      height: 1, indent: 78, endIndent: 20, color: tc.divider),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: title,
      hint: subtitle,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tc.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tc.textSecondary,
                        fontSize: 10,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              trailing ??
                  Icon(Icons.chevron_right_rounded,
                      color: tc.textSecondary, size: 21),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdatePill extends StatelessWidget {
  final String text;

  const _UpdatePill({required this.text});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: tc.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.success.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: tc.success,
          fontSize: 8,
          height: 1.15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GoodFishingBanner extends StatelessWidget {
  final String title;
  final String subtitle;

  const _GoodFishingBanner({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 58,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/settings_fishing_banner.png',
                fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xF20A315E),
                    const Color(0x990A315E),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28)),
                    ),
                    child: const Icon(Icons.phishing,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 9,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.24)),
                    ),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Google impose un accès aux options de confidentialité uniquement lorsque
/// UMP retourne le statut `required`.
class _AdvertisingPrivacyEntry extends StatefulWidget {
  const _AdvertisingPrivacyEntry();

  @override
  State<_AdvertisingPrivacyEntry> createState() =>
      _AdvertisingPrivacyEntryState();
}

class _AdvertisingPrivacyEntryState extends State<_AdvertisingPrivacyEntry> {
  Future<bool>? _isRequired;

  @override
  void initState() {
    super.initState();
    // SettingsPage est construit même lorsqu'il est masqué par le shell.
    // Attendre le premier frame garantit que AppShell a d'abord attaché
    // l'activité et lancé l'initialisation UMP.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isRequired = AdService.instance.isPrivacyOptionsRequired();
      });
    });
  }

  Future<void> _openPrivacyOptions() async {
    final updated = await AdService.instance.showPrivacyOptionsForm();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            updated ? 'settings.adPrivacyUpdated' : 'settings.adPrivacyError',
          ),
        ),
      ),
    );

    setState(() {
      _isRequired = AdService.instance.isPrivacyOptionsRequired();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRequired = _isRequired;
    if (isRequired == null) return const SizedBox.shrink();
    return FutureBuilder<bool>(
      future: isRequired,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return _SettingsRow(
          icon: Icons.ads_click_outlined,
          iconColor: ThemeColors.of(context).oceanLight,
          title: context.tr('settings.adPrivacy'),
          subtitle: context.tr('settings.adPrivacySubtitle'),
          onTap: _openPrivacyOptions,
        );
      },
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
        w * 0.5,
        h * 0.41,
        w * 0.96,
        h * 0.59,
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
