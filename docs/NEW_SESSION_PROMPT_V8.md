# Prompt de reprise — nouvelle session BoosterFish V+8

**Mis à jour le 31 juillet 2026 après validation réelle Google Play / App Check.**

Copier-coller intégralement le texte ci-dessous dans une nouvelle session.

```text
Nous reprenons BoosterFish dans une nouvelle session parce que la session
précédente était saturée et renvoyait parfois « Selected model is at capacity ».
Ce n'est pas un nouveau projet. Ne recommence pas l'audit et ne refais pas les
corrections déjà validées.

Projet local :
/Users/salimben/Desktop/Projets/spots_app

Avant toute action, lis intégralement et dans cet ordre :
1. AGENTS.md
2. docs/SESSION_HANDOFF_V8_2026-07-31.md
3. docs/releases/1.0.5-8-evidence.md
4. docs/GOOGLE_PLAY_RELEASE_CHECKLIST.md
5. ce prompt

En cas de divergence historique, l'addendum final du dossier de passation,
docs/releases/1.0.5-8-evidence.md et ce prompt décrivent l'état le plus récent.

==============================
1. SOURCE DE VÉRITÉ ACTUELLE
==============================

- Application : BoosterFish
- package Android : com.zagorito.spots_app
- candidate testée : 1.0.5 (versionCode 8), aussi appelée V+8
- branche : main
- HEAD local au dernier contrôle : b1a6fc3
- main est en avance de 7 commits sur origin/main
- aucun push GitHub de ces 7 commits n'a été autorisé ni réalisé
- avant cette mise à jour documentaire, seul le sous-dépôt utilisateur
  spots_app_temp était marqué dirty ; il est hors périmètre et ne doit jamais
  être touché
- si la mise à jour n'a pas encore été commitée, les deux fichiers
  docs/NEW_SESSION_PROMPT_V8.md et
  docs/SESSION_HANDOFF_V8_2026-07-31.md apparaîtront aussi modifiés ; ce sont
  uniquement les documents de passation, pas du code applicatif
- code de la candidate AAB : commit d3a0617
- AAB :
  build/app/outputs/bundle/release/app-release.aab
- SHA-256 AAB :
  81a04e72609b447e6014409fec45274b073fa79496abbe1f4b5c839bb22e86c5
- catalogue chiffré : 6 365 spots officiels
- projet Firebase / Google Cloud correct : spots-app-salim
- numéro de projet : 68722970471
- application Firebase Android :
  1:68722970471:android:22dce79885650fc112e9c2

Ne confonds jamais :
- le certificat de clé d'importation Play ;
- le certificat de signature d'application Google Play ;
- le SHA-256 du fichier AAB.

Certificat de signature réellement mesuré sur l'APK installé depuis Google
Play :
6C:B8:0F:3A:2D:40:50:79:7F:D5:DC:36:93:08:6D:7E:D0:7F:D3:61:9E:CF:35:AA:44:20:55:F5:E3:8C:EE:47

==============================
2. CE QUI EST TERMINÉ ET VALIDÉ
==============================

La version 1.0.5 (8) a été installée depuis Google Play sur un Samsung SM_A037F
et les contrôles ont confirmé :
- installateur : com.android.vending ;
- version : 1.0.5 (8) ;
- boot Android vérifié, appareil verrouillé et build système release ;
- certificat de signature Google Play conforme à la valeur ci-dessus.

Le défaut de publication Communauté a été reproduit et diagnostiqué à partir
des journaux du processus BoosterFish :
- la demande Play Integrity partait correctement ;
- Play Integrity répondait ;
- Firebase App Check refusait l'attestation avec
  « 403 App attestation failed », puis « Too many attempts ».

Cause exacte :
l'empreinte SHA-256 enregistrée dans Firebase ressemblait au certificat Play
mais contenait deux erreurs de caractères :
- d07e au lieu de d07f ;
- 2055e5 au lieu de 2055f5.

Correction externe déjà réalisée :
l'empreinte Play correcte a été ajoutée de manière non destructive à
l'application Firebase Android. L'ancienne empreinte erronée n'a pas été
supprimée. Aucun changement du code Flutter ni nouvel AAB n'a été nécessaire.

Résultat final déjà validé manuellement :
- démarrage à froid de l'installation Google Play ;
- nouvelle demande et réponse Play Integrity ;
- absence de 403 App attestation failed ;
- absence de Too many attempts ;
- publication Communauté réussie.

Ne rouvre donc pas ce diagnostic et ne modifie pas App Check si cette erreur ne
réapparaît pas sur une installation Google Play authentique.

Les corrections fonctionnelles suivantes existent et doivent être préservées :
- démarrage de la carte en satellite ;
- zoom à deux doigts conservé ;
- outil de mesure, compteur temps réel centré au-dessus de la recherche et X ;
- fermeture cohérente du panneau spot, du vent et des outils ;
- favoris limités à 30 ;
- spots personnels limités à 30, visibles immédiatement et copiés en
  arrière-plan pour modération sans le révéler à l'utilisateur ;
- marqueurs personnels bleu marine ;
- raccourci vers la carte, Modifier et Supprimer sous forme d'icônes ;
- panneau de détails lisible et défilable ;
- sélecteur Communauté / Mes prises modernisé ;
- galerie privée limitée à 20 photos ;
- photo limitée à 2 Mio et normalisée en JPEG ;
- poids en kg ;
- publication publique limitée selon les règles produit, durée 7 jours ;
- likes, signalement, blocage et retrait de sa propre publication ;
- règles Firestore et fonctions de modération durcies ;
- pages légales HTTPS et suppression de compte ;
- build signé et verrou Gradle exigeant au moins 6 000 spots officiels.

Les preuves détaillées de build, tests et validation Play sont dans :
docs/releases/1.0.5-8-evidence.md

==============================
3. BLOCAGE / DÉBLOCAGE DES PÊCHEURS
==============================

État réel du code :
- le blocage d'un pêcheur existe déjà ;
- community_blocks/{currentUid}/users/{blockedUid} est utilisé ;
- le feed masque les publications des pêcheurs bloqués ;
- Firestore autorise déjà au propriétaire de supprimer son document de blocage ;
- les tests de conformité couvrent le blocage et le signalement.

Le déblocage n'est pas encore exposé par une interface utilisateur.
Décision produit prise :
- il pourra être ajouté plus tard dans
  Profil > Confidentialité/Communauté > Pêcheurs bloqués ;
- bouton Débloquer avec confirmation ;
- aucune notification au pêcheur bloqué ;
- liste de blocage privée ;
- déblocage par suppression idempotente du document Firestore ;
- rafraîchissement du feed après déblocage.

Ce travail futur est isolé et à faible risque. Il n'est pas considéré comme un
blocage connu de la production actuelle, car le blocage et le signalement
obligatoires pour l'UGC sont déjà présents. Ne l'implémente pas sans demande
explicite.

==============================
4. DERNIÈRE TÂCHE : COMPTE REVIEWER
==============================

La dernière demande était de savoir si l'adresse e-mail du compte reviewer peut
être changée. La réponse est oui, dans Play Console :
Règles et programmes > Contenu de l'application > Informations de connexion >
Gérer > modifier le compte reviewer.

Cette modification Play Console :
- ne demande aucun changement du code ;
- ne demande aucun nouvel APK/AAB ;
- doit utiliser un compte Firebase Authentication réel et durable ;
- doit être testée sur la version installée depuis Google Play ;
- doit permettre d'accéder à toutes les fonctions restreintes ;
- ne doit exiger ni 2FA, ni OTP, ni mot de passe temporaire ;
- doit contenir des instructions simples en anglais ;
- ne doit jamais conduire à écrire l'adresse, le mot de passe ou un jeton dans
  Git, les rapports ou ce prompt.

État non confirmé :
l'utilisateur n'a pas encore confirmé dans cette session que la nouvelle
adresse reviewer a été créée, testée et enregistrée. Considère donc cette tâche
comme MANUELLE ET À CONFIRMER, pas comme terminée.

Exemple d'instruction anglaise sans identifiants :
“Use the credentials above to sign in. The account provides access to
Community, My Catches, Spots, Maps and all other restricted features.
No additional verification is required.”

==============================
5. RESTE À FAIRE AVANT PRODUCTION
==============================

Ne passe pas en production. Les tâches restantes doivent être distinguées des
corrections de code déjà terminées.

Manuel / validation :
1. Créer ou choisir le compte reviewer dédié.
2. Tester ses identifiants sur un appareil propre avec la version Google Play.
3. Enregistrer les nouvelles informations de connexion et les instructions en
   anglais dans Play Console.
4. Terminer la matrice manuelle sur l'installation Play :
   - connexion/déconnexion ;
   - suppression de compte ;
   - favori ;
   - création/modification/suppression d'un spot personnel ;
   - photo de spot ≤ 2 Mio et persistance après relance ;
   - publication Communauté, déjà validée une fois ;
   - like depuis un second compte ;
   - signalement ;
   - blocage ;
   - retrait par l'auteur ;
   - compteur de likes, poids en kg et meilleure prise.
   Ne déclare réussi que ce qui possède une confirmation ou une preuve.
5. Vérifier Crashlytics, Android Vitals et le rapport de pré-lancement.
6. Relire et finaliser dans Play Console :
   - Sécurité des données ;
   - annonces et identifiant publicitaire AdMob ;
   - cible et contenu ;
   - classification UGC et contenu en ligne ;
   - informations de connexion ;
   - confidentialité et suppression de compte ;
   - catégorie Sports ;
   - application gratuite sans Play Billing.
7. Refaire les éléments de la fiche devenus obsolètes après le changement de
   thème :
   - captures téléphone ;
   - captures tablette réellement pertinentes ;
   - image de présentation 1 024 × 500 ;
   - vidéo YouTube si elle est conservée.
8. Choisir la disponibilité par pays/régions.
9. Retirer ou remplacer http://www.boosterfish.com tant que le site n'est pas
   réellement opérationnel en HTTPS.
10. Vérifier abonnement Open-Meteo, secret distant, fraîcheur Firestore et
    dernière exécution automatique planifiée.
11. N'envisager la production qu'après une validation manuelle complète sans
    crash, ANR ni défaut bloquant.

Firebase App Check :
- le fournisseur Play Integrity est enregistré ;
- la bonne empreinte Play SHA-256 est enregistrée ;
- la publication Communauté fonctionne depuis Google Play ;
- ne supprime pas l'ancienne empreinte dans une session de finition ;
- ne durcis pas l'enforcement de façon brutale ;
- toute activation future doit être progressive et précédée d'une vérification
  des métriques et des parcours.

==============================
6. RÈGLES DE NON-RÉGRESSION
==============================

- Ne lance jamais flutter run directement.
- Pour lancer/réinstaller : tools/run_app.sh.
- Pour un build Play : tools/build_release.sh.
- Pour les tests nécessitant le catalogue :
  flutter test --dart-define-from-file=.env
- Avant chaque téléversement, installer la même Release sur appareil physique
  et suivre docs/GOOGLE_PLAY_RELEASE_CHECKLIST.md.
- Après téléversement interne, réinstaller depuis Google Play et tester App
  Check, publication, like, signalement, blocage et retrait.
- Ne touche pas aux clés, au catalogue chiffré, aux règles Firestore ou au
  backend sans défaut reproduit et demande explicite.
- Ne modifie pas la sélection accidentelle d'un spot pendant le pinch-zoom :
  ce point est volontairement différé jusqu'à une plainte testeur.
- Ne touche pas à spots_app_temp.
- Aucun git reset --hard, checkout destructif ou suppression large.
- Ne pousse pas GitHub sans autorisation explicite.
- Ne publie ni ne promeus une release sans confirmation explicite.
- Toute correction doit être minimale, testée et documentée.

==============================
7. RÉPONSE ATTENDUE AU DÉBUT DE LA NOUVELLE SESSION
==============================

Après lecture, ne demande pas de renvoyer tout l'historique. Réponds avec :
1. un état précis séparant :
   - terminé dans le code ;
   - validé localement ;
   - validé depuis Google Play ;
   - manuel Play Console restant ;
   - différé volontairement ;
2. la prochaine action unique recommandée ;
3. ses risques ;
4. la confirmation que le code ne sera pas modifié sans demande explicite ou
   défaut reproductible.

La prochaine action normale est :
finaliser et tester le compte reviewer dédié dans Play Console, puis reprendre
la checklist manuelle restante une étape à la fois. Ne reconstruis pas V+8
uniquement pour changer l'e-mail reviewer.

Si « Cette action n'est pas autorisée » ou « vérification de sécurité
momentanément indisponible » réapparaît, ne modifie pas immédiatement le code.
Note l'appareil, la version, l'installateur, le compte, l'heure, l'action et le
message exact, puis vérifie les journaux App Check/Play Integrity et la source
d'installation.
```

## Consigne de continuité

La nouvelle session doit s'appuyer sur le dépôt et les documents locaux. Une
erreur de capacité du modèle n'autorise ni la réinitialisation du projet, ni la
répétition des corrections, ni une modification non demandée.
