// ============================================================
//  splash_bootstrap.dart — Écran de démarrage et initialisation
//  Initialise Firebase + charge les spots une seule fois avant AppShell
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spots_app/firebase_options.dart';
import 'package:spots_app/app_shell.dart';
import 'package:spots_app/providers/fish_provider.dart';
import 'package:spots_app/providers/premium_provider.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/services/spot_service.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/l10n/app_localizations.dart';

class SplashBootstrap extends StatefulWidget {
  const SplashBootstrap({super.key});

  @override
  State<SplashBootstrap> createState() => _SplashBootstrapState();
}

class _SplashBootstrapState extends State<SplashBootstrap> {
  String _status = 'splash.initializingFirebase';
  double _progress = 0.05;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      _update('splash.initializingFirebase', 0.05);
      try {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      } catch (e) {
        debugPrint('[SplashBootstrap] Firebase error: $e');
        rethrow;
      }

      // App Check doit être activé immédiatement après Firebase.initializeApp
      // et avant toute utilisation d'Auth, Firestore ou Storage. L'enforcement
      // reste piloté depuis Firebase Console après validation des métriques.
      try {
        await _activateAppCheck();
      } catch (e, st) {
        // Une attestation indisponible ne doit pas empêcher le démarrage tant
        // que l'enforcement n'est pas activé. Les règles Firebase restent la
        // protection obligatoire des données.
        debugPrint('[SplashBootstrap] App Check activation error: $e\n$st');
      }

      _update('splash.loadingData', 0.3);
      if (!mounted) return;
      final fishProvider = context.read<FishProvider>();

      // Paralléliser spots + fish data (indépendants)
      final results = await Future.wait([
        SpotService.loadSpots(),
        fishProvider.loadFishData(),
      ]);
      final spots = results[0] as List<Spot>;

      if (!mounted) return;

      _update('splash.ready', 1.0);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => AppShell(key: appShellKey, initialSpots: spots)),
      );

      // Initialiser PremiumProvider en arriere-plan (non-bloquant)
      // pour ne pas retarder l'affichage de la carte.
      unawaited(_initPremiumInBackground());
    } catch (e, st) {
      debugPrint('[SplashBootstrap] ERREUR: $e\n$st');
      if (mounted) setState(() => _error = 'splash.startupErrorMessage');
    }
  }

  Future<void> _activateAppCheck() async {
    if (kIsWeb) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
      );
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await FirebaseAppCheck.instance.activate(
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
    }
  }

  Future<void> _initPremiumInBackground() async {
    try {
      // On attend le premier evenement authStateChanges pour garantir que
      // Firebase Auth a bien fini de restaurer la session interne.
      final user = await FirebaseAuth.instance.authStateChanges().first;
      if (user != null) {
        // Contexte accessible via appShellKey
        final ctx = appShellKey.currentContext;
        if (ctx != null && ctx.mounted) {
          // Resolve the provider before the await so no BuildContext is held
          // across the asynchronous initialization gap.
          final premiumProvider = ctx.read<PremiumProvider>();
          await premiumProvider.init(user.uid);
        }
      }
    } catch (e) {
      debugPrint('[SplashBootstrap] Premium init background error: $e');
    }
  }

  void _update(String status, double progress) {
    if (!mounted) return;
    setState(() {
      _status = status;
      _progress = progress.clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 100,
                    height: 100,
                  ),
                  const SizedBox(height: 24),
                  if (_error == null) ...[
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        value: _progress > 0.0 ? _progress : null,
                        backgroundColor: tc.surfaceLight,
                        color: tc.oceanLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(context.tr(_status),
                        style:
                            TextStyle(color: tc.textSecondary, fontSize: 13)),
                  ] else ...[
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(context.tr('splash.startupError'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Text(context.tr(_error!),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: tc.textSecondary, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _bootstrap,
                      child: Text(context.tr('splash.retry')),
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
