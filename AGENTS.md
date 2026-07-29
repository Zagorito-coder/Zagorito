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
