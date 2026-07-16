# 🧾 AUDIT PLAY CONSOLE V2 — BoosterFish (Spots App)

**Date** : 05/07/2026  
**Version** : 1.0.0+1 (pubspec.yaml)  
**Package** : `com.zagorito.spots_app`  
**Nom affiché** : BoosterFish  

---

## 📊 RÉSUMÉ EXÉCUTIF

| Critère | Verdict |
|---|---|
| **Score Global** | ✅ **QUASI PRÊT** (0 bloqueur critique détecté) |
| 🔴 Blockers | 0 (mais ⚠️ Play Signing SHA-1 requis avant Google Sign-In fonctionnel) |
| 🟡 Warnings | 5 |
| 💡 Recommandations | 5 |

Les 3 bloqueurs critiques de l'audit précédent (28/06/2026) ont été corrigés :
- ✅ Package renommé `com.example` → `com.zagorito.spots_app`
- ✅ Signature release configurée via `key.properties`
- ✅ ProGuard/R8 activé avec `proguard-rules.pro`

---

## 🔴 PROBLÈMES CRITIQUES (BLOCKERS)

**Aucun bloqueur détecté. Le projet peut être soumis sur Google Play.**

---

## 🟡 AVERTISSEMENTS (WARNINGS)

### 1. ⚠️ PLAY APP SIGNING — SHA-1 Firebase à mettre à jour
**Contexte** : Google Play re-signe l'AAB avec sa propre clé (Play App Signing).  
Le SHA-1 de l'APK installé depuis Play Store est donc **différent** de celui de ton build local.  
Firebase Auth (Google Sign-In) utilise le SHA-1 pour authentifier l'app → **Google Sign-In échouera** si le SHA-1 Play n'est pas enregistré dans Firebase.

**Procédure corrective** :
1. Play Console → Release → Setup → App integrity → copier le **SHA-1** du `App signing key certificate`
2. Firebase Console → Project settings → Your apps → app Android `com.zagorito.spots_app` → **Add fingerprint** → coller ce SHA-1
3. **Télécharger un nouveau `google-services.json`** depuis Firebase (il contient désormais le SHA-1 Play)
4. Remplacer `android/app/google-services.json` par le nouveau fichier
5. Rebuild l'AAB : `flutter clean && flutter pub get && flutter build appbundle --release`
6. Réuploader l'AAB sur Play Console

**Note** : Garde aussi le SHA-1 de ta clé d'upload locale (`upload key`) pour les tests en local.

### 2. iOS Bundle ID incohérent dans `firebase_options.dart`
**Fichier** : `lib/firebase_options.dart:66,75`
```dart
static const FirebaseOptions ios = FirebaseOptions(
  iosBundleId: 'com.example.spotsApp',  // ⚠️ Devrait correspondre au vrai bundle ID iOS
);
```
**Impact** : Si l'app iOS est déployée, le bundle ID Firebase ne correspondra pas.  
**Action** : Mettre à jour avec le vrai bundle ID iOS après configuration de l'app iOS.

### 3. Flags Gradle obsolètes dans `gradle.properties`
**Fichier** : `android/gradle.properties:4-6`
```properties
android.newDsl=false
android.builtInKotlin=false
```
**Impact** : Ces flags étaient utilisés pour la migration Gradle. Avec AGP 9.0.1 et Kotlin 2.3.20, ils ne sont plus nécessaires.  
**Action** : Supprimer les lignes 4 et 6.

### 4. `debugPrint` résiduels en release
**Fichiers** :
- `lib/services/subscription_service.dart:15-18` — `debugPrint('[SubscriptionService]...')`  
- `lib/services/auth_service.dart:36` — `debugPrint('[AuthService] ...')`  

**Impact** : Bien que `debugPrint` soit désactivé en release (`main.dart:38`), ces logs sont inutiles et pourraient exposer des informations en cas de fuite.  
**Action** : Supprimer les `debugPrint` ou les conditionner avec `if (kDebugMode)`.

### 5. Pas de politique de confidentialité visible
**Impact** : Google Play exige un lien vers une politique de confidentialité pour toute app collectant des données personnelles (email, localisation via Firebase Auth).  
**Action** : Ajouter un lien Privacy Policy dans la page Settings et dans la fiche Play Console.

---

## 💡 RECOMMANDATIONS

| # | Suggestion | Action |
|---|---|---|
| 1 | Mettre à jour le target SDK pour la version 2026 | `targetSdk = 36` déjà OK ✅ |
| 2 | Ajouter icône de notification `@mipmap/ic_notification` | Créer une icône de notification dans `android/app/src/main/res/` |
| 3 | Ajouter un fichier `privacy_policy.html` dans l'app et un lien dans Settings | Obligatoire pour les apps avec Firebase Auth + géolocalisation |
| 4 | Nettoyer les fichiers de build résiduels | 27+ fichiers `build_log*.txt`, `run_log*.txt` — déjà dans `.gitignore` ✅ |
| 5 | Nettoyer les dossiers `/_backup_premium/` et fichiers `.bak` | `lib/_backup_premium/`, `lib/pages/home_page.dart.bak` — supprimer avant publication |

---

## 📋 CHECKLIST PLAY CONSOLE

