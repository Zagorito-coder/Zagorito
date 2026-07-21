# BoosterFish

Application Flutter de spots et de conditions de peche cotiere.

## Configuration locale

1. Copier `.env.example` vers `.env`.
2. Renseigner `CSV_ENCRYPTION_KEY` avec une cle AES-256 encodee en Base64.

Sur Android, la configuration Google Sign-In est fournie par le fichier
Firebase `android/app/google-services.json` (à provisionner séparément dans
un clone ou une CI). Aucun identifiant Google supplémentaire n'est requis dans
`.env`.

Une nouvelle cle peut etre generee localement avec :

```sh
openssl rand -base64 32
```

Le fichier `.env` et la source `assets/spots.csv` sont ignores par Git. Seul
`assets/spots.csv.enc` est distribue avec l'application.

## Mettre a jour le catalogue des spots

Apres toute modification de `assets/spots.csv`, regenerer puis verifier
l'asset chiffre :

```sh
python3 tools/encrypt_spots.py
python3 tools/encrypt_spots.py --check
```

Le script utilise exclusivement la cle de `.env` ou la variable
`CSV_ENCRYPTION_KEY`. Il n'affiche jamais la cle et refuse toute cle absente ou
invalide.

## Build Release reproductible

Ne pas appeler directement `flutter build appbundle --release`, car la cle du
catalogue doit etre fournie au compilateur Dart. Utiliser :

```sh
tools/build_release.sh appbundle
```

Pour produire un APK Release :

```sh
tools/build_release.sh apk
```

Avant le build, le script confirme que la cle, le CSV chiffre et sa source
locale correspondent. Flutter recoit ensuite `.env` via
`--dart-define-from-file`.

## Verification courante

```sh
flutter analyze
flutter test
```
