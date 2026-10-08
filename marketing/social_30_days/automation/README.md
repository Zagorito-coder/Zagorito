# Automatisation Facebook + Instagram — guide clic par clic

Ce dossier publie les 30 Reels avec l'API officielle Meta. Le programme démarre toujours en **simulation**. Il ne publie réellement qu'avec l'option `--live`. Le journal SQLite empêche un doublon lorsqu'une tâche est relancée.

## Ce qui est automatisé

- choix de la vidéo et de la légende du jour ;
- publication sur la Page Facebook et le compte Instagram professionnel ;
- attente du traitement vidéo Instagram ;
- reprise séparée si une seule plateforme échoue ;
- journal des identifiants Meta et protection contre les doubles publications.

La musique de la bibliothèque Meta et la voix off ne peuvent pas être ajoutées automatiquement par ce flux. Les MP4 actuels sont des masters sans piste audio. Il faut donc publier silencieusement ou incorporer une voix/musique autorisée dans les fichiers avant d'activer `--live`.

## Phase 1 — vérifier les comptes dans Meta Business Suite

1. Ouvrir [Meta Business Suite](https://business.facebook.com/).
2. En haut à gauche, sélectionner l'entreprise qui possède la Page **BoosterFish**.
3. Cliquer sur **Paramètres** (roue dentée, en bas à gauche).
4. Cliquer sur **Comptes** puis **Pages**.
5. Cliquer sur la Page BoosterFish et vérifier que votre profil indique **Contrôle total**.
6. Cliquer sur **Comptes** puis **Comptes Instagram**.
7. Vérifier que le compte Instagram BoosterFish apparaît et qu'il est rattaché à la même entreprise.
8. S'il manque, cliquer **Ajouter** > **Connecter un compte Instagram**, se connecter, puis confirmer.
9. Dans Instagram mobile : **Profil** > menu `☰` > **Type de compte et outils**. Le compte doit être **Professionnel** (Entreprise ou Créateur), pas Personnel.

Ne pas continuer tant que la Page et Instagram ne sont pas visibles dans le même portefeuille professionnel.

## Phase 2 — créer l'application Meta

1. Ouvrir [Meta for Developers — Mes apps](https://developers.facebook.com/apps/).
2. Cliquer sur **Créer une app**.
3. Si Meta demande un cas d'usage, choisir celui qui permet de **gérer le contenu d'une Page et d'Instagram**. Selon l'interface affichée, ce choix peut être nommé **Autre** puis **Entreprise**.
4. Nom de l'app : `BoosterFish Social Publisher`.
5. Saisir l'adresse e-mail de contact.
6. Sélectionner le portefeuille professionnel qui possède BoosterFish.
7. Cliquer sur **Créer l'app** et confirmer le mot de passe/2FA.
8. Dans le tableau de bord de l'app, ajouter **Facebook Login for Business** et **Instagram API** lorsqu'ils sont proposés.

## Phase 3 — produire un jeton d'essai limité à vos comptes

1. Dans le menu de l'app, ouvrir **Outils** > **Explorateur de l'API Graph**. Si le menu n'apparaît pas, ouvrir directement [Graph API Explorer](https://developers.facebook.com/tools/explorer/).
2. En haut à droite, sélectionner l'app `BoosterFish Social Publisher`.
3. Cliquer sur **Générer un jeton d'accès** > **Obtenir un jeton d'accès utilisateur**.
4. Cocher exactement :
   - `pages_show_list`
   - `pages_read_engagement`
   - `pages_manage_posts`
   - `instagram_basic`
   - `instagram_content_publish`
5. Cliquer sur **Générer le jeton d'accès**.
6. Dans la fenêtre Facebook, sélectionner la Page BoosterFish et le compte Instagram BoosterFish, puis autoriser.
7. Dans la barre de requête, saisir `me/accounts?fields=id,name,access_token,instagram_business_account`.
8. Cliquer sur **Envoyer**.
9. Dans la réponse, repérer l'objet dont `name` vaut BoosterFish. Conserver localement :
   - `id` → `META_PAGE_ID` ;
   - `access_token` → `META_PAGE_ACCESS_TOKEN` ;
   - `instagram_business_account.id` → `META_IG_USER_ID`.

Ne jamais envoyer le jeton dans une capture d'écran, un e-mail ou une conversation. Il donne le droit de publier au nom de la Page.

## Phase 4 — rendre les MP4 accessibles à Instagram

Instagram télécharge chaque Reel depuis une URL HTTPS publique. Placer les 30 fichiers de `exports/reels/` dans un dossier dédié de votre stockage objet (Firebase Storage, Google Cloud Storage, Cloudflare R2 ou S3) et utiliser des URLs de lecture stables pendant toute la campagne.

1. Créer le dossier distant `social/2026-10/`.
2. Y téléverser les 30 MP4 sans modifier leur nom.
3. Ouvrir l'URL du premier MP4 dans une fenêtre privée.
4. Vérifier que la vidéo se charge sans connexion ni page intermédiaire.
5. Copier l'URL du dossier dans `PUBLIC_MEDIA_BASE_URL`.

Un lien Google Drive de partage ordinaire ne convient pas : Meta doit recevoir directement le fichier vidéo.

## Phase 5 — configurer et contrôler localement

Depuis la racine du projet :

```bash
cp marketing/social_30_days/automation/meta.env.example \
  marketing/social_30_days/automation/meta.env
```

Ouvrir `meta.env`, remplacer les quatre valeurs, puis exécuter :

```bash
python3 marketing/social_30_days/automation/meta_scheduler.py validate --require-secrets
python3 marketing/social_30_days/automation/meta_scheduler.py plan
python3 marketing/social_30_days/automation/meta_scheduler.py publish-day --day 1
```

La dernière commande doit afficher `[SIMULATION]`. Elle ne publie rien.

## Phase 6 — faire un seul test réel contrôlé

1. Choisir d'abord une plateforme :

```bash
python3 marketing/social_30_days/automation/meta_scheduler.py \
  publish-day --day 1 --platform instagram --live
```

2. Ouvrir Instagram et contrôler le cadrage, le texte, la lisibilité et le son.
3. Tester ensuite Facebook :

```bash
python3 marketing/social_30_days/automation/meta_scheduler.py \
  publish-day --day 1 --platform facebook --live
```

4. Consulter le journal :

```bash
python3 marketing/social_30_days/automation/meta_scheduler.py status
```

## Phase 7 — programmation automatique

Le calendrier fourni programme un Reel par jour du **1er au 30 octobre 2026 à 19 h 30, heure de Casablanca**. Pour changer le début ou l'heure :

```bash
python3 marketing/social_30_days/automation/build_schedule.py \
  --start 2026-10-01 --time 19:30 --timezone Africa/Casablanca
```

Pour un Mac qui reste allumé et connecté, copier le fichier `com.boosterfish.social.plist.example` vers `~/Library/LaunchAgents/com.boosterfish.social.plist`, puis charger la tâche avec `launchctl`. Le programme vérifie le calendrier toutes les cinq minutes. Une exécution en retard de plus de 90 minutes est marquée `missed` et n'est pas publiée en rafale.

Pour une campagne fiable même lorsque le Mac est éteint, exécuter la même commande `run-due --live` toutes les cinq minutes dans un service cloud et stocker `meta.env` dans son gestionnaire de secrets. Ne pas déposer le jeton dans GitHub ou dans un fichier partagé.

## Commandes quotidiennes

```bash
# Voir le calendrier
python3 marketing/social_30_days/automation/meta_scheduler.py plan

# Vérifier ce qui a été publié ou a échoué
python3 marketing/social_30_days/automation/meta_scheduler.py status

# Exécution réelle utilisée par le planificateur
python3 marketing/social_30_days/automation/meta_scheduler.py run-due --live
```

Le calendrier et les médias peuvent être préparés sans jeton. L'autorisation Meta n'est nécessaire qu'au moment du test réel.
