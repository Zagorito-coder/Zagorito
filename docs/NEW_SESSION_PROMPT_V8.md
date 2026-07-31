# Prompt de reprise — nouvelle session BoosterFish V+8

Copier-coller le texte ci-dessous dans une nouvelle session.

```text
Nous reprenons le projet BoosterFish dans une nouvelle session parce que la
session précédente était saturée et renvoyait parfois « Selected model is at
capacity ». Il ne s'agit pas d'un nouveau projet : le code et l'audit existent
déjà dans le dépôt local.

Projet :
/Users/salimben/Desktop/Projets/spots_app

Lis d'abord, intégralement, sans modifier aucun fichier :
1. AGENTS.md
2. docs/SESSION_HANDOFF_V8_2026-07-31.md
3. docs/releases/1.0.5-8-evidence.md
4. docs/GOOGLE_PLAY_RELEASE_CHECKLIST.md

Source de vérité actuelle :
- package Android : com.zagorito.spots_app
- version candidate : 1.0.5, versionCode 8
- branche : main
- HEAD local : 8c7b43e
- main est en avance de 4 commits sur origin/main
- seul le sous-dépôt spots_app_temp est marqué dirty ; il est hors périmètre et
  ne doit pas être touché
- l'AAB validé est :
  build/app/outputs/bundle/release/app-release.aab
- SHA-256 AAB :
  81a04e72609b447e6014409fec45274b073fa79496abbe1f4b5c839bb22e86c5

Objectif immédiat :
continuer la préparation pré-production de façon sûre, sans refaire l'audit et
sans impacter les fonctions déjà validées. La priorité est de valider la
version 1.0.5 (8) depuis Google Play Internal Testing, puis de finaliser les
actions manuelles Play Console. Ne passe pas en production.

État déjà corrigé et à préserver :
- démarrage carte satellite ;
- outils de mesure au-dessus de la barre de recherche avec compteur temps réel
  et bouton X ;
- nettoyage du panneau spot/vent/outils ;
- spots personnels visibles immédiatement, limite 30 ;
- favoris limités à 30 ;
- spots personnels avec copie de modération Firestore non révélée à l'utilisateur ;
- actions Modifier/Supprimer en icônes et accès direct à la carte ;
- détails de spots lisibles et défilables ;
- sélecteur Communauté / Mes prises modernisé (64 px, gradient, icônes, contraste) ;
- galerie privée de prises limitée à 20 images ;
- photo ≤ 2 Mio, publication publique limitée à une par 24 h et durée 7 jours ;
- poids en kg, likes, signalement, blocage et retrait de publication ;
- normalisation des photos (EXIF, redimensionnement, JPEG, contrôle de taille) ;
- bootstrap Firebase puis App Check/Play Integrity avant Crashlytics/navigation ;
- règles Firestore et fonctions de modération durcies ;
- pages légales HTTPS et suppression de compte ;
- build signé, catalogue chiffré avec 6 365 spots officiels ;
- tests locaux et installation Release physique déjà réalisés.

Ne fais pas les choses suivantes sans autorisation explicite :
- ne lance jamais `flutter run` directement ;
- utilise `tools/run_app.sh` pour installer/tester ;
- utilise `tools/build_release.sh` pour un build Play ;
- ne touche pas aux clés, au catalogue chiffré, aux règles Firestore ou au
  backend sans défaut reproduit ;
- ne modifie pas le comportement du pinch-zoom/sélection accidentelle : ce
  point a été volontairement différé jusqu'à une plainte testeur ;
- n'active pas l'enforcement App Check avant la validation de l'installation
  Google Play ;
- ne touche pas à spots_app_temp ;
- ne fais pas de git reset --hard, checkout destructif ou suppression large ;
- ne pousse pas GitHub sans me demander explicitement.

Après lecture, réponds avec :
1. un résumé de l'état réel en distinguant « terminé », « validé localement »,
   « à valider depuis Google Play » et « manuel Play Console » ;
2. la prochaine action unique recommandée ;
3. les risques associés ;
4. une confirmation que tu ne modifieras pas le code avant que je le demande ou
   qu'un défaut reproductible soit établi.

La prochaine action attendue est normalement :
- téléverser l'AAB 1.0.5 (8) en Test interne si ce n'est pas déjà fait ;
- installer la version depuis Google Play, pas par câble ;
- tester Play Integrity/App Check et la publication Communauté ;
- tester like avec un second compte, signalement, blocage, retrait, spots
  personnels, photos et relance ;
- consulter Crashlytics, Android Vitals et le rapport de pré-lancement.

Si un message « Cette action n'est pas autorisée » ou « vérification de sécurité
momentanément indisponible » apparaît, ne modifie pas immédiatement le code :
note la source d'installation, le compte, la version, l'heure et le message,
puis vérifie d'abord Play Integrity/App Check et les règles de distribution.

La qualité recherchée est la non-régression : chaque modification doit être
minimale, testée et documentée. La production ne sera envisagée qu'après la
validation manuelle complète et la finalisation des déclarations Google Play.
```

## Réponse attendue de la nouvelle session

La nouvelle session doit commencer par lire les documents et confirmer l'état,
pas par demander de renvoyer tout l'historique. Si elle rencontre une erreur de
capacité du modèle, elle doit continuer avec le modèle disponible et s'appuyer
sur ce dossier local ; l'erreur de capacité n'est pas une raison pour réinitialiser
le projet ou refaire les corrections.
