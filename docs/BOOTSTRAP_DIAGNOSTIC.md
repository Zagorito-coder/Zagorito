# Diagnostic démarrage lent & petits bugs — Spots App

> Analyse du pipeline `main → SplashBootstrap → AppShell` sans modification de fonctionnalité.

---

## 1. Pipeline de démarrage constaté

```text
main()
 ├─ await Firebase.initializeApp()                    (bloquant)
 ├─ SystemChrome.setSystemUIOverlayStyle()
 └─ runApp(SpotsApp)
     └─ SplashBootstrap (StatefulWidget)
         └─ _bootstrap()
             ├─ FMTCObjectBoxBackend.initialise()     (~100-500 ms 1er lancement)
             ├─ Création 3 stores FMTC                (si non ready)
             ├─ SpotService.loadFromCache()           (I/O + JSON parse)
             │   └─ fallback SpotService.loadFromCsv() si cache vide
             │       └─ SpotService.saveToCache()
             ├─ fishProvider.loadFishData()           (I/O + parse)
             ├─ 200 ms delay
             └─ pushReplacement(AppShell)
                 └─ AppShell index 3 = SpotFinderPage (MapScreen)
                     ├─ _loadSpots()  [RE-CHARGE depuis cache]
                     ├─ _initLocation()
                     ├─ _initPositionStream()
                     └─ écoute PremiumProvider
```

---

## 2. Causes probables de lenteur

### A. Initialisations bloquantes avant `runApp`

