# 🔐 AUDIT SÉCURITÉ COMPLET — SpotsApp v1.0.0+2

**Date :** 09/07/2026  
**Projet Flutter :** `com.zagorito.spots_app` (Firebase: `zagorito-9a0c4`)  
**Périmètre :** Code Dart, configuration Android/iOS, Firebase, règles Firestore, APK

---

## 🔴 Niveau de Sévérité

| Niveau | Signification |
|--------|---------------|
| 🔴 CRITIQUE | Exploitable immédiatement, impact fort (vol données, bypass auth, reverse engineering) |
| 🟠 HAUTE | Risque important nécessitant correction rapide |
| 🟡 MOYENNE | Mauvaise pratique, vecteur d'attaque secondaire |
| 🟢 BASSE | Optimisation, recommandation |

---

## 1. 🔴 CRITIQUE — Clé API Firebase exposée en clair dans le binaire APK/IPA

### Fichier : `lib/firebase_options.dart`

```dart
// Lignes 43-85
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'AIzaSyAiDLTtZzrUchYBmo-x2WFopmth-ji6pOk',
  appId: '1:68722970471:android:22dce79885650fc112e9c2',
  ...
);
```

### Problème
Les clés API Firebase (`apiKey`) sont compilées en dur dans le binaire. Un reverse engineering basique (`strings` + `apktool` sur l'APK, ou `otool` sur l'IPA) permet de les extraire en 30 secondes.

### Risques
- Accès non autorisé à Firebase Auth / Firestore si les restrictions SHA-1 ne sont pas strictes
- Création de comptes frauduleux
- Requêtes Firestore massives = coût financier

### Correctif
1. **Firebase Console → Authentication → Sign-in method → Android :** Restreindre strictement aux SHA-1/SHA-256 de tes keystores release.
2. **Firebase Console → Firestore → Rules :** Déjà partiellement fait (voir §2), mais renforcer.
3. **Firebase Console → APIs & Services → Credentials → API Key (Android) :** Appliquer une restriction par package name + SHA-1. **NE PAS** laisser "None" pour Application restrictions.
4. Côté code : Déplacer `apiKey` dans `.env` via `flutter_dotenv` (déjà présent dans `pubspec.yaml` mais non utilisé pour Firebase). L'option `flutter_dotenv` cache les clés du code source Git mais ne les cache pas du binaire compilé — **la seule vraie protection reste le restriction côté Firebase Console.**

---

## 2. 🔴 CRITIQUE — Clé de chiffrement AES-256 hardcodée

### Fichier : `lib/services/spot_service.dart`

```dart
// Ligne 53
static const String _encKey = 'q/F+3pnu668/hPnjF96uTqZH+7E24ppnH+53+rwdya0=';
```

### Problème
La clé AES-256-CBC utilisée pour déchiffrer `assets/spots.csv.enc` est en dur dans le code source. N'importe qui décompile l'APK peut :
1. Extraire la clé
2. Déchiffrer le fichier CSV (IV en 16 premiers bytes du fichier)
3. Récupérer l'intégralité de la base de spots de pêche

### Risques
- Vol de la base de données de spots (propriété intellectuelle)
- Contournement du système premium (les spots premium sont déchiffrés sans authentification)

