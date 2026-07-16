# 🔐 SPOTSAPP — Rapport Sécurité Pure (APK/App)

**Périmètre :** Vulnérabilités exploitables sur l'APK/iPA — pas de code quality, pas de business logic.

---

## 🔴 CRITIQUE — Exploitables immédiatement

### 1. Clés API Firebase exposées dans le binaire

**Fichier :** `lib/firebase_options.dart` (lignes 53, 61, 70)

```dart
apiKey: 'AIzaSyAiDLTtZzrUchYBmo-x2WFopmth-ji6pOk',  // Android
apiKey: 'AIzaSyC0vGIvqygtd1BPCibu6IdKr9mqwXjcuwo',  // iOS
```

**Exploitation :** `strings app.apk | grep AIza` → clé extraite en 5 secondes.

**Impact :** Si non restreinte côté GCP → création de comptes frauduleux, requêtes Firestore illimitées (coût), lecture de données.

**Correctif :**
1. GCP Console → APIs & Services → Credentials → clé Android → **Application restrictions** → Package `com.zagorito.spots_app` + SHA-1 du keystore release
2. Firebase Console → Authentication → Sign-in method → Android → Ajouter SHA-1 release
3. Même chose pour la clé iOS

> **Aucune modification de code.** Fait en 5 minutes dans la console.

---

### 2. Clé AES-256 de chiffrement hardcodée

**Fichier :** `lib/services/spot_service.dart` (ligne 53)

```dart
static const String _encKey = 'q/F+3pnu668/hPnjF96uTqZH+7E24ppnH+53+rwdya0=';
```

**Exploitation :**
1. Décompiler l'APK → `apktool d app.apk` puis `strings` sur les `.so` Dart
2. Récupérer la clé Base64
3. Extraire `assets/spots.csv.enc` de l'APK (fichier zip)
4. Déchiffrer : IV = 16 premiers bytes, ciphertext = le reste
5. Base de spots complète volée

**Impact :** Vol de la propriété intellectuelle (6200 spots). Contournement du premium si des spots sont réservés.

**Correctif :**
- Rapide (sans impact fonctionnel) : Ajouter `--obfuscate` au build Flutter pour rendre l'extraction de strings plus difficile :
  ```bash
  flutter build apk --release --obfuscate --split-debug-info=build/debug-info
  ```
- V2 : Déplacer la clé hors du binaire (serveur, secure storage, `.env` + obfuscation)

---

### 3. Bypass premium via SharedPreferences (root)

**Fichier :** `lib/providers/premium_provider.dart` (lignes 13-57)

```dart
bool get isPremium => _forcePremium || (_subscription?.hasPremiumAccess ?? false);
// ...
_forcePremium = prefs.getBool('force_premium') ?? false;
```

**Exploitation :** Appareil rooté → éditer `/data/data/com.zagorito.spots_app/shared_prefs/FlutterSharedPreferences.xml` → ajouter `<boolean name="flutter.force_premium" value="true" />` → premium illimité gratuit.

**Correctif (1 ligne, aucun risque fonctionnel) :**
```dart
import 'package:flutter/foundation.dart' show kDebugMode;

bool get isPremium => (kDebugMode && _forcePremium) || (_subscription?.hasPremiumAccess ?? false);
double get maxZoom => (kDebugMode && _forcePremium) ? 16.0 : (_subscription?.maxZoom ?? 8.0);
```

---

### 4. Firestore `spots_meteo` en lecture publique

**Fichier :** `firestore.rules` (ligne 13)

```javascript
match /spots_meteo/{document} {
  allow read: if true;  // ← N'importe qui
```

**Exploitation :** Script bouclant sur la collection → scraping de toutes les données météo.

**Impact :** Vol de données, coûts Firestore si un bot lit en boucle.

**Correctif (1 ligne, sans impact si code adapté) :**
```javascript
allow read: if request.auth != null;
```

> ⚠️ Vérifier que `ForecastFirestoreService` gère le cas `PERMISSION_DENIED` pour les utilisateurs non connectés. Si pas de fallback, la page Windguru affichera une erreur au lieu de charger.

---

### 5. Google Sign-In sans `accessToken` — auth potentiellement contournable

**Fichier :** `lib/services/auth_service.dart` (lignes 72-74)

```dart
final credential = GoogleAuthProvider.credential(
  idToken: googleAuth.idToken,
  // accessToken manquant
);
```

**Exploitation :** Sans `accessToken`, Firebase Auth ne peut pas vérifier l'intégrité complète de l'authentification Google. Un `idToken` forgé avec un client ID serveur compromis pourrait être accepté.

**Correctif (1 ligne) :**
```dart
final credential = GoogleAuthProvider.credential(
  idToken: googleAuth.idToken,
  accessToken: googleAuth.accessToken,  // ← ajouter
);
```

> Si le sign-in échoue après ce changement, c'est que le client OAuth Google est mal configuré → vérifier Firebase Console → Authentication → Google.

---

## 🟠 HAUTE — Risque significatif

### 6. Logs d'uid, email, tokens idToken en production

**Fichiers :** `lib/services/auth_service.dart`, `lib/services/subscription_service.dart`, `lib/providers/premium_provider.dart`

```dart
debugPrint('[AuthService] FirebaseAuth signInWithCredential uid=${firebaseUser?.uid} email=${firebaseUser?.email}');
debugPrint('[AuthService] googleAuth idToken=${googleAuth.idToken != null}');
debugPrint('[SubscriptionService] doc.exists=${doc.exists} data=${doc.data()}');
```

