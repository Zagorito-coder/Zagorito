# 🔧 AUDIT SPOTSAPP — Correctifs classés par risque d'impact fonctionnel

**Contexte :** Test interne Play Console en cours. L'objectif est de ne **pas casser** le build actuel.

---

## 🟢 CATÉGORIE A — Zéro impact sur le code applicatif (Firebase Console uniquement)

Ces correctifs ne touchent **aucune ligne de code**. Aucun risque de régression.

| # | Vulnérabilité | Action | Où |
|---|--------------|--------|-----|
| 1 | Clé API Firebase exposée | Restreindre la clé Android par package name + SHA-1 | Firebase Console → APIs & Services → Credentials → API Key Android → Application restrictions → Package `com.zagorito.spots_app` + SHA-1 du keystore release |
| 1b | Authentification non restreinte | N'autoriser que les SHA-1 de tes keystores | Firebase Console → Authentication → Sign-in method → Android → Ajouter SHA-1/SHA-256 release + debug |
| 4 | Firestore `spots_meteo` public | Modifier la règle `allow read: if request.auth != null;` | `firestore.rules` — push via `firebase deploy --only firestore:rules` |
| 5b | Clients OAuth Google mal configurés | Vérifier que seuls Android + iOS sont activés | Firebase Console → Authentication → Sign-in providers → Google → Ne garder que les clients Android/iOS |

**IMPORTANT pour le #4 :** Si tu actives `request.auth != null` sur `spots_meteo`, vérifie que le `WindguruPage` / `ForecastFirestoreService` a bien un utilisateur authentifié avant de lire Firestore. Actuellement `forecast_firestore_service.dart` utilise `FirebaseFirestore.instance` sans vérifier l'auth. Si l'utilisateur n'est pas connecté, la règle bloquera la lecture et le fetch échouera → **à tester absolument avant de déployer la règle Firestore**. Voir Catégorie B pour le correctif code.

---

## 🟡 CATÉGORIE B — Impact code faible, testable rapidement

Ces correctifs touchent le code mais avec un risque de régression quasi nul. Un smoke test de 5 minutes suffit.

| # | Fichier | Changement | Risque | Test à faire |
|---|---------|-----------|--------|-------------|
| **3** | `lib/providers/premium_provider.dart:13-17` | Garder `_forcePremium` uniquement en mode debug : `bool get isPremium => (kDebugMode && _forcePremium) \|\| (_subscription?.hasPremiumAccess ?? false);` | **Nul.** Ajout d'une condition `kDebugMode`. En release, `_forcePremium` sera toujours `false` quoi qu'il y ait dans les SharedPreferences. | Vérifier que les features premium fonctionnent normalement avec un compte connecté premium |
| **6** | `lib/main.dart:38-39` | Désactiver aussi `print` en release. Ajouter après `debugPrint = ...` : `if (!kDebugMode) { Zone.current.run(() => ...); }`. Alternative plus simple : remplacer tous les `debugPrint` de données sensibles (uid, email) par un logger qui n'écrit qu'en debug. | **Nul.** Ne change que les logs. | Vérifier que l'app ne crash pas au démarrage |
| **8** | `lib/services/auth_service.dart:109-120` | Remplacer `SharedPreferences` par `flutter_secure_storage` pour `anonymous_user_id` | **Très faible.** `flutter_secure_storage` a une API similaire. Ajouter la dépendance dans `pubspec.yaml`. | Vérifier que l'ID anonyme persiste entre les lancements. Si le secure storage échoue (appareil rooté), prévoir un fallback `SharedPreferences` |
| **10** | `android/app/proguard-rules.pro` | Remplacer `-keep class com.google.firebase.** { *; }` par `-keep class com.google.firebase.** { public *; }` | **Faible.** ProGuard plus restrictif sur Firebase. Si une classe non-publique est utilisée par réflexion, crash. | Build APK release, tester l'auth Google + Firestore. Si crash, revert une règle spécifique |
| **14** | `analysis_options.yaml` | Ajouter des règles de lint | **Nul.** Ce sont des avertissements statiques. | `flutter analyze` ne doit pas avoir de nouvelles erreurs bloquantes |

### Détail du correctif #4 + #B (Firestore rules + code)