| # | Item | Statut |
|---|---|---|
| 1 | Package name valide (pas `com.example`) | ✅ `com.zagorito.spots_app` |
| 2 | APK/AAB signé avec clé release | ✅ `key.properties` configuré |
| 3 | ProGuard/R8 activé | ✅ `isMinifyEnabled = true` + `proguard-rules.pro` |
| 4 | `targetSdk` ≥ 33 (dernier requis) | ✅ `targetSdk = 36` |
| 5 | `usesCleartextTraffic="false"` | ✅ |
| 6 | Icône de notification | ❌ Manquante |
| 7 | Politique de confidentialité | ❌ Manquante |
| 8 | Classification par âge dans Play Console | ❌ À remplir |
| 9 | Fiche Store complète | ❌ À remplir |
| 10 | Build `.aab` release | ❌ `flutter build appbundle --release` |
| 11 | Test sur device physique Android 8+ | ❌ À faire |

---

## 📋 AUDIT TECHNIQUE DÉTAILLÉ

### Android / Gradle
| Paramètre | Valeur | Statut |
|---|---|---|
| minSdkVersion | 24 | ✅ ≥21 |
| targetSdkVersion | 36 | ✅ Dernier |
| compileSdkVersion | 36 | ✅ |
| AGP | 9.0.1 | ✅ |
| Kotlin | 2.3.20 | ✅ |
| Java | 17 | ✅ |
| 64-bit | Automatique Flutter | ✅ |
| ProGuard/R8 | ✅ Activé | ✅ |
| Signature release | `key.properties` | ✅ |
| `newDsl` flag | Présent | 🟡 Obsolète |

### Permissions Android
| Permission | Justification | Statut |
|---|---|---|
| `INTERNET` | Tuiles OpenStreetMap | ✅ |
| `ACCESS_FINE_LOCATION` | GPS spots + distance | ✅ |
| `ACCESS_COARSE_LOCATION` | Localisation approchée | ✅ |
| Pas de permissions sensibles inutiles | - | ✅ |

### Firebase / Sécurité
| Test | Résultat |
|---|---|
| `google-services.json` match le package | ✅ `com.zagorito.spots_app` |
| Firebase API keys exposées | ✅ Normal (clés publiques Firebase) |
| Firestore règles | ✅ `allow read, write: if request.auth != null && request.auth.uid == userId` |
| Cloud Functions | ✅ `functions/lib/conditions.js` (Open-Meteo API calls) |
| `.env` dans git | ✅ Exclu via `.gitignore` |
| `.env` dans assets pubspec | ✅ Non listé dans les assets |
| Keystore dans git | ✅ Exclu via `.gitignore` (`*.jks`) |

### Dépendances
| Package | Version | Statut |
|---|---|---|
| `firebase_core` | ^4.11.0 | ✅ |
| `firebase_auth` | ^6.5.4 | ✅ |
| `cloud_firestore` | ^6.6.0 | ✅ |
| `google_sign_in` | ^7.2.0 | ✅ |
| `geolocator` | ^14.0.3 | ✅ |
| `flutter_map` | ^8.3.0 | ✅ |
| `flutter_lints` | ^6.0.0 | ✅ |

### Code Flutter
| Test | Résultat |
|---|---|
| Null safety | ✅ SDK ≥3.0.0 |
| Gestion d'état | ✅ Provider |
| try/catch | ✅ Présents |
| `debugShowCheckedModeBanner` | ✅ false |
| `kDebugMode` pour les logs | 🟡 Partiel (cf. warning 3) |

### Assets / Branding
| Item | Statut |
|---|---|
| Icône launcher personnalisée | ✅ `flutter_launcher_icons.yaml` |
| Icône notification | ❌ Manquante |
| Lottie animations | ✅ |
| Assets multilingues (ar/en/fr) | ✅ |

### Contenu / Policies
| Test | Statut |
|---|---|
| Contenu adulte | ✅ Non (app de pêche) |
| Contenu violent | ✅ Non |
| Données utilisateur collectées | 🟡 Email + localisation (nécessite Privacy Policy) |
| Achats in-app | 🟡 Abonnements premium (nécessite Privacy Policy + ToS) |

---

## 📝 PROCHAINES ÉTAPES (ORDRE PRIORITAIRE)

### Étape 1 — Obligatoire pour Play Console
1. **Créer une Privacy Policy** — héberger sur GitHub Pages ou Firebase Hosting, ajouter le lien dans:
   - Fiche Play Console (section "Confidentialité")
   - Page Settings de l'app
2. **Créer icône de notification** — `android/app/src/main/res/`
3. **Remplir la fiche Play Console** : description, captures d'écran, classification par âge

### Étape 2 — Build & Test
```bash
flutter clean
flutter pub get
flutter build appbundle --release
flutter build apk --release
```
Tester l'APK sur device physique Android 8+.

### Étape 3 — Optimisations (optionnel)
1. Supprimer `android.newDsl=false` et `android.builtInKotlin=false` de `gradle.properties`
2. Nettoyer `debugPrint` résiduels
3. Supprimer `lib/_backup_premium/` et fichiers `.bak`

---

## 🎯 VERDICT FINAL

**✅ PRÊT POUR SOUMISSION (après Privacy Policy)**

Les 3 bloqueurs critiques identifiés dans l'audit du 28/06/2026 ont été corrigés :
- Package renommé `com.zagorito.spots_app`
- Signature release avec keystore
- ProGuard/R8 activé

Actions restantes rapides (~1h) :
1. Rédiger une Privacy Policy
2. Ajouter l'icône de notification
3. Builder l'AAB

---

*Rapport généré le 05/07/2026 — Audit Play Console V2*