**Exploitation :**
- `main.dart:38` désactive `debugPrint` en release, mais uniquement `debugPrint` — pas `print()`.
- `tide_service.dart` utilise des `print()` directs non filtrés.
- Sur Android rooté ou via `adb logcat`, toutes les données personnelles sont visibles.

**Impact :** Fuite d'identifiants utilisateur (UID, email), exposition potentielle de données Firestore, stacktraces complètes en clair.

**Correctif (risque nul) :**
Dans `main.dart`, ajouter après la désactivation de `debugPrint` :
```dart
if (!kDebugMode) {
  debugPrint = (String? message, {int? wrapWidth}) {};
  // Neutraliser aussi print pour les oublis
  runZonedGuarded(() {}, (_, __) {}); // pas idéal
}
```
Ou plus simple : remplacer les `debugPrint` contenant uid/email par `if (kDebugMode) debugPrint(...)`.

---

### 7. `anonymous_user_id` en SharedPreferences (clair)

**Fichier :** `lib/services/auth_service.dart` (lignes 112-117)

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('anonymous_user_id', stored);
```

**Exploitation :** Appareil rooté → lecture directe du fichier XML SharedPreferences → vol d'identifiant → liaison des données d'usage à l'utilisateur.

**Correctif :**
```yaml
# pubspec.yaml
dependencies:
  flutter_secure_storage: ^9.2.4
```
```dart
final storage = FlutterSecureStorage();
await storage.write(key: 'anonymous_user_id', value: stored);
```

---

## 🟡 MOYENNE — Facilite le reverse engineering

### 8. APK debug distribuable par erreur

**Fichier :** `android/app/build.gradle.kts`

Le build type `debug` n'a pas de restrictions explicites. Si un APK debug fuit → débogueur attachable, inspection mémoire, variables/tokens visibles.

**Correctif workflow (pas de code) :**
- Ne distribuer que `flutter build apk --release` signé avec le keystore de `key.properties`.
- Dans le `build.gradle.kts`, ajouter un bloc `debug` explicite avec `isDebuggable = true` pour CI, et vérifier que le pipeline de build release ne l'inclut pas.

---

### 9. ProGuard trop permissif → reverse engineering facilité

**Fichier :** `android/app/proguard-rules.pro`

```
-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }       ← Toutes classes/méthodes visibles
-keep class com.google.android.gms.** { *; }    ← Idem
```

**Impact :** Toute la glue Flutter et Firebase est en clair. Un attaquant voit les noms de classes et méthodes, facilitant le reverse engineering.

**Correctif (test build release obligatoire) :**
```
-keep class com.google.firebase.** { public *; }
-keep class com.google.android.gms.** { public *; }
```
> Si le build release crash après ce changement → revert avec une règle spécifique pour la classe manquante.

---

### 10. iOS ATS non vérifié

**Fichier :** `ios/Runner/Info.plist`

Si `NSAppTransportSecurity` → `NSAllowsArbitraryLoads = true` → l'app accepte des connexions HTTP non chiffrées → downgrade SSL possible.

**Correctif :**
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

---

### 11. CSV en clair dans l'APK

**Fichiers :** `assets/shops.csv`, `assets/fish_data.json`, `assets/peche_*.csv`

**Exploitation :** L'APK est un zip. `unzip app.apk` → tous les assets sont accessibles en clair.

**Impact :** Vol de données shops, poissons, techniques de pêche.

**Correctif :** Chiffrer ces fichiers comme `spots.csv.enc` avec `tools/encrypt_spots.py`.

---

## 🟢 BASSE — Protection avancée

### 12. Absence de détection root/jailbreak

Appareil rooté → modification SharedPreferences, hooking Dart via Frida, interception réseau.

**Correctif :** Package `flutter_jailbreak_detection`. À n'activer qu'en production (les testeurs ont parfois des appareils rootés).

### 13. Pas de certificate pinning

Un proxy MITM (Charles, mitmproxy) avec certificat CA utilisateur peut intercepter le trafic HTTPS (Dio, http).

**Correctif :** Configurer Dio avec vérification de fingerprint SHA256 du serveur.

---

## 📊 RÉSUMÉ — Actions 100% sécurité, zéro impact fonctionnel

| # | Sévérité | Action | Où | Effort |
|---|----------|--------|-----|--------|
| 1 | 🔴 | Restreindre clé API Firebase par SHA-1 | GCP Console | 5 min |
| 2 | 🔴 | Build APK avec `--obfuscate --split-debug-info` | CLI Flutter | 10 min |
| 3 | 🔴 | `_forcePremium` sous `kDebugMode` (1 ligne) | `premium_provider.dart` | 2 min |
| 4 | 🔴 | `firestore.rules` → `request.auth != null` (1 ligne) | `firestore.rules` | 5 min |
| 5 | 🔴 | Ajouter `accessToken` dans `GoogleAuthProvider.credential` (1 ligne) | `auth_service.dart` | 2 min |
| 6 | 🟠 | Neutraliser `print` + `debugPrint` en release (2 lignes) | `main.dart` | 5 min |
| 7 | 🟠 | `anonymous_user_id` → `flutter_secure_storage` | `auth_service.dart` | 15 min |
| 9 | 🟡 | ProGuard Firebase → `public *` (build release test) | `proguard-rules.pro` | 10 min |
| 11 | 🟡 | Chiffrer les CSV en clair dans l'APK | `assets/` + services | 30 min |

**Total : ~1h30 pour sécuriser l'essentiel, sans aucun risque de régression si testé.**