Si tu actives `request.auth != null` dans `firestore.rules` pour `spots_meteo`, il faut aussi adapter le code pour gérer le cas où l'utilisateur n'est pas connecté :

**Analyse :** Actuellement, dans `forecast_firestore_service.dart`, les reads Firestore se font sans vérifier l'état d'authentification. Si la règle devient `request.auth != null`, un utilisateur non connecté recevra une `FirebaseException: PERMISSION_DENIED`.

**Action à faire en même temps que le #4 :**
1. Dans `ForecastFirestoreService`, wrapper les reads avec `try { ... } on FirebaseException catch (e) { if (e.code == 'permission-denied') return null; }`
2. Dans `WindguruPage`, afficher un message "Connectez-vous pour voir les prévisions" si les données sont null à cause d'un permission-denied.

→ Ce correctif combiné demande un **test fonctionnel complet du flow Windguru** (connecté + non connecté).

---

## 🟠 CATÉGORIE C — Impact code modéré, nécessite tests dédiés

Ces correctifs modifient des flux critiques (auth, subscription, chiffrement). Un test sur les 3 scénarios (offline, online, premium, free) est nécessaire.

| # | Fichier | Changement | Risque | Test à faire |
|---|---------|-----------|--------|-------------|
| **5** | `lib/services/auth_service.dart:72-74` | Ajouter `accessToken: googleAuth.accessToken` dans `GoogleAuthProvider.credential(...)` | **Modéré.** La signature actuelle `credential(idToken: ...)` fonctionne. Ajouter l'accessToken peut renforcer la vérification mais ne cassera pas le flux existant. Firebase Auth acceptera la forme à 1 ou 2 params. | Tester sign-in Google sur Android + iOS. Si le sign-in échoue avec "invalid credential", retirer l'accessToken |
| **7** | `lib/services/subscription_service.dart:55-60` | Remplacer `return SubscriptionModel.newUser(userId)` en fallback par `return SubscriptionModel.free(userId)` | **Modéré.** Si Firestore est down, les users premium légitimes perdront temporairement leur accès. Le fallback free est plus sûr que de donner un trial gratuit, mais peut frustrer les vrais premium si Firestore est instable. | **Scénario 1 :** Mode avion → lancer l'app → doit être en mode free. **Scénario 2 :** Réactiver réseau → l'app doit restaurer le statut premium automatiquement (via le stream Firestore existant) |
| **13** | `assets/` + `pubspec.yaml` | Chiffrer `shops.csv`, `fish_data.json`, `peche_*.csv` comme `spots.csv.enc` | **Modéré.** Ré-encrypter avec le même script Python `tools/encrypt_spots.py` et modifier `ShopService`, `SpeciesService`, `TechniqueService`, `FishProvider` pour déchiffrer au chargement. Impacte 4-5 fichiers de service. | Charger l'app → vérifier que les shops, espèces, techniques, poissons s'affichent correctement dans toutes les langues |

---

## 🔴 CATÉGORIE D — Impact code élevé, demande refonte partielle

Ces correctifs touchent l'architecture même. **À planifier pour la V2, pas pour le test interne actuel.**

