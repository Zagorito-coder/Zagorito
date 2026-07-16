// ============================================================
//  auth_service.dart — Google Sign-In lié à Firebase Auth
//  Compatible google_sign_in ^7.2.0 (API singleton)
// ============================================================

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalUser {
  final String displayName;
  final String email;
  final String? photoUrl;
  const LocalUser({required this.displayName, required this.email, this.photoUrl});
}

class AuthService extends ChangeNotifier {
  LocalUser? _localUser;
  bool _isLoading = false;
  bool _initialized = false;

  LocalUser? get user => _localUser;
  bool get isLoggedIn => _localUser != null;
  bool get isLoading => _isLoading;
  String? get displayName => _localUser?.displayName;
  String? get email => _localUser?.email;
  String? get photoUrl => _localUser?.photoUrl;
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  AuthService() {
    debugPrint('[AuthService] Initialisé${kIsWeb ? ' (web)' : ' (android)'}');
    // Restaurer la session Firebase persistée au démarrage
    FirebaseAuth.instance.authStateChanges().listen((firebaseUser) {
      if (firebaseUser != null) {
        _localUser = LocalUser(
          displayName: firebaseUser.displayName ?? 'Utilisateur',
          email: firebaseUser.email ?? '',
          photoUrl: firebaseUser.photoURL,
        );
      } else {
        _localUser = null;
      }
      notifyListeners();
    });
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await gsi.GoogleSignIn.instance.initialize(
      serverClientId: '68722970471-pau8krffnjflfskkkfvfnfjhn1bcqto0.apps.googleusercontent.com',
    );
    _initialized = true;
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      debugPrint('[AuthService] signIn appelé...');
      await _ensureInitialized();
      final googleAccount = await gsi.GoogleSignIn.instance.authenticate();
      debugPrint('[AuthService] Connecté: ${googleAccount.displayName} / ${googleAccount.email}');

      // Lier le compte Google à Firebase Auth
      final googleAuth = googleAccount.authentication;
      debugPrint('[AuthService] googleAuth idToken=${googleAuth.idToken != null}');
      // Note securite : Firebase accepte idToken seul pour signInWithCredential.
      // google_sign_in v7.2.0 n'expose pas accessToken sur GoogleSignInAuthentication.
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      debugPrint('[AuthService] FirebaseAuth signInWithCredential uid=${firebaseUser?.uid} email=${firebaseUser?.email}');

      _localUser = LocalUser(
        displayName: googleAccount.displayName ?? firebaseUser?.displayName ?? 'Utilisateur',
        email: googleAccount.email,
        photoUrl: googleAccount.photoUrl ?? firebaseUser?.photoURL,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on gsi.GoogleSignInException catch (e) {
      debugPrint('[AuthService] GoogleSignInException: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e, st) {
      debugPrint('[AuthService] ERREUR: $e');
      debugPrint('$st');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await gsi.GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
    _localUser = null;
    notifyListeners();
  }

  /// Genere ou restaure un identifiant anonyme unique.
  ///
  /// Utilise [FlutterSecureStorage] (Keychain/Keystore) en priorite,
  /// avec fallback sur [SharedPreferences] si le secure storage est
  /// indisponible (ex: appareil rooté, Android Keystore desactivé).
  Future<String> ensureAnonymousId() async {
    if (uid != null) return uid!;

    const key = 'anonymous_user_id';
    final storage = FlutterSecureStorage();

    // 1. Essayer le secure storage d'abord
    try {
      final secureStored = await storage.read(key: key);
      if (secureStored != null && secureStored.isNotEmpty) {
        return secureStored;
      }
    } catch (_) {
      // Fallback : secure storage indisponible
    }

    // 2. Fallback SharedPreferences (migration des utilisateurs existants)
    final prefs = await SharedPreferences.getInstance();
    final legacyStored = prefs.getString(key);

    // 3. Generer un nouvel ID si aucun n'existe
    String id;
    if (legacyStored != null && legacyStored.isNotEmpty) {
      id = legacyStored;
    } else {
      final rnd = math.Random.secure();
      final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
      id = base64Url.encode(sha256.convert(bytes).bytes).substring(0, 28);
    }

    // 4. Persister dans secure storage (et SharedPreferences pour compatibilite)
    try {
      await storage.write(key: key, value: id);
    } catch (_) {}
    await prefs.setString(key, id);

    return id;
  }
}