`lib/main.dart` :

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('[main] Firebase error: $e');
  }
  ...
  runApp(const SpotsApp());
}
```

- `Firebase.initializeApp` est exécutée avant le premier frame.
- Impact : écran blanc/noir jusqu'à ce que Firebase réponde.
- Solution non impactante : déplacer `Firebase.initializeApp` dans `SplashBootstrap._bootstrap` pour qu'elle soit couverte par l'écran de chargement.

### B. Double chargement des spots

1. `SplashBootstrap` charge et cparse les spots.
2. `MapScreen` (affiché par défaut dans `AppShell` index 3) recharge à nouveau `SpotService.loadFromCache()`.

Le cache JSON est relu deux fois. Sur 6200 spots cela représente un I/O + parse non négligeable.

**Recommandation :** garder le résultat du `_bootstrap` en mémoire statique ou passer la liste `spots` à `AppShell` → `SpotFinderPage` afin d'éviter la seconde lecture.

### C. `loadFishData()` non détaillé

`fishProvider.loadFishData()` est appelé dans le splash sans `compute`. Si `assets/fish_data.json` est volumineux, le parse s'exécute sur le thread UI. Vérifier l'utilisation de `compute()` ici.

### D. `await Future.delayed(Duration(milliseconds: 200))`

Ajoute artificiellement 200 ms avant navigation. C'est acceptable esthétiquement, mais c'est du temps perdu si le device est déjà rapide.

### E. `MapScreen` initialisé avec système UI immersive

```dart
void initState() {
  super.initState();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  _loadSpots();
  _initLocation();
  _initPositionStream();
  ...
}
```

- `immersiveSticky` cache barres système, ce qui peut causer un saut visuel au lancement.
- `_initPositionStream` démarre immédiatement la géolocalisation en continu (même si l'utilisateur n'est pas sur la carte activement).

---

## 3. Rebuilds / listeners redondants

| Fichier | Problème | Impact |
|---------|----------|--------|
| `main.dart` | `AnimatedBuilder` écoute `ThemeController` + `LanguageController` en haut de l'arbre | Rebuild entier de `MaterialApp` à chaque changement de thème/langue — acceptable mais non granulaire |
| `app_shell.dart` | `ListenableBuilder` sur `ThemeController` + `LanguageController` + `Visibility` pour chaque page | Maintient tous les widgets des 5 onglets en mémoire (`maintainState: true`) ; rebuild partiel mais présent |
| `home_page.dart` | `ListenableBuilder` merge `ThemeController` + `LanguageController` | Toute la `HomePage` rebuild quand la langue change |
| `home_page.dart` | `_buildMapPreviewCard` recrée 500 markers à chaque frame si `_spots` change | `displaySpots = _spots.take(500).toList()` alloue une nouvelle liste ; MarkerLayer sans `const` |
| `main.dart` `MapScreen` | `ListenableBuilder(LanguageController.instance)` entoure `_SearchBar`, le panel détail et le modal poisson | Rebuild de tout le overlay texte/langue à chaque changement de langue — correct fonctionnellement |
| `species_page.dart` | `LanguageController.instance.addListener` manuel + `ListenableBuilder` | Double abonnement ; pas de fuite car `removeListener` présent, mais redondant |
| `techniques_page.dart` | Idem `LanguageController.instance.addListener` manuel | Redondant |

### Points d'attention précis

- `LanguageController.instance` est un singleton global. L'utiliser via `ListenableBuilder` est correct, mais l'ajouter manuellement dans `initState()`/`dispose()` des pages est redondant avec les rebuilds déjà déclenchés par `ListenableBuilder` ou `AnimatedBuilder` parents.
- `MapScreen` écoute `PremiumProvider` dans `initState` mais n'appelle jamais `removeListener`. C'est une fuite de listener :

```dart
p.addListener(() {
  if (!mounted) return;
  setState(() { _isPremium = p.isPremium; _maxZoom = p.isPremium ? 16.0 : 8.0; });
});
```

Il faudrait stocker le listener et le retirer dans `dispose`.

- `_FishVerticalMenu` est un `StatelessWidget` qui reçoit `fishes` via `Consumer<FishProvider>`. Si `FishProvider` notifie fréquemment, le menu entier rebuild. Pas de fuite, mais potentiel de micro-freezes.

---

## 4. Petits bugs visibles / comportements

### 4.1 Splash affiche un spinner indéterminé au début

```dart
value: _progress > 0.0 ? _progress : null,
```

La progression reste à `0.0` jusqu'à ce que `_update('Initialisation...', 0.1)` soit appelé. L'utilisateur voit un spinner sans texte pendant quelques frames.

**Correction mineure :** initialiser `_status` avec un message et `_progress` à `0.05` dans `initState`.

### 4.2 AppShell démarre sur l'onglet 3 (Map)

```dart
int _currentIndex = 3;
```

Cela signifie que juste après le splash, la page carte lourde s'affiche immédiatement, avec `_loadSpots`, `_initLocation`, `_initPositionStream`. Si l'intention est de montrer Home en premier, c'est un bug d'UX.

**Note :** si le produit veut la carte en premier, ce n'est pas un bug, mais cela contribue au sentiment de lenteur.

### 4.3 `MapScreen` recharge les spots depuis le cache alors qu'ils viennent d'être chargés

Mentionné en B. C'est un bug de performance.

### 4.4 `_initPositionStream` en continu dès l'ouverture de la carte

La géolocalisation tourne en arrière-plan dès le lancement. Cela consomme la batterie et peut ralentir le premier rendu.

**Recommandation :** ne démarrer le stream qu'après un premier appui sur "Ma position" ou quand le GPS est réellement nécessaire.

### 4.5 Barre de recherche recrée constamment la liste des résultats

```dart
List<Spot> get _searchResults { ... _spots.where(...).toList(); }
```

`_searchResults` est recalculé à chaque `build`. La liste est passée à `_SearchBar`, qui crée un `ListView.builder` dessus. Cela fonctionne, mais les objets `List<Spot>` ne sont pas stablement identiques, ce qui empêche certaines optimisations de `ListView`.

### 4.6 `AppTileLayer` recrée un `FMTCTileProvider` à chaque build

```dart
@override
Widget build(BuildContext context) {
  final tileProvider = FMTCTileProvider(
    stores: Map.from({...}),
    ...
  );
  return TileLayer(... tileProvider: tileProvider);
}
```

`FMTCTileProvider` est recréé à chaque `build` de la carte. Même si c'est un objet léger, il pourrait invalider des connexions/cache internes.

**Recommandation :** mettre en cache le `FMTCTileProvider` par style dans un `Map<MapStyle, FMTCTileProvider>` initialisé une fois.

### 4.7 `dio_tile_provider.dart` — `StreamController` non `broadcast`

```dart
final chunkEvents = StreamController<ImageChunkEvent>();
```

Si `loadImage` est appelé plusieurs fois sur le même provider, le `StreamController` est recréé à chaque appel. Ce n'est pas une fuite immédiate car `finally` ferme le controller, mais si le stream est écouté plusieurs fois cela plantera (`Stream has already been listened to`).

**Note :** le fichier semble actuellement non utilisé car `AppTileLayer` utilise FMTC.

---

## 5. Fichiers inutilisés / morts

- `lib/services/dio_tile_provider.dart` : non importé dans `main.dart` ni `app_shell.dart`.
- `lib/main_original.dart` : fichier de backup historique.
- `lib/pages/splash_map_page.dart` : ancien splash, semble remplacé par `splash_bootstrap.dart`.

Ces fichiers n'affectent pas le démarrage mais alourdissent l'analyse.

---

## 6. Recommandations prioritaires (non impactantes)

1. **Déplacer `Firebase.initializeApp` dans `_bootstrap`** pour couvrir le temps d'attente par le splash.
2. **Transmettre la liste des spots** du `SplashBootstrap` à `AppShell`/`SpotFinderPage` pour éviter la double lecture JSON.
3. **Démarrer `_initPositionStream` à la demande**, pas dans `initState`.
4. **Corriger la fuite `PremiumProvider.addListener`** dans `MapScreen` en retirant le listener dans `dispose`.
5. **Initialiser `_status`/`_progress`** dans `SplashBootstrap.initState` pour éviter le spinner muet.
6. **Mettre en cache les `FMTCTileProvider`** par `MapStyle` dans `AppTileLayer`.
7. **Vérifier `FishProvider.loadFishData`** pour utiliser `compute` si le JSON est gros.
8. **Supprimer/rediriger `main_original.dart` et `dio_tile_provider.dart`** si confirmés inutiles.

---

## 7. Ordre d'intervention recommandé

1. Profilage avec DevTools (Startup / CPU) pour confirmer les points ci-dessus.
2. Corrections A/B/C (Firebase, double chargement spots, fish data).
3. Corrections listeners/fuites (PremiumProvider, LanguageController redondants).
4. Micro-optimisations UI (cache tile provider, status splash initial).
5. Nettoyage fichiers morts.