| # | Fichier | Changement | Risque | Pourquoi attendre |
|---|---------|-----------|--------|------------------|
| **2** | `lib/services/spot_service.dart:53` | Déplacer la clé AES dans `flutter_secure_storage` ou `.env` | **Élevé.** La clé est hardcodée dans un `static const`. La déplacer dans le secure storage ou `.env` change le flux de chargement des spots (async init nécessaire avant tout accès). Le `SplashBootstrap` actuel charge les spots de manière séquentielle. | Le chiffrement actuel est une protection de base (l'APK reste extractible). Pour la V2, migrer vers un chiffrement côté serveur avec clé par utilisateur. La version actuelle est acceptable pour un test interne. |
| **9** | `android/app/build.gradle.kts` | Empêcher la distribution d'APK debug | **Élevé sur le process, pas sur le code.** Juste un changement de workflow CI/CD. | Pas de changement de code, mais nécessite de valider le pipeline de build release |
| **11** | `ios/Runner/Info.plist` | Vérifier ATS | **Faible.** Juste une vérification. Si `NSAllowsArbitraryLoads` n'est pas présent, iOS bloque déjà les connexions HTTP non-sécurisées par défaut. | Le fichier Info.plist est déjà en place et fonctionnel |
| **12** | `pubspec.yaml` | Épingler les versions exactes (enlever `^`) | **Très élevé.** Peut casser la résolution de dépendances si des sous-dépendances sont incompatibles. | Le `pubspec.lock` commité protège déjà. Attendre la V2. |
| **15** | Projet | Ajouter `flutter_jailbreak_detection` | **Élevé.** Peut empêcher le lancement sur certains appareils de test (rootés par les testeurs). | À activer uniquement en production après avoir prévenu les testeurs |
| **16** | `lib/services/dio_tile_provider.dart` | Certificate pinning | **Élevé.** Si le certificat tourne côté serveur (Let's Encrypt tous les 90 jours), l'app cassera pour tous les utilisateurs sans mise à jour. | Nécessite une stratégie de rotation de clés + kill switch |

---

## 📊 PRIORISATION POUR LE TEST INTERNE ACTUEL

### ✅ À FAIRE MAINTENANT (aucun risque code)

| Ordre | Action | Effort |
|--------|--------|--------|
| 1 | Restreindre la clé API Firebase Android dans GCP Console | 5 min |
| 2 | Restreindre l'auth Android aux SHA-1 de tes keystores dans Firebase Console | 5 min |
| 3 | Vérifier les clients OAuth Google dans Firebase Console (désactiver Web si non utilisé) | 2 min |

### ✅ À FAIRE CETTE SEMAINE (risque faible, 1 test chacun)

| Ordre | Action | Effort | Fichier modifié |
|--------|--------|--------|-----------------|
| 4 | `_forcePremium` conditionné à `kDebugMode` | 5 min | `premium_provider.dart` |
| 5 | Ajouter `accessToken` dans `GoogleAuthProvider.credential` | 2 min | `auth_service.dart` |
| 6 | Remplacer `print` par `debugPrint` + désactiver logs en release | 15 min | `main.dart` |
| 7 | `anonymous_user_id` → `flutter_secure_storage` | 20 min | `auth_service.dart` |

### ⚠️ À TESTER AVEC PRÉCAUTION (risque modéré)

| Ordre | Action | Test obligatoire |
|--------|--------|-----------------|
| 8 | `firestore.rules` → `request.auth != null` sur `spots_meteo` | Tester Windguru connecté + déconnecté |
| 9 | `subscription_service.dart` fallback → free au lieu de trial | Tester offline/online avec compte premium |
| 10 | `proguard-rules.pro` → affiner les `-keep` Firebase | Build release + smoke test complet |

### 🔮 POUR LA V2 (refonte)

| Ordre | Action |
|--------|--------|
| 11 | Clé AES → serveur ou secure storage |
| 12 | Chiffrer tous les CSV dans l'APK |
| 13 | Certificate pinning |
| 14 | Root/jailbreak detection |
| 15 | Versions exactes dans pubspec.yaml |

---

## ⚡ RÉSUMÉ VISUEL

```
                    ┌─────────────────────────────────┐
                    │ ZÉRO RISQUE (Firebase Console)   │
                    │ ✅ #1, #1b, #4(rules), #5b      │
                    │ → Faire immédiatement            │
                    └─────────────────────────────────┘
                                      │
                    ┌─────────────────────────────────┐
                    │ RISQUE FAIBLE (code, 5-15 min)   │
                    │ ✅ #3, #5, #6, #8, #10, #14     │
                    │ → Faire cette semaine            │
                    └─────────────────────────────────┘
                                      │
                    ┌─────────────────────────────────┐
                    │ RISQUE MODÉRÉ (test dédié)       │
                    │ ⚠️ #4(code), #7, #13             │
                    │ → Faire avant prochaine release  │
                    └─────────────────────────────────┘
                                      │
                    ┌─────────────────────────────────┐
                    │ RISQUE ÉLEVÉ (refonte V2)        │
                    │ 🔮 #2, #9, #11, #12, #15, #16   │
                    │ → Planifier pour la V2           │
                    └─────────────────────────────────┘