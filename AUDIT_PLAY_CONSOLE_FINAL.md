# 🧾 AUDIT PLAY CONSOLE — Spots App

**Date** : 28/06/2026  
**Version** : 1.0.0+1 (pubspec.yaml)  
**Package** : `com.example.spots_app`

---

## 📊 RÉSUMÉ EXÉCUTIF

| Critère | Verdict |
|---|---|
| **Score Global** | ⚠️ **NON PRÊT** (3 bloqueurs critiques) |
| 🔴 Blockers | 3 (doivent être fixés avant soumission) |
| 🟡 Warnings | 7 (doivent être fixés idéalement) |
| 💡 Recommandations | 6 (optimisations) |

---

## 🔴 PROBLÈMES CRITIQUES (BLOCKERS)

### 1. APK RELEASE SIGNÉ AVEC LA CLÉ DEBUG
**Fichier** : `android/app/build.gradle.kts` — ligne 35
```kotlin
release {
    signingConfig = signingConfigs.getByName("debug")
}
```
**Impact** : Google Play refusera l'App Bundle signé avec une clé debug.  
**Action** : Créer un keystore release et configurer la signature.

### 2. NOM DE PACKAGE INTERDIT `com.example`
**Fichier** : `android/app/build.gradle.kts` — ligne 25  
**Impact** : Google Play bloque tout package contenant `com.example`.  
**Action** : Renommer en `com.zagorito.spots_app` (ou équivalent).

### 3. PAS DE RÈGLES ProGuard / R8
**Fichier** : `android/app/build.gradle.kts` — section `buildTypes { release { } }`  
**Impact** : Aucune obfuscation, pas de minification du code. Vulnérabilité au reverse engineering + APK plus gros.  
**Action** : Ajouter `isMinifyEnabled = true` et un fichier `proguard-rules.pro`.

---

## 🟡 AVERTISSEMENTS

| # | Problème | Fichier | Détail |
|---|---|---|---|
| 1 | `.env` exposé dans l'APK | `pubspec.yaml:65` | Le fichier `.env` est déclaré comme asset → toutes les variables d'environnement (clés, tokens) sont lisibles dans l'APK. |
| 2 | `usesCleartextTraffic` non défini | `AndroidManifest.xml` | Par défaut true sur Android 9+. Ajouter `android:usesCleartextTraffic="false"`. |
| 3 | 5 dépendances directes majeures en retard | `pubspec.yaml` | `flutter_dotenv` 5.2.1→6.0.1, `geolocator` 12.0→14.0, `google_fonts` 6.3→8.1, `google_sign_in` 6.3→7.2, `latlong2` 0.9→0.10 |
| 4 | Aucune icône de notification | - | Pas d'icône `@mipmap/ic_notification` définie |
| 5 | `label="spots_app"` dans AndroidManifest | `AndroidManifest.xml:10` | Devrait être le nom lisible de l'application (ex: "Spots Pêche Côtière") |
| 6 | Pas de politique de confidentialité visible | - | Aucun lien vers une privacy policy dans l'app ou le repo |
| 7 | `sqflite_darwin` outdated (2.4.3→2.4.3+1) | `pubspec.lock` | Mise à jour mineure disponible |

---

## 💡 RECOMMANDATIONS

| # | Suggestion | Action |
|---|---|---|
| 1 | Mettre à jour `flutter_lints` 4.0.0→6.0.0 | `pubspec.yaml` → `flutter_lints: ^6.0.0` |
| 2 | Activer minify + shrinkResources | Ajouter `isMinifyEnabled = true` + `isShrinkResources = true` dans `buildTypes.release` |
| 3 | Ajouter un fichier `proguard-rules.pro` | Au minimum avec les règles Firebase : `-keep class com.google.firebase.** { *; }` |
| 4 | Nettoyer Gradle deps | Supprimer `android.newDsl=false` et `android.builtInKotlin=false` qui sont des flags de migration obsolètes |
| 5 | Ajouter Android App Bundle signing | Ajouter `signingConfig = signingConfigs.getByName("release")` dans buildTypes (après création keystore) |
| 6 | Nettoyer les fichiers de build résiduels | 27 fichiers `build_log*.txt` et `run_log*.txt` à la racine — ajouter `/build_log*.txt` et `/run_log*.txt` au `.gitignore` |

