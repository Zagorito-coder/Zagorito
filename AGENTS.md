# Instructions de travail locales

- Ne jamais lancer directement `flutter run` dans ce dépôt : le catalogue des
  spots est chiffré et exige les valeurs de `.env`.
- Pour lancer ou réinstaller l'application sur un appareil, toujours utiliser
  `tools/run_app.sh`, par exemple :
  `tools/run_app.sh --profile -d <device-id>`.
- Le script valide d'abord la configuration et le catalogue. En cas de fichier
  absent ou invalide, il s'arrête avant de remplacer l'application fonctionnelle
  déjà installée.
- Pour les builds Play Console, toujours utiliser `tools/build_release.sh`.
- Le verrou Gradle Android doit rester actif : il refuse tout APK/AAB sans clé
  valide, sans asset déchiffrable ou avec moins de 6 000 spots officiels.
- Pour contrôler aussi le déchiffrement du catalogue pendant les tests, utiliser
  `flutter test --dart-define-from-file=.env`.
- Avant chaque téléversement Play Console, installer la même version Release
  sur un appareil physique avec `tools/run_app.sh --release -d <device-id>` et
  valider manuellement le démarrage à froid, l'absence de crash/ANR et les
  parcours essentiels décrits dans `docs/GOOGLE_PLAY_RELEASE_CHECKLIST.md`.
- Une validation manuelle échouée bloque le téléversement. Après téléversement
  en test interne, réinstaller l'application depuis Google Play et valider aussi
  Play Integrity/App Check, la publication communautaire, le like, le
  signalement, le blocage et le retrait avant toute promotion.
