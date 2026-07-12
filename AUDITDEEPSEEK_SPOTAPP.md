# RAPPORT D'AUDIT — `spots_app`

**Date :** 19/06/2026  
**Analyseur :** DeepSeek / Cline  

---

## Classement : Critique → Faible

---

### 🔴 CRITIQUE — Plantages & Blocages

| # | Fichier | Problème | Impact |
|---|---|---|---|
| **1** | `lib/main.dart` + `lib/services/spot_service.dart` | **`SpotService` défini 2×** dans le même package — copie dans `main.dart` lignes 106-175 et une autre dans `services/spot_service.dart`. | ❌ **Erreur de compilation** `'SpotService' is already defined`. Le compilateur Dart refuse les duplications. |
| **2** | `lib/spot_finder_page.dart` | **Import de `main.dart`** : `import 'package:spots_app/main.dart'` — crée une dépendance circulaire (SpotFinderPage → MapScreen → main → SpotFinderPage si le barrel `pages/` un jour l'inclut). | ❌ **Risque d'import cyclique** = crash au runtime ou empêche la compilation. |
| **3** | `lib/providers/fish_provider.dart` (ligne 121) | `_isDisposed` check après `Isolate.run` — **race condition** : `notifyListeners()` peut être appelé après dispose si l'isolate termine après le démontage du widget. | ⚠️ **`Listenable was disposed`** → crash intermittent. |
| **4** | `lib/main.dart` ligne 672 | `_isPremium = false` stocké en **variable locale** alors que `PremiumProvider` existe dans le Provider tree — la variable n'est JAMAIS mise à jour, le zoom premium (`_maxZoom`) reste bloqué à 8.0. | ⚠️ **Fonctionnalité premium cassée** : impossible de dézoomer au-delà de 8. |

---

### 🟠 ÉLEVÉ — Bugs fonctionnels & Perf

| # | Fichier | Problème |
|---|---|---|
| **5** | `lib/providers/fish_provider.dart` | **Singleton + Provider = double injection**. `FishProvider()` factory retourne l'instance singleton, pas une nouvelle. Le `ChangeNotifierProvider(create: (_) => FishProvider())` crée une instance inutile. Tous les widgets utilisent `FishProvider.instance`. |
| **6** | `lib/providers/premium_provider.dart` | **`toggle([bool? value])`** : paramètre nullable optionnel → `toggle()` sans argument = null ≠ `_isPremium` donc bascule vrai → `toggle(false)` échoue car `null == false` est false. Comportement imprévisible. |
| **7** | `lib/main.dart` (_MapScreenState) | **État monolithique** : ~20 champs d'état (`_selectedSpot`, `_currentZoom`, `_searchQuery`, `_heading`, etc.) dans un seul `setState`. **Chaque setState rebuild l'intégralité du widget** → ralentissements sur 6200 spots. |
| **8** | `lib/spot_details_panel.dart` lignes 61-73 | **`_getNearbySpots()` recalcule les distances sur TOUS les spots à chaque build** — pas de mémoization. Pour 6200 spots = 6199 calculs de distance à chaque ouverture. |
| **9** | `lib/main.dart` lignes 43-45 | `debugPrint = (String? message, ...) {}` en release — **supprime tous les logs** (y compris erreurs utiles comme celles de `SpotService`). |

---

### 🟡 MOYEN — Propreté & Architecture

| # | Fichier | Problème |
|---|---|---|
| **10** | `lib/theme.dart` (ThemeColors) | `factory ThemeColors.of(BuildContext)` **n'utilise pas le context** → lit `ThemeController.instance.isDark` directement. Si le theme change sans `ListenableBuilder`, les couleurs restent bloquées. |
| **11** | `lib/app_shell.dart` | **`_NavItem` recrée les labels à chaque build** avec ternaire `LanguageController.instance.langCode == 'en'` — ignore la localisation existante (`context.tr()`). |
| **12** | `lib/widgets.dart` (_WavePainter) | **`shouldRepaint` retourne `false`** → la vague ne se redessine jamais si la taille change. |
| **13** | `lib/cluster_index.dart` | **Fichier poubelle** : classe vide avec des commentaires. Supprimer ou mettre dans `.gitignore`. |

---

### 🟢 FAIBLE — Cosmétique & Style

| # | Fichier | Problème |
|---|---|---|
| **14** | `lib/widgets.dart` (AnimatedCounter) | `TweenAnimationBuilder(begin:0, end:1)` — ne s'anime qu'à l'insertion, pas aux mises à jour du compteur. |
| **15** | `lib/models.dart` | `location: LatLng(lat, lng)` enregistré en mémoire **en double** : `latitude`/`longitude` sont aussi stockés dans le `Spot` → redondance mémoire. |
| **16** | `pubspec.yaml` | `cached_network_image`, `flutter_map_animations`, `google_fonts` — dépendances installées mais **jamais utilisées** dans le code actuel. |

---

## RÉSUMÉ EXÉCUTIF

```
CRITIQUE : 4 (dont 1 plantage compilation + 1 crash runtime)
ÉLEVÉ   : 5 (perf, bugs fonctionnels)
MOYEN   : 4 (architecture)
FAIBLE  : 3 (cosmétique)
```

**Blocage immédiat** : `SpotService` dupliqué → empêche la compilation si les deux fichiers sont dans le package (résolution : supprimer la copie dans `main.dart`, importer `services/spot_service.dart`).