# BoosterFish — campagne sociale de 30 jours

Le pack complémentaire de **20 publications image 4:5** est disponible dans [`static_posts/`](static_posts/README.md).

La série enrichie demandée ensuite, avec écrans de l’application et explication détaillée de chaque fonction, est disponible dans [`feature_posters/`](feature_posters/README.md). Cette série est la version recommandée pour publication.

Livrable prêt pour Facebook Reels et Instagram Reels, construit à partir des fonctions réellement présentes dans BoosterFish et de son identité bleu marine/cyan.

## Contenu livré

- `exports/reels/` : 30 vidéos verticales MP4, H.264, 1080 × 1920, 30 i/s, 12 secondes.
- `exports/covers/` : 30 couvertures PNG, 1080 × 1920.
- `content/captions_ready_to_post.md` : textes de publication, CTA et hashtags.
- `content/video_scripts.md` : écrans et voix off pour chaque vidéo.
- `content/captions_srt/` : 30 fichiers SRT synchronisés avec les quatre écrans.
- `content/calendar_30_days.csv` : calendrier éditable dans Excel ou Google Sheets.
- `content/delivery_manifest.csv` : correspondance vidéo, couverture et sous-titres.
- `content/content_qa.json` : faits autorisés et promesses volontairement exclues.
- `qa/media_validation.csv` : validation technique de chaque MP4.
- `automation/` : calendrier daté et planificateur officiel Meta avec simulation, journal anti-doublon et [guide clic par clic](automation/README.md).

Répartition éditoriale : 15 contenus en français, 8 en darija marocain et 7 bilingues.

## Publication recommandée

1. Choisir la vidéo du jour dans `exports/reels/`.
2. Choisir sa couverture portant le même nom dans `exports/covers/`.
3. Copier le texte du jour depuis `content/captions_ready_to_post.md`.
4. Ajouter la voix off fournie dans `content/video_scripts.md`, ou publier le master avec son texte incrusté.
5. Ajouter une piste autorisée depuis Meta Sound Collection si une musique est souhaitée.
6. Vérifier l'aperçu Instagram et Facebook avant de publier.

Les MP4 sont des **masters propres sans piste audio**. Ce choix évite d'incorporer une musique dont la licence ou la disponibilité régionale pourrait changer. Meta indique que certaines entreprises n'ont pas accès à toute la bibliothèque musicale et propose Sound Collection pour les usages commerciaux.

## Positionnement pendant le test fermé

Jusqu'à l'ouverture publique, conserver les mentions « en test fermé », « bientôt disponible » et « testeur invité ». Ne pas utiliser « téléchargez maintenant » auprès du public général. Le jour où BoosterFish passe en production, remplacer ces mentions par le lien Google Play officiel puis régénérer les vidéos.

## Mesure du premier mois

Pour chaque Reel, relever après 24 heures et après 7 jours : portée, lectures de 3 secondes, durée moyenne de visionnage, taux de complétion, enregistrements, partages, commentaires et visites du profil. Après sept publications, garder les deux meilleurs hooks et les deux meilleurs sujets pour le mois suivant.

Le premier mois sert aussi de test éditorial. Les heures de publication doivent être comparées dans Meta Business Suite avec deux créneaux réguliers, puis ajustées selon les données réelles de la page.

## Régénération

Les textes sont produits par :

```bash
python3 marketing/social_30_days/tools/generate_content.py
```

Les vidéos sont produites sur macOS par :

```bash
SWIFT_MODULECACHE_PATH=/tmp/boosterfish-swift-cache \
CLANG_MODULE_CACHE_PATH=/tmp/boosterfish-swift-cache \
swift marketing/social_30_days/tools/render_reels.swift \
  marketing/social_30_days
```

La validation technique est produite par :

```bash
SWIFT_MODULECACHE_PATH=/tmp/boosterfish-swift-cache \
CLANG_MODULE_CACHE_PATH=/tmp/boosterfish-swift-cache \
swift marketing/social_30_days/tools/inspect_media.swift \
  marketing/social_30_days/exports/reels
```