---

## 📋 CHECKLIST PLAY CONSOLE

- [ ] ❌ Signer l'AAB avec une clé release (pas debug)
- [ ] ❌ Renommer le package `com.example.spots_app`
- [ ] ❌ Configurer ProGuard/R8
- [ ] ❌ Retirer `.env` des assets pubspec.yaml
- [ ] ❌ Ajouter `android:usesCleartextTraffic="false"` dans AndroidManifest
- [ ] ❌ Ajouter une icône de notification
- [ ] ❌ Ajouter un lien vers la politique de confidentialité
- [ ] ❌ Créer l'App Bundle (.aab) avec `flutter build appbundle`
- [ ] ❌ Tester l'APK sur device physique Android 8.0+
- [ ] ❌ Activer Play App Signing sur la Play Console
- [ ] ❌ Remplir la fiche Store (description, captures d'écran, classification par âge)

---

## 📋 AUDIT TECHNIQUE DÉTAILLÉ

### Android / Gradle
| Paramètre | Valeur | Statut |
|---|---|---|
| minSdkVersion | 24 | ✅ ≥21, ≥24 recommandé |
| targetSdkVersion | 36 | ✅ Dernier requis (2026) |
| compileSdkVersion | 36 | ✅ |
| Gradle | 9.1.0 | ✅ Très récent |
| AGP | 9.0.1 | ✅ Très récent |
| Kotlin | 2.3.20 | ✅ Très récent |
| Java | 17 | ✅ |
| AndroidX | `true` | ✅ |
| 64-bit (arm64-v8a) | Automatique Flutter | ✅ |
| ProGuard/R8 | ❌ Absent | 🔴 |
| Signature release | Debug key | 🔴 |
| Keystore release | Aucun | 🔴 |

### Permissions
| Permission | Fichier | Justification |
|---|---|---|
| `INTERNET` | AndroidManifest.xml:4 | ✅ OpenStreetMap tiles |
| `ACCESS_FINE_LOCATION` | AndroidManifest.xml:6 | ✅ GPS spot distance |
| `ACCESS_COARSE_LOCATION` | AndroidManifest.xml:7 | ✅ Localisation approchée |
| Pas de `CAMERA` / `STORAGE` / `PHONE` | - | ✅ |
| `usesCleartextTraffic` | Non défini | 🟡 |

### Dépendances (pub outdated)
| Package | Actuelle | Dernière | Statut |
|---|---|---|---|
| `flutter_dotenv` | 5.2.1 | 6.0.1 | 🟡 Major |
| `geolocator` | 12.0.0 | 14.0.3 | 🟡 Major |
| `google_fonts` | 6.3.3 | 8.1.0 | 🟡 Major |
| `google_sign_in` | 6.3.0 | 7.2.0 | 🟡 Major |
| `latlong2` | 0.9.1 | 0.10.1 | 🟡 Major |
| `flutter_lints` | 4.0.0 | 6.0.0 | 🟡 Dev |

### Sécurité
| Test | Résultat |
|---|---|
| Secrets dans le code | 🔴 `firebase_options.dart` contient les apiKey Firebase (normal pour Firebase) |
| `.env` exposé dans assets | 🔴 Ligne 65 de pubspec.yaml — le fichier `.env` est embarqué dans l'APK |
| `debuggable=true` en release | ✅ Pas de `android:debuggable="true"` |
| `SharedUserId` | ✅ Absent |
| Obfuscation | 🔴 Aucune (pas de R8/ProGuard) |

### Code Flutter
| Test | Résultat |
|---|---|
| Null safety | ✅ SDK ≥3.0.0 activé |
| Gestion d'état | ✅ Provider |
| try/catch présents | ✅ Dans `loadSpots`, `initLocation`, `dotenv.load`, `Firebase.initializeApp` |
| `debugPrint` désactivé en release | ✅ Ligne 49 |
| `debugShowCheckedModeBanner` | ✅ false |

### Assets / Branding
| Test | Résultat |
|---|---|
| Icône launcher personnalisée | ✅ `flutter_launcher_icons.yaml` + `assets/launcher_icon.png` |
| Icône notification | ❌ Absente |
| Assets compressés | ✅ `.csv` et `.json` |
| Fichiers non utilisés | 🟡 27+ `build_log*.txt`, `build_out.txt`, etc. à la racine |

---

## 📝 PROCHAINES ÉTAPES (ORDRE PRIORITAIRE)

### Étape 1 — Corriger les 3 bloqueurs critiques
1. **Créer un keystore release** :
```bash
keytool -genkey -v -keystore %USERPROFILE%\upload-keystore.jks ^
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
2. Configurer `key.properties` :
```properties
storePassword=XXXX
keyPassword=XXXX
keyAlias=upload
storeFile=C:/Users/Salim/upload-keystore.jks
```
3. Modifier `android/app/build.gradle.kts` :
```kotlin
// Avant android {} :
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Dans buildTypes :
release {
    signingConfig = signingConfigs.create("release") {
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
    }
}
```
4. **Renommer le package** : `com.example.spots_app` → `com.zagorito.spots_app`
   - Modifier dans `android/app/build.gradle.kts` : `namespace` et `applicationId`
   - Modifier dans `AndroidManifest.xml`
   - Reconfigurer Firebase avec le nouveau package
5. **Activer R8** : Ajouter dans `android/app/build.gradle.kts` release :
```kotlin
release {
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    signingConfig = signingConfigs.getByName("release")
}
```
6. **Créer `android/app/proguard-rules.pro`** :
```
# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
```

### Étape 2 — Corriger les 7 warnings
1. **Ajouter `android:usesCleartextTraffic="false"`** dans `<application>` du `AndroidManifest.xml`
2. **Retirer `.env`** de la liste des assets dans `pubspec.yaml` (ligne 65)
3. **Ajouter icône de notification** : `@mipmap/ic_notification`
4. **Changer `android:label`** : `android:label="Spots Pêche Côtière"`
5. **Mettre à jour les dépendances majeures** : `flutter pub upgrade --major-versions` (après tests)
6. **Ajouter lien Privacy Policy** dans l'app (Settings page)
7. **Mettre à jour `sqflite_darwin`** : `flutter pub upgrade`

### Étape 3 — Build final
```bash
flutter clean
flutter pub get
flutter build appbundle --release
flutter build apk --release
```

---

## 📦 POIDS DES ASSETS (ESTIMÉ)

| Fichier | Taille approx. | Note |
|---|---|---|
| `sposts.csv.enc` | ~200 KB | Crypté ✅ |
| `shops.csv` | ~10 KB | OK |
| `peche_cotiere_database*.csv` | ~50 KB × 4 | Triplé (Ar/Fr/En) |
| `fish_data.json` | Variable | OK |
| Images techniques | Variable | OK |
| Animations Lottie | Variable | OK |
| **Total estimé** | **< 5 MB** | ✅ Bien < 150 MB |

---

## 🎯 VERDICT FINAL

**⚠️ NON PRÊT POUR PUBLICATION**

Raison principale : signature debug en release, nom de package `com.example` interdit, absence de protection R8.

Une fois ces 3 bloqueurs levés (≈ 30 minutes de travail), le projet pourra être buildé en `.aab` release et soumis.

---
*Rapport généré le 28/06/2026 — Audit Flutter Play Console v1.0*