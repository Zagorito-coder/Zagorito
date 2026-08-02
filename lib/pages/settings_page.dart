// ============================================================
//  settings_page.dart — Page Paramètres / Command Center
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/widgets/app_back_button.dart';
import 'package:spots_app/widgets/boosterfish_page.dart';
import 'package:spots_app/services/ad_service.dart';
import 'package:spots_app/services/auth_service.dart';
import 'package:spots_app/features/community/services/community_repository.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final tc = BoosterFishPagePalette.of(context);

        return BoosterFishPageShell(
          child: CustomScrollView(
            key: const ValueKey('settings-scroll-view'),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHero(context, tc)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                sliver: SliverList.list(
                  children: [
                    _buildAccountSection(context, tc),
                    const SizedBox(height: 12),
                    _buildSectionHeading(
                      context,
                      tc,
                      Icons.shield_outlined,
                      context.tr('settings.privacySection'),
                    ),
                    const SizedBox(height: 7),
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
                        _SettingsRow(
                          icon: Icons.info_outline_rounded,
                          iconColor: tc.oceanLight,
                          title: context.tr('settings.openSourceLicenses'),
                          subtitle:
                              context.tr('settings.openSourceLicensesSubtitle'),
                          onTap: () => showLicensePage(
                            context: context,
                            applicationName: 'BoosterFish',
                            applicationVersion: '1.0.6',
                            applicationLegalese: '© 2026 BoosterFish',
                          ),
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
                    const SizedBox(height: 12),
                    _buildSectionHeading(
                      context,
                      tc,
                      Icons.sailing_outlined,
                      context.tr('settings.vesselCrew'),
                    ),
                    const SizedBox(height: 7),
                    _SettingsGroup(
                      children: [
                        _PublicProfileSettingsRow(
                          key: ValueKey(
                            'public-profile-${context.watch<AuthService>().uid ?? 'guest'}',
                          ),
                          onOpen: () => _showEditProfileDialog(context, tc),
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
                    const SizedBox(height: 12),
                    _GoodFishingBanner(
                      title: context.tr('settings.goodFishingTitle'),
                      subtitle: context.tr('settings.goodFishingSubtitle'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHero(BuildContext context, BoosterFishPagePalette tc) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return SizedBox(
      height: 125 + (textScale - 1) * 38,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF071A3A)),
          Image.asset(
            'assets/settings_hero.webp',
            fit: BoxFit.cover,
            cacheWidth: (MediaQuery.sizeOf(context).width *
                    MediaQuery.devicePixelRatioOf(context))
                .clamp(480, 1080)
                .round(),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xCC071A3A),
                    tc.navy.withValues(alpha: 0.58),
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
    BoosterFishPagePalette tc,
    IconData icon,
    String title,
  ) {
    return Row(
      children: [
        Icon(icon, color: tc.accent, size: 18),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: tc.accent,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context, BoosterFishPagePalette tc) {
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
                colors: [tc.navy, const Color(0xFF0A3562)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: tc.accent.withValues(alpha: 0.18),
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
    final tc = BoosterFishPagePalette.of(context);
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
    final tc = BoosterFishPagePalette.of(context);
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

  Future<bool> _showEditProfileDialog(
      BuildContext context, BoosterFishPagePalette tc) async {
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('settings.profileSignInRequired'))),
      );
      return false;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PublicProfileSheet(),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('settings.publicIdentitySaved'))),
      );
    }
    return saved == true;
  }
}

class _PublicProfileSettingsRow extends StatefulWidget {
  const _PublicProfileSettingsRow({
    super.key,
    required this.onOpen,
  });

  final Future<bool> Function() onOpen;

  @override
  State<_PublicProfileSettingsRow> createState() =>
      _PublicProfileSettingsRowState();
}

class _PublicProfileSettingsRowState extends State<_PublicProfileSettingsRow> {
  bool _showUpdateHint = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPreference();
  }

  Future<void> _loadSavedPreference() async {
    if (!context.read<AuthService>().isLoggedIn) return;
    try {
      final profile = await CommunityRepository.instance.loadPublicProfile();
      if (!mounted) return;
      setState(() => _showUpdateHint = !profile.hasSavedPreference);
    } catch (_) {
      // En cas de panne réseau, l'indicateur reste visible et le profil
      // demeure accessible. Aucune erreur de chargement ne bloque Paramètres.
    }
  }

  Future<void> _openProfile() async {
    final saved = await widget.onOpen();
    if (saved && mounted) {
      setState(() => _showUpdateHint = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = BoosterFishPagePalette.of(context);
    return _SettingsRow(
      icon: Icons.person,
      iconColor: tc.success,
      title: context.tr('settings.profile'),
      subtitle: context.tr('settings.profileSubtitle'),
      trailing: _showUpdateHint
          ? _UpdatePill(
              text: context.tr('settings.updateCredentials'),
            )
          : null,
      onTap: _openProfile,
    );
  }
}

class _PublicProfileSheet extends StatefulWidget {
  const _PublicProfileSheet();

  @override
  State<_PublicProfileSheet> createState() => _PublicProfileSheetState();
}

class _PublicProfileSheetState extends State<_PublicProfileSheet> {
  final _nicknameController = TextEditingController();
  bool _anonymous = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final auth = context.read<AuthService>();
    final fallback = auth.displayName?.trim() ?? '';
    try {
      final profile = await CommunityRepository.instance.loadPublicProfile();
      if (!mounted) return;
      _nicknameController.text = profile.publicDisplayName.isNotEmpty
          ? profile.publicDisplayName
          : fallback;
      setState(() {
        _anonymous = profile.publishAnonymously;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      _nicknameController.text = fallback;
      setState(() {
        _loading = false;
        _error = context.tr('settings.publicIdentityLoadError');
      });
    }
  }

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();
    if (!_anonymous && (nickname.length < 2 || nickname.length > 40)) {
      setState(() {
        _error = context.tr('settings.publicIdentityNicknameError');
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await CommunityRepository.instance.savePublicProfile(
        publishAnonymously: _anonymous,
        publicDisplayName: nickname,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.tr('settings.publicIdentitySaveError');
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = BoosterFishPagePalette.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 10,
          right: 10,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 10,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.98),
              borderRadius: const BorderRadius.all(Radius.circular(28)),
              border: Border.all(color: tc.accent.withValues(alpha: 0.42)),
              boxShadow: [
                BoxShadow(
                  color: tc.accent.withValues(alpha: 0.16),
                  blurRadius: 30,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tc.textMuted.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [tc.oceanMedium, tc.oceanDeep],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tc.accent.withValues(alpha: 0.3),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.public_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('settings.publicIdentityTitle'),
                              style: TextStyle(
                                color: tc.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.tr('settings.publicIdentitySubtitle'),
                              style: TextStyle(
                                color: tc.textSecondary,
                                fontSize: 11,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _IdentityChoice(
                      icon: Icons.visibility_off_rounded,
                      title: context.tr('settings.publicIdentityAnonymous'),
                      selected: _anonymous,
                      onTap: () => setState(() {
                        _anonymous = true;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _IdentityChoice(
                      icon: Icons.badge_outlined,
                      title: context.tr('settings.publicIdentityNickname'),
                      selected: !_anonymous,
                      onTap: () => setState(() {
                        _anonymous = false;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _anonymous
                          ? _PublicPreview(
                              key: const ValueKey('anonymous-preview'),
                              name: CommunityRepository.anonymousDisplayName,
                              tc: tc,
                            )
                          : TextField(
                              key: const ValueKey('nickname-field'),
                              controller: _nicknameController,
                              enabled: !_saving,
                              maxLength: 40,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: context
                                    .tr('settings.publicIdentityNickname'),
                                hintText: context
                                    .tr('settings.publicIdentityNicknameHint'),
                                filled: true,
                                fillColor: tc.surfaceElevated,
                                counterText: '',
                                prefixIcon: Icon(Icons.alternate_email_rounded,
                                    color: tc.accent),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                    ),
                    if (!_anonymous) ...[
                      const SizedBox(height: 10),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _nicknameController,
                        builder: (context, value, _) => _PublicPreview(
                          name: value.text.trim().isEmpty
                              ? context.tr('settings.userFallback')
                              : value.text.trim(),
                          tc: tc,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: TextStyle(color: tc.error, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(context.tr('settings.publicIdentitySave')),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: tc.oceanMedium,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityChoice extends StatelessWidget {
  const _IdentityChoice({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tc = BoosterFishPagePalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? tc.accent.withValues(alpha: 0.12)
                : tc.surfaceElevated.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? tc.accent : tc.borderStrong,
              width: selected ? 1.2 : 0.7,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: selected ? tc.accent : tc.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? tc.accent : tc.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicPreview extends StatelessWidget {
  const _PublicPreview({super.key, required this.name, required this.tc});

  final String name;
  final BoosterFishPagePalette tc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tc.navy.withValues(alpha: tc.isDark ? 0.7 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.preview_rounded, color: tc.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${context.tr('settings.publicIdentityPreview')}: $name',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tc.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandAccountCard extends StatelessWidget {
  final Widget child;

  const _CommandAccountCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final tc = BoosterFishPagePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [tc.navy, const Color(0xFF0A3562)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: tc.accent.withValues(alpha: 0.18),
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
    final tc = BoosterFishPagePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tc.surface.withValues(alpha: tc.isDark ? 0.96 : 0.98),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              tc.isDark ? tc.accent.withValues(alpha: 0.34) : tc.borderStrong,
        ),
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
    final tc = BoosterFishPagePalette.of(context);
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: title,
      hint: subtitle,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      maxLines: 3,
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
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tc.textSecondary,
                        fontSize: 12,
                        height: 1.25,
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
    final tc = BoosterFishPagePalette.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 100, minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: tc.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.success.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: tc.success,
          fontSize: 10,
          height: 1.2,
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
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 64 + (textScale - 1) * 28,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/settings_fishing_banner.webp',
              fit: BoxFit.cover,
              cacheWidth: (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .clamp(480, 1080)
                  .round(),
            ),
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
                            fontSize: 11,
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
          iconColor: BoosterFishPagePalette.of(context).oceanLight,
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
