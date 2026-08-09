# Base stable officielle — BoosterFish

Dernière validation : 9 août 2026

## Référence fonctionnelle

- Version : `1.0.6+14`
- Commit testé : `bad3d9debfe94f7d7e1f3f57ce680cabec58f11e`
- Tag immuable : `stable/boosterfish-1.0.6-14-play-validated`
- Branche Release : `release/closed-test-readiness-20260808`
- Branche des prochaines fonctionnalités : `develop/next-release-20260809`
- SHA-256 de l'AAB validé :
  `af28ce8ddd7e6ff241dc76b35e13af3a57362157f3fddad49ddf861264e0687a`

Cette référence correspond à l'AAB `1.0.6 (14)` installé depuis Google Play,
testé sur appareil physique et audité avant le premier examen Play Console.

## Contrôles de référence

- `flutter analyze` : aucune anomalie.
- `flutter test --dart-define-from-file=.env` : 160 tests réussis,
  1 test volontairement ignoré, 0 échec.
- Worktree Release propre, sans fichier modifié ou non suivi.
- Parcours Play installé validés : démarrage à froid, authentification,
  Play Integrity/App Check, spots personnels, prises privées, publication,
  like, signalement, blocage, retrait et suppression.
- Aucun crash ou ANR observé pendant la validation manuelle finale.

## Règles pour les prochaines mises à jour

1. Démarrer tout nouveau travail depuis
   `develop/next-release-20260809`, jamais depuis une ancienne branche de
   sauvegarde.
2. Ne pas modifier ou déplacer le tag stable.
3. Utiliser `tools/run_app.sh` pour installer l'application sur téléphone.
4. Utiliser `tools/build_release.sh` pour produire un APK ou un AAB Play.
5. Rejouer l'analyse, les tests et la checklist physique avant toute nouvelle
   promotion Play Console.

## Archives à ne pas utiliser comme base

La branche `backup/legacy-desktop-before-stable-20260809` conserve l'ancien
état local uniquement pour récupération. Elle n'est ni testée ni destinée à
recevoir de nouvelles fonctionnalités.

En cas de doute, revenir au tag
`stable/boosterfish-1.0.6-14-play-validated` et non à une branche `backup/*`.