### Correctif
1. **Option minimale :** Ne pas hardcoder la clé. Utiliser `flutter_dotenv` et placer la clé dans un fichier `.env` (non commité). Le fichier `.env.example` existe déjà mais n'est pas utilisé pour `_encKey`.
2. **Option intermédiaire :** Utiliser le **flutter_secure_storage** (Keychain iOS / Android Keystore) pour stocker une clé maître. Générer une clé aléatoire au premier lancement, la stocker dans le Keystore, dériver la clé AES depuis cette clé maître.
3. **Option renforcée :** Chiffrer le CSV avec une clé dérivée côté serveur (jamais embarquée dans l'APK) et fournie via une API authentifiée. Les utilisateurs premium reçoivent la clé, les gratuits non. Cela protège à la fois les données et le business model.
4. **Obfuscation :** Bien que R8/ProGuard soit activé (`isMinifyEnabled = true`), les strings constants Dart ne sont pas forcément obfusquées. Utiliser `flutter build apk --obfuscate --split-debug-info`.

---

## 3. 🔴 CRITIQUE — `force_premium` bypass via SharedPreferences

### Fichier : `lib/providers/premium_provider.dart`

```dart
// Lignes 13-17
bool get isPremium => _forcePremium || (_subscription?.hasPremiumAccess ?? false);
double get maxZoom => _forcePremium ? 16.0 : (_subscription?.maxZoom ?? 8.0);

// Lignes 51-57
Future<void> _loadForcePremium() async {
  final prefs = await SharedPreferences.getInstance();
  _forcePremium = prefs.getBool('force_premium') ?? false;
}
```

### Problème
N'importe quel utilisateur avec un appareil rooté peut modifier les SharedPreferences (`/data/data/com.zagorito.spots_app/shared_prefs/`) et forcer `force_premium = true`. Cela débloque **tous les accès premium** sans payer.

### Risques
- Perte de revenus (bypass total du système d'abonnement)
- Zoom max 16.0 accessible, spots premium visibles, toutes fonctionnalités premium gratuites

### Correctif
1. **Supprimer `_forcePremium`** du build release. Le garder uniquement pour le développement :
   ```dart
   import 'package:flutter/foundation.dart' show kDebugMode;
   // ...
   bool get isPremium => (kDebugMode && _forcePremium) || (_subscription?.hasPremiumAccess ?? false);
   ```
2. **Vérifier le statut premium côté serveur** (Firestore). Actuellement la vérification est locale avec un fallback côté client. La règle Firestore pour `subscriptions/{userId}` est correcte (`request.auth.uid == userId`), mais il faut que le code client ne contourne pas cette vérification.
3. **Ajouter une vérification HMAC :** Le serveur signe le statut premium avec une clé secrète. Le client vérifie la signature. Sans signature valide, refuser l'accès.

---

## 4. 🔴 CRITIQUE — Firestore `spots_meteo` en lecture publique

### Fichier : `firestore.rules`

```
match /spots_meteo/{document} {
  allow read: if true;  // ← Lecture publique sans restriction
  allow write: if request.auth != null
    && request.auth.token.email == '...';
}
```

### Problème
N'importe qui peut lire toutes les prévisions météo sans authentification. Si ces données ont un coût d'API (recupérées via un service payant), tu exposes un endpoint gratuit utilisable par des bots.

### Risques
- Scraping massif des données météo
- Coûts Firestore (reads facturés) si un bot boucle sur la collection

### Correctif
```javascript
// Restreindre aux utilisateurs authentifiés de l'app
allow read: if request.auth != null;

// Ou : limiter le débit avec une condition sur le timestamp
allow read: if request.auth != null
  && request.time < request.resource.data.lastRead + duration.time(1, 0, 0, 0);
```

---

## 5. 🔴 CRITIQUE — Google Sign-In `serverClientId` exposé, auth non vérifiée

### Fichier : `lib/services/auth_service.dart`

```dart
// Ligne 55
await gsi.GoogleSignIn.instance.initialize(
  serverClientId: '68722970471-pau8krffnjflfskkkfvfnfjhn1bcqto0.apps.googleusercontent.com',
);
```

### Problème
- Le `serverClientId` est un client ID **serveur** (pas Android). Il est utilisé pour obtenir un `idToken` côté client.
- Le `idToken` Google est fourni à Firebase Auth pour créer un credential (`GoogleAuthProvider.credential(idToken: ...)`).
- **Mais `accessToken` n'est pas fourni à Firebase.** La signature `GoogleAuthProvider.credential(idToken: idToken, accessToken: googleAuth.accessToken)` est la forme sécurisée. Sans `accessToken`, Firebase ne peut pas vérifier l'authenticité complète du token.

### Risques
- **Usurpation d'identité potentielle :** Un attaquant pourrait injecter un `idToken` forgé si le `serverClientId` est compromis.
- Le client ID serveur est visible dans l'APK décompilée — un attaquant peut l'utiliser pour créer des tokens OAuth frauduleux.

### Correctif
```dart
final credential = GoogleAuthProvider.credential(
  idToken: googleAuth.idToken,
  accessToken: googleAuth.accessToken,  // ← AJOUTER
);
```

**Firebase Console → Authentication → Sign-in providers → Google :**
- Vérifier que seuls les clients OAuth 2.0 autorisés (Android + iOS) sont configurés
- Ne pas activer le client Web si non utilisé

---

## 6. 🟠 HAUTE — Logs sensibles en production (uid, email, tokens)

### Fichiers : `auth_service.dart`, `subscription_service.dart`, `premium_provider.dart`

```dart
debugPrint('[AuthService] FirebaseAuth signInWithCredential uid=${firebaseUser?.uid} email=${firebaseUser?.email}');
debugPrint('[AuthService] googleAuth idToken=${googleAuth.idToken != null}');
debugPrint('[SubscriptionService] doc.exists=${doc.exists} data=${doc.data()}');
```

### Problème
Bien que `main.dart` (ligne 38) désactive `debugPrint` en mode release :
```dart
if (!kDebugMode) debugPrint = (String? message, {int? wrapWidth}) {};
```
Cela **n'empêche pas les logs d'être écrits sur Android Logcat** si `debugPrint` est redirigé, et surtout cela repose sur une seule ligne. Si un `print()` direct est utilisé au lieu de `debugPrint`, il passe.

Le fichier `services/tide_service.dart` utilise `print` au lieu de `debugPrint` :
```dart
debugPrint('$st');  // Affiche la stacktrace complète
```

### Risques
- Fuite d'UID Firebase, emails, tokens JWT dans les logs système
- Sur Android, toute application avec `READ_LOGS` (déprécié mais possible sur versions rootées) peut intercepter ces logs

### Correctif
1. Remplacer tous les `print()` par `debugPrint()`.
2. Ajouter dans `main.dart` **aussi** un override pour `print` :
   ```dart
   if (!kDebugMode) {
     debugPrint = (String? message, {int? wrapWidth}) {};
     print = (Object? object) {};  // Ajout
   }
   ```
   Note : ceci n'est pas une fonction `print` standard, il faut wrapper :
   ```dart
   void _noOpPrint(Object? object) {}
   if (!kDebugMode) {
     debugPrint = (String? message, {int? wrapWidth}) {};
   }
   ```
   Ou mieux, utiliser un package comme `logger` avec un filtre de niveau configurable.
3. **Ne jamais logger d'uid, email, ou token**, même en debug. Utiliser un ID anonymisé.

---

## 7. 🟠 HAUTE — `subscription_service.dart` fallback faille métier

### Fichier : `lib/services/subscription_service.dart`

```dart
// Lignes 55-60
on FirebaseException catch (e) {
  debugPrint('[SubscriptionService] FirebaseException getOrCreateSubscription: $e');
  return SubscriptionModel.newUser(userId);  // ← FAILLE : retourne un trial neuf
} catch (e) {
  debugPrint('[SubscriptionService] Erreur getOrCreateSubscription: $e');
  return SubscriptionModel.newUser(userId);  // ← FAILLE : idem
}
```

### Problème
Si Firestore est inaccessible ou si l'utilisateur a un problème réseau, le code **crée un nouvel abonnement trial**. Un attaquant peut :
1. Mettre son téléphone en mode avion
2. Recevoir un `SubscriptionModel.newUser()` → trial gratuit de 30 jours
3. Bloquer les futures requêtes Firestore pour rester en trial indéfiniment

### Correctif
En cas d'erreur réseau/Firestore, retourner un `SubscriptionModel.fallback()` sans accès premium :
```dart
static SubscriptionModel fallback(String userId) {
  return SubscriptionModel(userId: userId, planType: PlanType.free, ...);
}
```
Ne jamais créer de trial en fallback.

---

## 8. 🟠 HAUTE — Pas de `flutter_secure_storage` pour les tokens

### Problème
Aucune utilisation de `flutter_secure_storage`. Les tokens Firebase/Google Sign-In sont stockés par le SDK Firebase en interne (qui utilise le Keystore Android et Keychain iOS). Cependant, le `anonymous_user_id` est stocké dans `SharedPreferences` en clair :

```dart
// auth_service.dart:117
await prefs.setString('anonymous_user_id', stored);
```

### Risque
- Vol d'identifiant anonyme (permettant de lier les données d'usage)
- Si d'autres données sensibles sont ajoutées aux SharedPreferences plus tard, elles seront en clair

### Correctif
Utiliser `flutter_secure_storage` pour `anonymous_user_id` et toute donnée sensible future.

---

## 9. 🟡 MOYENNE — APK debuggable potentiel

### Fichier : `android/app/build.gradle.kts`

```kotlin
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(...)
        // ...
    }
    // Pas de bloc debug { } explicite
}
```

### Problème
Par défaut, le build type `debug` a `debuggable = true`. Si par erreur un APK debug est distribué (testeurs, stores alternatifs), n'importe qui peut attacher un débogueur et inspecter la mémoire, les variables, les tokens.

### Correctif
- Ne **jamais** distribuer un APK debug. Toujours signer avec une clé release (`key.properties` déjà configuré).
- Vérifier avant chaque déploiement : `flutter build apk --release`.
- Ajouter dans le bloc `debug` (pour la CI) :
  ```kotlin
  debug {
      isDebuggable = true  // Explicite, et s'assurer qu'il n'est pas en release
  }
  ```

---

## 10. 🟡 MOYENNE — ProGuard trop permissif (`-keep` globaux)

### Fichier : `android/app/proguard-rules.pro`

```
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
```

### Problème
Les règles `-keep class X.** { *; }` empêchent TOUTE obfuscation de ces packages. Cela facilite le reverse engineering :
- Tous les noms de classes/méthodes Firebase sont visibles
- Toute la glue Flutter est en clair

### Correctif
Affiner les règles ProGuard pour ne garder que les points d'entrée nécessaires. Pour Firebase, suffit généralement de :
```
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.firebase.** { public *; }
```

---

## 11. 🟡 MOYENNE — iOS ATS non configuré strictement

### Fichier : `ios/Runner/Info.plist`

À vérifier (non lu). Si `NSAppTransportSecurity` n'est pas configuré, iOS 9+ autorise toutes les connexions HTTPS par défaut. Pour renforcer :
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

---

## 12. 🟡 MOYENNE — Dépendances non épinglées (supply chain)

### Fichier : `pubspec.yaml`

```yaml
firebase_core: ^4.11.0    # Accepte 4.11.0 ≤ x < 5.0.0
firebase_auth: ^6.5.4
cloud_firestore: ^6.6.0
```

### Problème
Le caret `^` accepte automatiquement les versions mineures/patchs. Un attaquant qui compromet un package peut publier une version `6.5.5` malveillante, et ton pipeline CI/CD la récupérera.

### Correctif
- Utiliser `pubspec.lock` (déjà présent, vérifié dans le repo — bien).
- **Ne pas supprimer `pubspec.lock`** du repo Git (bonne pratique : le commiter pour les applications, ne pas le commiter pour les packages).
- **Bonus :** Vérifier les dépendances avec `flutter pub outdated` régulièrement.

---

## 13. 🟡 MOYENNE — Fichiers CSV sensibles dans les assets

### Fichier : `pubspec.yaml`, `assets/`

```yaml
assets:
  - assets/spots.csv.enc
  - assets/shops.csv        # ← EN CLAIR
  - assets/fish_data.json   # ← EN CLAIR
  - assets/peche_*.csv      # ← EN CLAIR
```

### Problème
`spots.csv` est chiffré (`.enc`), c'est bien. Mais `shops.csv`, `fish_data.json` et les fichiers `peche_*_database*.csv` sont en clair dans l'APK. N'importe qui peut extraire ces données avec `apktool` puis `unzip`.

### Correctif
- Chiffrer tous les fichiers de données avec le même mécanisme AES-256-CBC
- Ou : déplacer ces données côté serveur (Firestore/Firebase Storage) pour les requêter via API

---

## 14. 🟢 BASSE — `analysis_options.yaml` minimal

Le fichier `analysis_options.yaml` n'active aucun lint additionnel. Recommandé d'ajouter :
```yaml
linter:
  rules:
    - avoid_print
    - avoid_web_libraries_in_flutter
    - cancel_subscriptions
    - prefer_const_constructors
    - use_key_in_widget_constructors
    - avoid_dynamic_calls
    - no_leading_underscores_for_library_prefixes
```

---

## 15. 🟢 BASSE — Absence de détection de root/jailbreak

Un attaquant avec un appareil rooté peut :
- Modifier les SharedPreferences (cf. §3)
- Hooker les fonctions Dart via Frida
- Intercepter le trafic réseau (même HTTPS avec certificate pinning bypass)

### Correctif
Ajouter un package comme `flutter_jailbreak_detection` pour détecter et bloquer les appareils compromis. Combiner avec `flutter_secure_storage` qui refuse de fonctionner sur appareils rootés (sur Android, `KeyStore` est désactivé si le bootloader est déverrouillé).

---

## 16. 🟢 BASSE — Pas de certificate pinning

Les requêtes HTTP (Dio, http) ne vérifient pas le certificat SSL du serveur. Un MITM avec un proxy type Charles/mitmproxy peut intercepter le trafic si l'utilisateur a installé un certificat CA personnalisé.

### Correctif
Implémenter le certificate pinning avec Dio :
```dart
(dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
  client.badCertificateCallback = (cert, host, port) => false; // Bloquer tous les certificats invalides
  // Ou vérifier le fingerprint SHA256 attendu
};
```

---

## 📊 RÉSUMÉ DES ACTIONS PRIORITAIRES

| # | Sévérité | Problème | Effort | Impact |
|---|----------|----------|--------|--------|
| 1 | 🔴 | Clé API Firebase non restreinte (Firebase Console) | Faible | Bloque exploitation |
| 2 | 🔴 | Clé AES-256 hardcodée | Élevé | Protège IP |
| 3 | 🔴 | `force_premium` bypass | Faible | Protège revenus |
| 4 | 🔴 | Firestore lecture publique | Faible | Protège coûts API |
| 5 | 🔴 | Google OAuth `accessToken` manquant | Moyen | Protège auth |
| 6 | 🟠 | Logs sensibles | Faible | Protège données |
| 7 | 🟠 | Fallback trial gratuit | Moyen | Protège revenus |
| 8 | 🟠 | `anonymous_user_id` en SharedPreferences | Faible | Conformité |
| 13 | 🟡 | CSV en clair dans l'APK | Élevé | Protège IP |

**Recommandation :** Corriger les 5 🔴 CRITIQUE avant toute publication sur le Play Store / App Store. Les 🟠 HAUTE avant la V2. Le reste progressivement.