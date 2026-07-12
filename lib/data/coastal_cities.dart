/// Liste des villes côtières par pays.
/// Utilisée pour interroger l'API Overpass (OSM) autour de chaque ville
/// (recherche par rayon), afin de couvrir les zones côtières sans avoir
/// à calculer la distance au littoral pour chaque magasin.
class CoastalCity {
  final String name;
  final String country;
  final String iso; // code ISO 3166-1 alpha-2
  final double lat;
  final double lon;

  const CoastalCity({
    required this.name,
    required this.country,
    required this.iso,
    required this.lat,
    required this.lon,
  });
}

const List<CoastalCity> coastalCities = [
  // ---------------- Maroc (MA) ----------------
  CoastalCity(name: 'Tanger', country: 'Maroc', iso: 'MA', lat: 35.7595, lon: -5.8340),
  CoastalCity(name: 'Al Hoceïma', country: 'Maroc', iso: 'MA', lat: 35.2517, lon: -3.9372),
  CoastalCity(name: 'Nador', country: 'Maroc', iso: 'MA', lat: 35.1681, lon: -2.9287),
  CoastalCity(name: 'Kénitra', country: 'Maroc', iso: 'MA', lat: 34.2610, lon: -6.5802),
  CoastalCity(name: 'Rabat', country: 'Maroc', iso: 'MA', lat: 34.0209, lon: -6.8416),
  CoastalCity(name: 'Casablanca', country: 'Maroc', iso: 'MA', lat: 33.5731, lon: -7.5898),
  CoastalCity(name: 'El Jadida', country: 'Maroc', iso: 'MA', lat: 33.2549, lon: -8.5058),
  CoastalCity(name: 'Safi', country: 'Maroc', iso: 'MA', lat: 32.2994, lon: -9.2372),
  CoastalCity(name: 'Essaouira', country: 'Maroc', iso: 'MA', lat: 31.5085, lon: -9.7595),
  CoastalCity(name: 'Tifnit', country: 'Maroc', iso: 'MA', lat: 30.2833, lon: -9.6667),
  CoastalCity(name: 'Agadir', country: 'Maroc', iso: 'MA', lat: 30.4278, lon: -9.5981),
  CoastalCity(name: 'Laâyoune', country: 'Maroc', iso: 'MA', lat: 27.1418, lon: -13.1878),
  CoastalCity(name: 'Dakhla', country: 'Maroc', iso: 'MA', lat: 23.6848, lon: -15.9579),

  // ---------------- Algérie (DZ) ----------------
  CoastalCity(name: 'Oran', country: 'Algérie', iso: 'DZ', lat: 35.6969, lon: -0.6331),
  CoastalCity(name: 'Mostaganem', country: 'Algérie', iso: 'DZ', lat: 35.9315, lon: 0.0891),
  CoastalCity(name: 'Alger', country: 'Algérie', iso: 'DZ', lat: 36.7538, lon: 3.0588),
  CoastalCity(name: 'Béjaïa', country: 'Algérie', iso: 'DZ', lat: 36.7509, lon: 5.0567),
  CoastalCity(name: 'Jijel', country: 'Algérie', iso: 'DZ', lat: 36.8218, lon: 5.7666),
  CoastalCity(name: 'Skikda', country: 'Algérie', iso: 'DZ', lat: 36.8761, lon: 6.9094),
  CoastalCity(name: 'Annaba', country: 'Algérie', iso: 'DZ', lat: 36.9000, lon: 7.7667),

  // ---------------- Tunisie (TN) ----------------
  CoastalCity(name: 'Bizerte', country: 'Tunisie', iso: 'TN', lat: 37.2744, lon: 9.8739),
  CoastalCity(name: 'Tunis', country: 'Tunisie', iso: 'TN', lat: 36.8065, lon: 10.1815),
  CoastalCity(name: 'Sousse', country: 'Tunisie', iso: 'TN', lat: 35.8256, lon: 10.6084),
  CoastalCity(name: 'Monastir', country: 'Tunisie', iso: 'TN', lat: 35.7770, lon: 10.8262),
  CoastalCity(name: 'Sfax', country: 'Tunisie', iso: 'TN', lat: 34.7406, lon: 10.7603),
  CoastalCity(name: 'Gabès', country: 'Tunisie', iso: 'TN', lat: 33.8815, lon: 10.0982),

  // ---------------- Libye (LY) ----------------
  CoastalCity(name: 'Zouara', country: 'Libye', iso: 'LY', lat: 32.9310, lon: 12.0810),
  CoastalCity(name: 'Tripoli', country: 'Libye', iso: 'LY', lat: 32.8872, lon: 13.1913),
  CoastalCity(name: 'Misrata', country: 'Libye', iso: 'LY', lat: 32.3745, lon: 15.0919),
  CoastalCity(name: 'Benghazi', country: 'Libye', iso: 'LY', lat: 32.1167, lon: 20.0667),
  CoastalCity(name: 'Tobrouk', country: 'Libye', iso: 'LY', lat: 32.0836, lon: 23.9764),

  // ---------------- Égypte (EG) ----------------
  CoastalCity(name: 'Alexandrie', country: 'Égypte', iso: 'EG', lat: 31.2001, lon: 29.9187),
  CoastalCity(name: 'Port-Saïd', country: 'Égypte', iso: 'EG', lat: 31.2653, lon: 32.3019),
  CoastalCity(name: 'Damiette', country: 'Égypte', iso: 'EG', lat: 31.4165, lon: 31.8133),
  CoastalCity(name: 'Suez', country: 'Égypte', iso: 'EG', lat: 29.9668, lon: 32.5498),
  CoastalCity(name: 'Hurghada', country: 'Égypte', iso: 'EG', lat: 27.2579, lon: 33.8116),

  // ---------------- Syrie (SY) ----------------
  CoastalCity(name: 'Lattaquié', country: 'Syrie', iso: 'SY', lat: 35.5317, lon: 35.7915),
  CoastalCity(name: 'Tartous', country: 'Syrie', iso: 'SY', lat: 34.8890, lon: 35.8866),

  // ---------------- Liban (LB) ----------------
  CoastalCity(name: 'Tripoli', country: 'Liban', iso: 'LB', lat: 34.4361, lon: 35.8497),
  CoastalCity(name: 'Beyrouth', country: 'Liban', iso: 'LB', lat: 33.8938, lon: 35.5018),
  CoastalCity(name: 'Saïda', country: 'Liban', iso: 'LB', lat: 33.5606, lon: 35.3758),
  CoastalCity(name: 'Tyr', country: 'Liban', iso: 'LB', lat: 33.2704, lon: 35.1938),

  // ---------------- Palestine (PS) ----------------
  CoastalCity(name: 'Gaza', country: 'Palestine', iso: 'PS', lat: 31.5017, lon: 34.4668),

  // ---------------- Arabie Saoudite (SA) ----------------
  CoastalCity(name: 'Jeddah', country: 'Arabie Saoudite', iso: 'SA', lat: 21.4858, lon: 39.1925),
  CoastalCity(name: 'Yanbu', country: 'Arabie Saoudite', iso: 'SA', lat: 24.0895, lon: 38.0618),
  CoastalCity(name: 'Jizan', country: 'Arabie Saoudite', iso: 'SA', lat: 16.8892, lon: 42.5611),
  CoastalCity(name: 'Dammam', country: 'Arabie Saoudite', iso: 'SA', lat: 26.4207, lon: 50.0888),
  CoastalCity(name: 'Jubail', country: 'Arabie Saoudite', iso: 'SA', lat: 27.0046, lon: 49.6255),

  // ---------------- Yémen (YE) ----------------
  CoastalCity(name: 'Aden', country: 'Yémen', iso: 'YE', lat: 12.7855, lon: 45.0187),
  CoastalCity(name: 'Al Hodeïda', country: 'Yémen', iso: 'YE', lat: 14.7979, lon: 42.9545),
  CoastalCity(name: 'Al Moukalla', country: 'Yémen', iso: 'YE', lat: 14.5425, lon: 49.1242),

  // ---------------- Oman (OM) ----------------
  CoastalCity(name: 'Mascate', country: 'Oman', iso: 'OM', lat: 23.5859, lon: 58.4059),
  CoastalCity(name: 'Salalah', country: 'Oman', iso: 'OM', lat: 17.0151, lon: 54.0924),
  CoastalCity(name: 'Sohar', country: 'Oman', iso: 'OM', lat: 24.3473, lon: 56.7086),
  CoastalCity(name: 'Sour', country: 'Oman', iso: 'OM', lat: 22.5667, lon: 59.5289),

  // ---------------- Émirats Arabes Unis (AE) ----------------
  CoastalCity(name: 'Dubaï', country: 'Émirats Arabes Unis', iso: 'AE', lat: 25.2048, lon: 55.2708),
  CoastalCity(name: 'Abou Dabi', country: 'Émirats Arabes Unis', iso: 'AE', lat: 24.4539, lon: 54.3773),
  CoastalCity(name: 'Charjah', country: 'Émirats Arabes Unis', iso: 'AE', lat: 25.3463, lon: 55.4209),
  CoastalCity(name: 'Fujaïrah', country: 'Émirats Arabes Unis', iso: 'AE', lat: 25.1288, lon: 56.3265),

  // ---------------- Qatar (QA) ----------------
  CoastalCity(name: 'Doha', country: 'Qatar', iso: 'QA', lat: 25.2854, lon: 51.5310),
  CoastalCity(name: 'Al Wakrah', country: 'Qatar', iso: 'QA', lat: 25.1715, lon: 51.6035),

  // ---------------- Koweït (KW) ----------------
  CoastalCity(name: 'Koweït City', country: 'Koweït', iso: 'KW', lat: 29.3759, lon: 47.9774),
  CoastalCity(name: 'Al Ahmadi', country: 'Koweït', iso: 'KW', lat: 29.0769, lon: 48.0838),
];