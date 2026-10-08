// Coordinates already collected by harvest_forecast.py. No new API calls.
// Keep IDs and coordinates aligned with that server catalogue.
import 'dart:math' as math;

class MarineWeatherPoint {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  const MarineWeatherPoint(this.id, this.name, this.latitude, this.longitude);

  double distanceKm(double lat, double lon) {
    const radians = math.pi / 180;
    final a = math.pow(math.sin((latitude - lat) * radians / 2), 2) +
        math.cos(lat * radians) *
            math.cos(latitude * radians) *
            math.pow(math.sin((longitude - lon) * radians / 2), 2);
    return 12742 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}

const marineWeatherPoints = <MarineWeatherPoint>[
  MarineWeatherPoint("casablanca_maroc", "Casablanca, Maroc", 33.5971, -7.6315),
  MarineWeatherPoint("agadir_maroc", "Agadir, Maroc", 30.42, -9.6),
  MarineWeatherPoint("tanger_maroc", "Tanger, Maroc", 35.77, -5.81),
  MarineWeatherPoint("rabat_maroc", "Rabat, Maroc", 34.02, -6.84),
  MarineWeatherPoint("essaouira_maroc", "Essaouira, Maroc", 31.51, -9.77),
  MarineWeatherPoint("dakhla_maroc", "Dakhla, Maroc", 23.7, -15.93),
  MarineWeatherPoint("laayoune_maroc", "Laayoune, Maroc", 27.15, -13.2),
  MarineWeatherPoint("safi_maroc", "Safi, Maroc", 32.3, -9.24),
  MarineWeatherPoint("eljadida_maroc", "El Jadida, Maroc", 33.23, -8.5),
  MarineWeatherPoint("mohammedia_maroc", "Mohammedia, Maroc", 33.69, -7.38),
  MarineWeatherPoint("tetouan_maroc", "Martil (Tétouan), Maroc", 35.62, -5.27),
  MarineWeatherPoint("alhoceima_maroc", "Al Hoceima, Maroc", 35.25, -3.93),
  MarineWeatherPoint("nador_maroc", "Nador, Maroc", 35.17, -2.93),
  MarineWeatherPoint("larache_maroc", "Larache, Maroc", 35.19, -6.15),
  MarineWeatherPoint("mdiq_maroc", "Mdiq, Maroc", 35.69, -5.32),
  MarineWeatherPoint("aousserd_extreme_sud_maroc",
      "Littoral d'Aousserd — extrême sud, Maroc", 21.12819, -16.94092),
  MarineWeatherPoint("tantan_elouatia_maroc",
      "Littoral de Tan-Tan / El Ouatia, Maroc", 28.61326, -11.21374),
  MarineWeatherPoint("boujdour_sud_maroc", "Littoral de Boujdour — sud, Maroc",
      25.52581, -14.7087),
  MarineWeatherPoint("aousserd_nord_maroc", "Littoral d'Aousserd — nord, Maroc",
      22.44095, -16.45138),
  MarineWeatherPoint(
      "sidi_ifni_maroc", "Sidi Ifni, Maroc", 29.36693, -10.18696),
  MarineWeatherPoint("tarfaya_akhfennir_maroc",
      "Corridor Tarfaya–Akhfennir, Maroc", 28.041664, -12.708328),
  MarineWeatherPoint("dakhla_boujdour_maroc", "Corridor Dakhla–Boujdour, Maroc",
      24.51228, -15.11409),
  MarineWeatherPoint("boujdour_nord_maroc",
      "Littoral de Boujdour — nord, Maroc", 26.43321, -14.09085),
  MarineWeatherPoint("aousserd_littoral_maroc", "Littoral d'Aousserd, Maroc",
      21.89563, -16.90179),
  MarineWeatherPoint("dakhla_sud_maroc", "Littoral de Dakhla — sud, Maroc",
      23.08228, -16.20727),
  MarineWeatherPoint("tarfaya_sud_maroc", "Littoral de Tarfaya — sud, Maroc",
      27.78174, -13.03329),
  MarineWeatherPoint("kenitra_moulay_bousselham_maroc",
      "Corridor Kénitra–Moulay Bousselham, Maroc", 34.59778, -6.44856),
  MarineWeatherPoint("chefchaouen_jabha_maroc",
      "Littoral de Chefchaouen — secteur Jabha, Maroc", 35.20981, -4.66566),
  MarineWeatherPoint("akhfennir_chbika_maroc",
      "Corridor Akhfennir–Chbika, Maroc", 28.2305, -11.73065),
  MarineWeatherPoint("aglou_tiznit_maroc", "Littoral d'Aglou–Tiznit, Maroc",
      29.85254, -9.79749),
  MarineWeatherPoint("saidia_maroc", "Saïdia, Maroc", 35.09066, -2.23885),
  MarineWeatherPoint("oualidia_maroc", "Oualidia, Maroc", 32.80346, -8.95479),
  MarineWeatherPoint("imsouane_nord_maroc", "Littoral d'Imsouane — nord, Maroc",
      30.95543, -9.82194),
  MarineWeatherPoint("guelmim_tantan_maroc",
      "Littoral de Guelmim–Tan-Tan, Maroc", 28.96584, -10.59871),
  MarineWeatherPoint("laayoune_boujdour_maroc",
      "Corridor Laâyoune–Boujdour, Maroc", 26.73018, -13.57505),
  MarineWeatherPoint("alger_algerie", "Alger, Algérie", 36.75, 3.04),
  MarineWeatherPoint("oran_algerie", "Oran, Algérie", 35.7, -0.64),
  MarineWeatherPoint("annaba_algerie", "Annaba, Algérie", 36.9, 7.77),
  MarineWeatherPoint("bejaia_algerie", "Bejaia, Algérie", 36.75, 5.07),
  MarineWeatherPoint("skikda_algerie", "Skikda, Algérie", 36.88, 6.9),
  MarineWeatherPoint("mostaganem_algerie", "Mostaganem, Algérie", 35.93, 0.09),
  MarineWeatherPoint("tipaza_algerie", "Tipaza, Algérie", 36.59, 2.44),
  MarineWeatherPoint("tunis_tunisie", "Tunis, Tunisie", 36.82, 10.3),
  MarineWeatherPoint("sfax_tunisie", "Sfax, Tunisie", 34.74, 10.76),
  MarineWeatherPoint("sousse_tunisie", "Sousse, Tunisie", 35.83, 10.64),
  MarineWeatherPoint("bizerte_tunisie", "Bizerte, Tunisie", 37.27, 9.87),
  MarineWeatherPoint("mahdia_tunisie", "Mahdia, Tunisie", 35.5, 11.06),
  MarineWeatherPoint("tripoli_libye", "Tripoli, Libye", 32.89, 13.18),
  MarineWeatherPoint("benghazi_libye", "Benghazi, Libye", 32.12, 20.07),
  MarineWeatherPoint("misrata_libye", "Misrata, Libye", 32.37, 15.09),
  MarineWeatherPoint("alexandria_egypte", "Alexandrie, Egypte", 31.2, 29.92),
  MarineWeatherPoint("portsaid_egypte", "Port Said, Egypte", 31.26, 32.29),
  MarineWeatherPoint(
      "marsamatruh_egypte", "Marsa Matruh, Egypte", 31.35, 27.24),
  MarineWeatherPoint(
      "nouadhibou_mauritanie", "Nouadhibou, Mauritanie", 20.93, -17.03),
  MarineWeatherPoint(
      "nouakchott_mauritanie", "Nouakchott, Mauritanie", 18.08, -15.98),
  MarineWeatherPoint("dakar_senegal", "Dakar, Sénégal", 14.69, -17.44),
  MarineWeatherPoint(
      "saintlouis_senegal", "Saint-Louis, Sénégal", 16.03, -16.49),
  MarineWeatherPoint("thies_senegal", "Mbour, Sénégal", 14.42, -16.97),
  MarineWeatherPoint("banjul_gambie", "Banjul, Gambie", 13.45, -16.58),
  MarineWeatherPoint(
      "bissau_guinee_bissau", "Bissau, Guinée-Bissau", 11.86, -15.6),
  MarineWeatherPoint("conakry_guinee", "Conakry, Guinée", 9.64, -13.58),
  MarineWeatherPoint(
      "freetown_sierra_leone", "Freetown, Sierra Leone", 8.48, -13.23),
  MarineWeatherPoint("monrovia_liberia", "Monrovia, Libéria", 6.3, -10.8),
  MarineWeatherPoint(
      "abidjan_cote_ivoire", "Abidjan, Côte d'Ivoire", 5.36, -4.01),
  MarineWeatherPoint(
      "sanpedro_cote_ivoire", "San-Pédro, Côte d'Ivoire", 4.75, -6.64),
  MarineWeatherPoint("accra_ghana", "Accra, Ghana", 5.6, -0.17),
  MarineWeatherPoint("takoradi_ghana", "Takoradi, Ghana", 4.9, -1.76),
  MarineWeatherPoint("lome_togo", "Lomé, Togo", 6.13, 1.22),
  MarineWeatherPoint("cotonou_benin", "Cotonou, Bénin", 6.37, 2.43),
  MarineWeatherPoint("lagos_nigeria", "Lagos, Nigéria", 6.45, 3.4),
  MarineWeatherPoint(
      "portharcourt_nigeria", "Bonny (Port Harcourt), Nigéria", 4.45, 7.17),
  MarineWeatherPoint("douala_cameroun", "Douala, Cameroun", 4.05, 9.7),
  MarineWeatherPoint("limbe_cameroun", "Limbé, Cameroun", 4.02, 9.22),
  MarineWeatherPoint(
      "malabo_guinee_equatoriale", "Malabo, Guinée Équatoriale", 3.75, 8.78),
  MarineWeatherPoint("libreville_gabon", "Libreville, Gabon", 0.39, 9.45),
  MarineWeatherPoint("portgentil_gabon", "Port-Gentil, Gabon", -0.72, 8.78),
  MarineWeatherPoint("pointe_noire_congo", "Pointe-Noire, Congo", -4.78, 11.86),
  MarineWeatherPoint("luanda_angola", "Luanda, Angola", -8.84, 13.23),
  MarineWeatherPoint("benguela_angola", "Benguela, Angola", -12.58, 13.4),
  MarineWeatherPoint("lobito_angola", "Lobito, Angola", -12.35, 13.55),
  MarineWeatherPoint("namibe_angola", "Namibe, Angola", -15.2, 12.15),
  MarineWeatherPoint("walvisbay_namibie", "Walvis Bay, Namibie", -22.96, 14.51),
  MarineWeatherPoint(
      "swakopmund_namibie", "Swakopmund, Namibie", -22.68, 14.53),
  MarineWeatherPoint(
      "capetown_afrique_sud", "Le Cap, Afrique du Sud", -33.92, 18.42),
  MarineWeatherPoint(
      "durban_afrique_sud", "Durban, Afrique du Sud", -29.86, 31.03),
  MarineWeatherPoint("portelizabeth_afrique_sud",
      "Port Elizabeth, Afrique du Sud", -33.96, 25.6),
  MarineWeatherPoint(
      "eastlondon_afrique_sud", "East London, Afrique du Sud", -33.02, 27.9),
  MarineWeatherPoint(
      "mosselbay_afrique_sud", "Mossel Bay, Afrique du Sud", -34.18, 22.13),
  MarineWeatherPoint("maputo_mozambique", "Maputo, Mozambique", -25.97, 32.59),
  MarineWeatherPoint("beira_mozambique", "Beira, Mozambique", -19.83, 34.84),
  MarineWeatherPoint("nampula_mozambique", "Nacala, Mozambique", -14.54, 40.67),
  MarineWeatherPoint(
      "dar_essalaam_tanzanie", "Dar es Salaam, Tanzanie", -6.79, 39.21),
  MarineWeatherPoint("zanzibar_tanzanie", "Zanzibar, Tanzanie", -6.16, 39.19),
  MarineWeatherPoint("mombasa_kenya", "Mombasa, Kenya", -4.04, 39.67),
  MarineWeatherPoint("malindi_kenya", "Malindi, Kenya", -3.22, 40.12),
  MarineWeatherPoint("mogadiscio_somalie", "Mogadiscio, Somalie", 2.04, 45.34),
  MarineWeatherPoint("berbera_somaliland", "Berbera, Somaliland", 10.44, 45.01),
  MarineWeatherPoint("djibouti_ville", "Djibouti, Djibouti", 11.59, 43.15),
  MarineWeatherPoint("portlouis_maurice", "Port Louis, Maurice", -20.16, 57.5),
  MarineWeatherPoint(
      "saintdenis_reunion", "Saint-Denis, Réunion", -20.88, 55.45),
  MarineWeatherPoint(
      "toamasina_madagascar", "Toamasina, Madagascar", -18.15, 49.4),
  MarineWeatherPoint(
      "antananarivo_madagascar", "Mahajanga, Madagascar", -15.72, 46.32),
  MarineWeatherPoint("male_maldives", "Malé, Maldives", 4.18, 73.51),
  MarineWeatherPoint(
      "victoria_seychelles", "Victoria, Seychelles", -4.62, 55.45),
  MarineWeatherPoint(
      "jedda_arabie_saoudite", "Jeddah, Arabie Saoudite", 21.54, 39.17),
  MarineWeatherPoint(
      "yanbu_arabie_saoudite", "Yanbu, Arabie Saoudite", 24.09, 38.06),
  MarineWeatherPoint(
      "dammam_arabie_saoudite", "Dammam, Arabie Saoudite", 26.42, 50.1),
  MarineWeatherPoint(
      "jubail_arabie_saoudite", "Jubail, Arabie Saoudite", 27.0, 49.66),
  MarineWeatherPoint("dubai_emirats", "Dubaï, EAU", 25.2, 55.27),
  MarineWeatherPoint("abudhabi_emirats", "Abou Dhabi, EAU", 24.45, 54.38),
  MarineWeatherPoint("sharjah_emirats", "Sharjah, EAU", 25.35, 55.39),
  MarineWeatherPoint("fujairah_emirats", "Fujairah, EAU", 25.13, 56.33),
  MarineWeatherPoint("muscat_oman", "Mascate, Oman", 23.61, 58.59),
  MarineWeatherPoint("salalah_oman", "Salalah, Oman", 17.02, 54.09),
  MarineWeatherPoint("sohar_oman", "Sohar, Oman", 24.36, 56.75),
  MarineWeatherPoint("doha_qatar", "Doha, Qatar", 25.29, 51.53),
  MarineWeatherPoint("manama_bahrein", "Manama, Bahreïn", 26.22, 50.59),
  MarineWeatherPoint("koweit_city_koweit", "Koweït City, Koweït", 29.37, 47.98),
  MarineWeatherPoint("basra_irak", "Al-Faw (Bassorah), Irak", 29.97, 48.47),
  MarineWeatherPoint("aden_yemen", "Aden, Yémen", 12.78, 45.03),
  MarineWeatherPoint("mukalla_yemen", "Mukalla, Yémen", 14.54, 49.13),
  MarineWeatherPoint("hodeidah_yemen", "Al Hudaydah, Yémen", 14.8, 42.95),
  MarineWeatherPoint("port_soudan_soudan", "Port-Soudan, Soudan", 19.62, 37.22),
  MarineWeatherPoint("aqaba_jordanie", "Aqaba, Jordanie", 29.45, 35.0),
  MarineWeatherPoint("eilat_israel", "Eilat, Israël", 29.48, 34.94),
  MarineWeatherPoint("telaviv_israel", "Tel Aviv, Israël", 32.09, 34.78),
  MarineWeatherPoint("haifa_israel", "Haïfa, Israël", 32.82, 34.99),
  MarineWeatherPoint("beyrouth_liban", "Beyrouth, Liban", 33.89, 35.5),
  MarineWeatherPoint("tripoli_liban", "Tripoli, Liban", 34.44, 35.84),
  MarineWeatherPoint("saida_liban", "Saïda, Liban", 33.56, 35.37),
  MarineWeatherPoint("lattaquie_syrie", "Lattaquié, Syrie", 35.52, 35.78),
  MarineWeatherPoint("tartous_syrie", "Tartous, Syrie", 34.89, 35.89),
  MarineWeatherPoint("istanbul_turquie", "Istanbul, Turquie", 41.01, 28.98),
  MarineWeatherPoint("izmir_turquie", "Izmir, Turquie", 38.42, 27.14),
  MarineWeatherPoint("antalya_turquie", "Antalya, Turquie", 36.9, 30.7),
  MarineWeatherPoint("mersin_turquie", "Mersin, Turquie", 36.8, 34.63),
  MarineWeatherPoint("samsun_turquie", "Samsun, Turquie", 41.29, 36.33),
  MarineWeatherPoint("trabzon_turquie", "Trabzon, Turquie", 41.0, 39.72),
  MarineWeatherPoint("bodrum_turquie", "Bodrum, Turquie", 37.03, 27.43),
  MarineWeatherPoint("larnaca_chypre", "Larnaca, Chypre", 34.92, 33.63),
  MarineWeatherPoint("limassol_chypre", "Limassol, Chypre", 34.68, 33.04),
  MarineWeatherPoint(
      "sharm_el_sheikh_egypte", "Sharm El-Sheikh, Egypte", 27.97, 34.39),
  MarineWeatherPoint("hurgada_egypte", "Hurghada, Egypte", 27.26, 33.81),
];

MarineWeatherPoint? nearestMarineWeatherPoint(double lat, double lon) {
  if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
    return null;
  }
  MarineWeatherPoint? nearest;
  var distance = 75.0;
  for (final point in marineWeatherPoints) {
    final km = point.distanceKm(lat, lon);
    if (km <= distance) {
      nearest = point;
      distance = km;
    }
  }
  return nearest;
}
