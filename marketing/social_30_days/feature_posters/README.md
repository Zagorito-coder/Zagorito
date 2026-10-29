# BoosterFish — 20 affiches explicatives

Cette série remplace le concept minimaliste initial par des publications riches inspirées de la structure du modèle fourni : identité forte, bénéfice principal, trois explications, téléphone central et preuve visuelle de l’application.

## Format

- 20 images PNG distinctes.
- 1080 × 1350 px, ratio 4:5.
- Adapté au fil Facebook et Instagram.
- Textes français intégrés et lisibles sur mobile.
- Logo officiel BoosterFish sur chaque publication.

## Architecture d’une affiche

1. Logo et signature BoosterFish.
2. Nom de la fonctionnalité.
3. Chiffre ou bénéfice vérifiable.
4. Description courte de l’usage.
5. Trois cartes explicatives.
6. Téléphone avec écran réel, extrait réel ou tutoriel réel de BoosterFish.
7. Message de conclusion.

## Les 20 sujets

| ID | Sujet | Preuve visuelle |
|---:|---|---|
| 01 | Page Spots | Carte réelle et marqueurs officiels |
| 02 | Spots privés | Écran réel Mes spots |
| 03 | Marées | Tableau de bord réel |
| 04 | Conditions marines | Vent, mer et marées dans l’accueil réel |
| 05 | Cartes hors ligne | Carte et outils cartographiques |
| 06 | Techniques | Page réelle des 18 techniques |
| 07 | Nœud FG | Illustration technique présente dans l’application |
| 08 | Nœud Palomar | Illustration technique présente dans l’application |
| 09 | Préparation jigging | Catalogue réel des techniques |
| 10 | Traîne et Big Game | Guide réel de connexion offshore |
| 11 | Espèces | Visuel officiel du thon rouge dans l’application |
| 12 | Communauté | Point d’accès réel depuis l’accueil |
| 13 | Partage d’une prise | Parcours communauté expliqué |
| 14 | Sécurité | Conditions visibles dans le tableau de bord |
| 15 | Magasins | Point d’accès réel depuis l’accueil |
| 16 | Carnet personnel | Écran réel Mes spots |
| 17 | Pêche responsable | Fiche espèce et règles de prudence |
| 18 | Test fermé | Version BoosterFish réellement testée |
| 19 | Tout-en-un | Vue d’ensemble réelle de l’accueil |
| 20 | Bientôt disponible | Statut exact : test fermé Google Play |

## Vérités produit utilisées

- 6 365 spots dans le catalogue local validé.
- Cartes hors ligne téléchargeables et activables.
- Spots personnels et coordonnées privées.
- Marées, conditions marines, espèces et guides techniques.
- 18 techniques et montages.
- 72 espèces affichées dans l’application.
- Communauté avec publication et contrôles de modération.
- Application Android actuellement en test fermé Google Play.

Les affiches ne promettent ni capture, ni sécurité absolue, ni date publique de lancement.

## Régénération

```bash
env CLANG_MODULE_CACHE_PATH=/tmp/boosterfish-swift-cache \
    SWIFT_MODULECACHE_PATH=/tmp/boosterfish-swift-cache \
    swift marketing/social_30_days/feature_posters/tools/compose_feature_posters.swift \
    marketing/social_30_days/static_posts/backgrounds \
    . \
    assets/images/techniques_v2 \
    assets/fish_images \
    marketing/social_30_days/static_posts/logo_reference.png \
    marketing/social_30_days/feature_posters/exports \
    all
```

