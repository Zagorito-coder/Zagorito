# BoosterFish — Pack de 20 publications image

Livrable statique pour Facebook et Instagram, conçu pour compléter les Reels de la campagne de 30 jours.

## Contenu livré

- `exports/` : 20 visuels finaux en **1080 × 1350 px (4:5)**, prêts à publier.
- `backgrounds/` : scènes photoréalistes originales, sans texte ni logo généré.
- `logo_reference.png` : logo officiel utilisé pour tous les montages.
- `content/CAPTIONS.md` : légendes, appels à l’action et hashtags.
- `content/CALENDAR.md` : ordre conseillé sur quatre semaines, associé aux Reels.
- `content/IMAGE_PROMPTS.md` : direction créative et prompts de production.
- `qa/contact_sheet.png` : contrôle visuel des 20 publications.
- `qa/SHA256SUMS.txt` : empreintes des exports livrés.

## Direction artistique

Le système combine photographie marine réaliste, bleu nuit, cyan BoosterFish, titres courts et zones de lecture très contrastées. Le logo est toujours le fichier officiel superposé après génération : aucun logo et aucun texte n’ont été confiés au générateur d’images.

Les références du marché ont servi à identifier des codes utiles — carte claire, conditions marines lisibles, communauté, carnet et pédagogie — sans copier leurs interfaces, leurs textes, leurs visuels ou leurs marques.

## Régénération

Depuis la racine du dépôt :

```bash
env CLANG_MODULE_CACHE_PATH=/tmp/boosterfish-swift-cache \
    SWIFT_MODULECACHE_PATH=/tmp/boosterfish-swift-cache \
    swift marketing/social_30_days/static_posts/tools/compose_posts.swift \
    marketing/social_30_days/static_posts/backgrounds \
    marketing/social_30_days/static_posts/logo_reference.png \
    marketing/social_30_days/static_posts/exports
```

Puis reconstruire la planche de contrôle :

```bash
env CLANG_MODULE_CACHE_PATH=/tmp/boosterfish-swift-cache \
    SWIFT_MODULECACHE_PATH=/tmp/boosterfish-swift-cache \
    swift marketing/social_30_days/static_posts/tools/make_contact_sheet.swift \
    marketing/social_30_days/static_posts/exports \
    marketing/social_30_days/static_posts/qa/contact_sheet.png
```

## Règles de publication

- Importer l’image à sa taille d’origine et choisir le format vertical 4:5.
- Ne pas ajouter un second logo ou un cadre Meta.
- Garder les textes importants dans le visuel ; utiliser la légende pour l’explication et l’appel à l’action.
- Ne jamais promettre une prise ou une sécurité absolue. Les conditions marines doivent toujours être vérifiées avant la sortie.
- Les scènes sont des créations publicitaires photoréalistes, pas des captures d’écran ni des témoignages d’utilisateurs réels.

