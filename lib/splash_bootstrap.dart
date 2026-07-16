// ============================================================
//  splash_bootstrap.dart — Écran de démarrage et initialisation
//  Initialise FMTC + charge les spots une seule fois avant AppShell
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spots_app/firebase_options.dart';
import 'package:spots_app/app_shell.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/providers/fish_provider.dart';
import 'package:spots_app/providers/premium_provider.dart';
import 'package:spots_app/services/spot_service.dart';
import 'package:spots_app/theme.dart';

class SplashBootstrap extends StatefulWidget {
  const SplashBootstrap({super.key});

  @override
  State<SplashBootstrap> createState() => _SplashBootstrapState();
}

class _SplashBootstrapState extends State<SplashBootstrap> {
  String _status = 'Initialisation…';
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
      _update('Initialisation Firebase…', 0.05);
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } catch (e) {
        debugPrint('[SplashBootstrap] Firebase error: $e');
      }

      _update('Initialisation du cache cartes…', 0.1);
      await FMTCObjectBoxBackend().initialise();
      for (final name in const ['osm', 'satellite', 'dark']) {
        final store = FMTCStore(name);
        if (!(await store.manage.ready)) {
          await store.manage.create();
        }
      }

      _update('Chargement des spots…', 0.4);
      List<Spot> spots;
      final cached = await SpotService.loadFromCache();
      if (cached.isNotEmpty) {
        spots = cached;
      } else {
        spots = await SpotService.loadFromCsv();
        if (spots.isNotEmpty) {
          await SpotService.saveToCache(spots);
        }
      }

      _update('Chargement des données…', 0.8);
      if (!mounted) return;
      final fishProvider = context.read<FishProvider>();
      await fishProvider.loadFishData();

      // Initialiser PremiumProvider si un utilisateur Firebase est déjà connecté
      // (session persistée après redémarrage).
      // On attend le premier événement authStateChanges pour garantir que
      // Firebase Auth a bien fini de restaurer la session interne.
      if (!mounted) return;
      final user = await FirebaseAuth.instance.authStateChanges().first;
      if (user != null && mounted) {
        _update('Restauration de la session…', 0.85);
        await context.read<PremiumProvider>().init(user.uid);
      }

      if (!mounted) return;

      _update('Prêt !', 1.0);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AppShell(key: appShellKey, initialSpots: spots)),
      );
    } catch (e, st) {
      debugPrint('[SplashBootstrap] ERREUR: $e\n$st');
      if (mounted) setState(() => _error = '$e');
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
                    Text(_status, style: TextStyle(color: tc.textSecondary, fontSize: 13)),
                  ] else ...[
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    const Text('Erreur de démarrage', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: tc.textSecondary, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _bootstrap,
                      child: const Text('Réessayer'),
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
