// ============================================================
//  auth_service.dart — Google Sign-In lié à Firebase Auth
//  Compatible google_sign_in ^7.2.0 (API singleton)
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalUser {
  final String displayName;
  final String email;
  final String? photoUrl;
  const LocalUser(
      {required this.displayName, required this.email, this.photoUrl});
}

/// Catégorie non sensible du dernier échec de connexion.
///
/// Aucun jeton, e-mail ou détail retourné par Google n'est exposé à l'UI.
enum SignInFailure {
  canceled,
  interrupted,
  googleClientConfiguration,
  googleProviderConfiguration,
  uiUnavailable,
  missingIdToken,
  network,
  providerDisabled,
  credentialRejected,
  userDisabled,
  tooManyRequests,
  firebase,
  unexpected,
}

class AuthService extends ChangeNotifier {
  late final StreamSubscription<User?> _authStateSubscription;
  LocalUser? _localUser;
  bool _isLoading = false;
  bool _initialized = false;
  SignInFailure? _lastSignInFailure;

  LocalUser? get user => _localUser;
  bool get isLoggedIn => _localUser != null;
  bool get isLoading => _isLoading;
  SignInFailure? get lastSignInFailure => _lastSignInFailure;
  String? get displayName => _localUser?.displayName;
  String? get email => _localUser?.email;
  String? get photoUrl => _localUser?.photoUrl;
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  AuthService() {
    debugPrint('[AuthService] Initialisé${kIsWeb ? ' (web)' : ' (android)'}');
    // Restaurer la session Firebase persistée au démarrage
    _authStateSubscription =
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

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    // L'authentification Google utilise uniquement le flux standard (pas de
    // serverClientId). Le backend Firebase Functions gère la vérification
    // serveur si nécessaire.
    await gsi.GoogleSignIn.instance.initialize();
    _initialized = true;
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _lastSignInFailure = null;
    notifyListeners();
    try {
      debugPrint('[AuthService] signIn appelé...');
      await _ensureInitialized();
      final googleAccount = await gsi.GoogleSignIn.instance.authenticate();
      // Ne jamais écrire l'adresse e-mail ou le nom dans les journaux de
      // production : ce sont des données personnelles.
      debugPrint('[AuthService] Compte Google authentifié');

      // Lier le compte Google à Firebase Auth
      final googleAuth = googleAccount.authentication;
      debugPrint(
          '[AuthService] googleAuth idToken=${googleAuth.idToken != null}');
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        _lastSignInFailure = SignInFailure.missingIdToken;
        return false;
      }
      // Note securite : Firebase accepte idToken seul pour signInWithCredential.
      // google_sign_in v7.2.0 n'expose pas accessToken sur GoogleSignInAuthentication.
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      debugPrint('[AuthService] Session Firebase Auth établie');

      _localUser = LocalUser(
        displayName: googleAccount.displayName ??
            firebaseUser?.displayName ??
            'Utilisateur',
        email: googleAccount.email,
        photoUrl: googleAccount.photoUrl ?? firebaseUser?.photoURL,
      );
      return true;
    } on gsi.GoogleSignInException catch (e) {
      _lastSignInFailure = _mapGoogleFailure(e.code);
      debugPrint('[AuthService] GoogleSignInException: ${e.code.name}');
      return false;
    } on FirebaseAuthException catch (e) {
      _lastSignInFailure = _mapFirebaseFailure(e.code);
      debugPrint('[AuthService] FirebaseAuthException: ${e.code}');
      return false;
    } catch (e, st) {
      _lastSignInFailure = SignInFailure.unexpected;
      debugPrint('[AuthService] ERREUR: $e');
      debugPrint('$st');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  SignInFailure _mapGoogleFailure(gsi.GoogleSignInExceptionCode code) {
    switch (code) {
      case gsi.GoogleSignInExceptionCode.canceled:
        return SignInFailure.canceled;
      case gsi.GoogleSignInExceptionCode.interrupted:
        return SignInFailure.interrupted;
      case gsi.GoogleSignInExceptionCode.clientConfigurationError:
        return SignInFailure.googleClientConfiguration;
      case gsi.GoogleSignInExceptionCode.providerConfigurationError:
        return SignInFailure.googleProviderConfiguration;
      case gsi.GoogleSignInExceptionCode.uiUnavailable:
        return SignInFailure.uiUnavailable;
      case gsi.GoogleSignInExceptionCode.unknownError:
      case gsi.GoogleSignInExceptionCode.userMismatch:
        return SignInFailure.unexpected;
    }
  }

  SignInFailure _mapFirebaseFailure(String code) {
    switch (code) {
      case 'network-request-failed':
        return SignInFailure.network;
      case 'operation-not-allowed':
        return SignInFailure.providerDisabled;
      case 'invalid-credential':
      case 'account-exists-with-different-credential':
        return SignInFailure.credentialRejected;
      case 'user-disabled':
        return SignInFailure.userDisabled;
      case 'too-many-requests':
        return SignInFailure.tooManyRequests;
      default:
        return SignInFailure.firebase;
    }
  }

  /// Supprime le compte Firebase Auth et ses donnees Firestore.
  /// Retourne true si la suppression a reussi.
  Future<bool> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Les suppressions de compte sont une opération sensible. Réauthentifier
    // avant de supprimer Firestore évite de perdre le document si Firebase
    // Auth refuse ensuite la suppression pour session trop ancienne.
    try {
      await _reauthenticateForDeletion(user);
    } on FirebaseAuthException catch (e) {
      debugPrint(
          '[AuthService] Réauthentification suppression refusée: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('[AuthService] Réauthentification suppression échouée: $e');
      return false;
    }

    // 1. Supprimer les données contrôlées par l'utilisateur. Les règles
    // autorisent uniquement ce delete, jamais les créations/modifications.
    try {
      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(user.uid)
          .delete();
    } on FirebaseException catch (e) {
      debugPrint('[AuthService] Suppression Firestore échouée: ${e.code}');
      return false;
    }

    // 2. Supprimer le compte Firebase Auth après la réauthentification.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Suppression Auth échouée: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('[AuthService] Suppression Auth échouée: $e');
      return false;
    }

    // 3. Nettoyer le stockage local au mieux. La suppression Firebase a
    // déjà réussi : une panne du stockage local ne doit pas faire croire à
    // l'utilisateur que son compte existe encore.
    _localUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('anonymous_user_id');
    } catch (e) {
      debugPrint('[AuthService] Nettoyage SharedPreferences indisponible: $e');
    }
    try {
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'anonymous_user_id');
    } catch (e) {
      debugPrint('[AuthService] Nettoyage SecureStorage indisponible: $e');
    }
    notifyListeners();
    return true;
  }

  /// Réauthentifie un compte Google avant une opération sensible.
  Future<void> _reauthenticateForDeletion(User user) async {
    final isGoogleUser =
        user.providerData.any((p) => p.providerId == 'google.com');
    if (!isGoogleUser) return;

    await _ensureInitialized();
    final googleAccount = await gsi.GoogleSignIn.instance.authenticate();
    final googleAuth = googleAccount.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Le jeton Google de réauthentification est indisponible.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await user.reauthenticateWithCredential(credential);
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
