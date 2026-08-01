// Normalise uniquement le cadrage visuel des vignettes poisson.
//
// Les assets ont tous une toile de 400 x 400, mais la quantité de marge blanche
// varie fortement d'une image à l'autre. Ces facteurs compensent ces marges sans
// modifier les fichiers, leur résolution ou le chargement en mémoire.
abstract final class FishImageFraming {
  static const Map<String, double> _thumbnailScaleByFishId = {
    'daurade_royale': 1.00,
    'loup_bar': 1.08,
    'thon_rouge': 1.75,
    'rouget': 1.02,
    'pageot': 1.70,
    'maquereau': 1.00,
    'mulet': 1.72,
    'sole': 1.78,
  };

  static double thumbnailScale(String fishId) =>
      _thumbnailScaleByFishId[fishId] ?? 1.0;

  static bool hasThumbnailFraming(String fishId) =>
      _thumbnailScaleByFishId.containsKey(fishId);
}
