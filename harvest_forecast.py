# harvest_forecast.py
# Recupere vent + houle + temperature/nuages/pluie via l'API commerciale
# Open-Meteo, calcule une note en etoiles, et pousse tout sur Firestore.
#
# v2 — multi-modeles (Phase 2) : 3 modeles GFS ~13km / ECMWF IFS-HRES ~9km /
# GFS-Wave, sous-objet "models" additif, sunrise/sunset, water_temp_c.
#
# Structure ecrite dans Firestore, collection "spots_meteo",
# document "{spot_id}" :
# {
#   "last_update": <timestamp serveur>,
#   "location_name": "Lancelin",
#   "latitude": -31.02, "longitude": 115.33,
#   "sunrise": "2026-07-08T06:30",   // nouveau – jour J+0
#   "sunset": "2026-07-08T20:15",    // nouveau – jour J+0
#   "water_temp_c": 22.4,            // nouveau – SST la plus proche du run
#   "days": [
#     { "date": "2026-07-08",
#       "sunrise": "2026-07-08T06:30",
#       "sunset": "2026-07-08T20:15",
#       "slots": [
#         { "hour": "2026-07-08T08:00",
#           // champs racine (compat arriere, inchanges)
#           "wind_speed_kt": 7.2, "wind_gust_kt": 10.0,
#           "wind_dir_deg": 190, "wave_height_m": 1.7, "wave_period_s": 13,
#           "wave_dir_deg": 210, "temp_c": 24, "cloud_pct": 30,
#           "precip_pct": 10, "rating": 3,
#           // nouveau sous-objet additif
#           "models": {
#             "wind": { ... },   // GFS ~13km
#             "hires": { ... },  // ECMWF IFS-HRES ~9km
#             "wave": { ... }    // GFS-Wave
#           }
#         },
#         ...
#       ]
#     }, ...
#   ]
# }
#
# Usage : python harvest_forecast.py
# Variables a adapter : SPOTS ci-dessous.
# ============================================================================

import os
import math
import random
import threading
import time
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from datetime import date, datetime, timedelta, timezone
from collections import defaultdict
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError, reset_tzpath

try:
    # Le runner GitHub peut embarquer une base système plus ancienne que le
    # retour définitif du Maroc à GMT du 20 septembre 2026. La dépendance
    # Python épinglée garantit la même règle IANA en CI et en Production.
    import importlib.resources as importlib_resources
    import tzdata

    reset_tzpath(
        [str(importlib_resources.files(tzdata).joinpath("zoneinfo"))]
    )
    ZoneInfo.clear_cache()
except ImportError:
    # En développement local, ZoneInfo conserve la base du système. Le job
    # Production installe toujours requirements-harvest.txt et ne passe donc
    # jamais par ce repli.
    pass

import requests
import firebase_admin
from firebase_admin import credentials, firestore

# ---------------------------------------------------------------------------
# URLs commerciales : la clé doit rester côté serveur/GitHub Actions.
# ---------------------------------------------------------------------------
# Clé commerciale injectée uniquement par le job serveur/GitHub Actions.
OPEN_METEO_API_KEY = (os.environ.get("OPEN_METEO_API_KEY") or "").strip() or None
FORECAST_RUN_ID = (os.environ.get("FORECAST_RUN_ID") or "").strip() or None

# Les documents météo et conditions contiennent dix jours de données. Firestore
# refuse tout Commit supérieur à 10 Mio. Une limite fixe de vingt stations garde
# chaque requête loin de ce plafond même lorsque les documents des 143 stations
# et les cinq alias de transition sont écrits ensemble.
PUBLISH_BATCH_STATION_COUNT = 20
EXPECTED_STATION_COUNT = 143

FORECAST_BASE_URL = "https://customer-api.open-meteo.com/v1/forecast"
MARINE_BASE_URL = "https://customer-marine-api.open-meteo.com/v1/marine"

# ---------------------------------------------------------------------------
# 1. Liste des spots a moissonner. Ajoute-en autant que tu veux.
# ---------------------------------------------------------------------------
SPOTS = [
    # === Afrique du Nord (Maghreb) ===
    # Point côtier Bourgogne Ouest utilisé par la référence de comparaison.
    # Le centre-ville produisait une interpolation moins représentative du
    # vent réellement rencontré sur le littoral casablancais.
    {"id": "casablanca_maroc", "name": "Casablanca, Maroc", "lat": 33.5971, "lon": -7.6315},
    {"id": "agadir_maroc", "name": "Agadir, Maroc", "lat": 30.42, "lon": -9.60},
    {"id": "tanger_maroc", "name": "Tanger, Maroc", "lat": 35.77, "lon": -5.81},
    {"id": "rabat_maroc", "name": "Rabat, Maroc", "lat": 34.02, "lon": -6.84},
    {"id": "essaouira_maroc", "name": "Essaouira, Maroc", "lat": 31.51, "lon": -9.77},
    {"id": "dakhla_maroc", "name": "Dakhla, Maroc", "lat": 23.70, "lon": -15.93},
    {"id": "laayoune_maroc", "name": "Laayoune, Maroc", "lat": 27.15, "lon": -13.20},
    {"id": "safi_maroc", "name": "Safi, Maroc", "lat": 32.30, "lon": -9.24},
    {"id": "eljadida_maroc", "name": "El Jadida, Maroc", "lat": 33.23, "lon": -8.50},
    {"id": "mohammedia_maroc", "name": "Mohammedia, Maroc", "lat": 33.69, "lon": -7.38},
    # Martil est le point côtier de Tétouan couvert par le modèle de vagues.
    {"id": "tetouan_maroc", "name": "Martil (Tétouan), Maroc", "lat": 35.62, "lon": -5.27},
    {"id": "alhoceima_maroc", "name": "Al Hoceima, Maroc", "lat": 35.25, "lon": -3.93},
    {"id": "nador_maroc", "name": "Nador, Maroc", "lat": 35.17, "lon": -2.93},
    {"id": "larache_maroc", "name": "Larache, Maroc", "lat": 35.19, "lon": -6.15},
    {"id": "mdiq_maroc", "name": "Mdiq, Maroc", "lat": 35.69, "lon": -5.32},
    # Points météo côtiers régionaux au Maroc. Ces libellés décrivent une zone
    # ou un corridor et ne présentent pas les noms locaux des spots comme des
    # villes officielles. Les coordonnées de couverture restent inchangées.
    {"id": "aousserd_extreme_sud_maroc", "name": "Littoral d'Aousserd — extrême sud, Maroc", "lat": 21.12819, "lon": -16.94092},
    {"id": "tantan_elouatia_maroc", "name": "Littoral de Tan-Tan / El Ouatia, Maroc", "lat": 28.61326, "lon": -11.21374},
    {"id": "boujdour_sud_maroc", "name": "Littoral de Boujdour — sud, Maroc", "lat": 25.52581, "lon": -14.70870},
    {"id": "aousserd_nord_maroc", "name": "Littoral d'Aousserd — nord, Maroc", "lat": 22.44095, "lon": -16.45138},
    {"id": "sidi_ifni_maroc", "name": "Sidi Ifni, Maroc", "lat": 29.36693, "lon": -10.18696},
    {"id": "tarfaya_akhfennir_maroc", "name": "Corridor Tarfaya–Akhfennir, Maroc", "lat": 28.041664, "lon": -12.708328},
    {"id": "dakhla_boujdour_maroc", "name": "Corridor Dakhla–Boujdour, Maroc", "lat": 24.51228, "lon": -15.11409},
    {"id": "boujdour_nord_maroc", "name": "Littoral de Boujdour — nord, Maroc", "lat": 26.43321, "lon": -14.09085},
    {"id": "aousserd_littoral_maroc", "name": "Littoral d'Aousserd, Maroc", "lat": 21.89563, "lon": -16.90179},
    {"id": "dakhla_sud_maroc", "name": "Littoral de Dakhla — sud, Maroc", "lat": 23.08228, "lon": -16.20727},
    {"id": "tarfaya_sud_maroc", "name": "Littoral de Tarfaya — sud, Maroc", "lat": 27.78174, "lon": -13.03329},
    {"id": "kenitra_moulay_bousselham_maroc", "name": "Corridor Kénitra–Moulay Bousselham, Maroc", "lat": 34.59778, "lon": -6.44856},
    {"id": "chefchaouen_jabha_maroc", "name": "Littoral de Chefchaouen — secteur Jabha, Maroc", "lat": 35.20981, "lon": -4.66566},
    {"id": "akhfennir_chbika_maroc", "name": "Corridor Akhfennir–Chbika, Maroc", "lat": 28.23050, "lon": -11.73065},
    {"id": "aglou_tiznit_maroc", "name": "Littoral d'Aglou–Tiznit, Maroc", "lat": 29.85254, "lon": -9.79749},
    {"id": "saidia_maroc", "name": "Saïdia, Maroc", "lat": 35.09066, "lon": -2.23885},
    {"id": "oualidia_maroc", "name": "Oualidia, Maroc", "lat": 32.80346, "lon": -8.95479},
    {"id": "imsouane_nord_maroc", "name": "Littoral d'Imsouane — nord, Maroc", "lat": 30.95543, "lon": -9.82194},
    {"id": "guelmim_tantan_maroc", "name": "Littoral de Guelmim–Tan-Tan, Maroc", "lat": 28.96584, "lon": -10.59871},
    {"id": "laayoune_boujdour_maroc", "name": "Corridor Laâyoune–Boujdour, Maroc", "lat": 26.73018, "lon": -13.57505},
    {"id": "alger_algerie", "name": "Alger, Algérie", "lat": 36.75, "lon": 3.04},
    {"id": "oran_algerie", "name": "Oran, Algérie", "lat": 35.70, "lon": -0.64},
    {"id": "annaba_algerie", "name": "Annaba, Algérie", "lat": 36.90, "lon": 7.77},
    {"id": "bejaia_algerie", "name": "Bejaia, Algérie", "lat": 36.75, "lon": 5.07},
    {"id": "skikda_algerie", "name": "Skikda, Algérie", "lat": 36.88, "lon": 6.90},
    {"id": "mostaganem_algerie", "name": "Mostaganem, Algérie", "lat": 35.93, "lon": 0.09},
    {"id": "tipaza_algerie", "name": "Tipaza, Algérie", "lat": 36.59, "lon": 2.44},
    # Coordonnée côtière : le centre de Tunis est une cellule terrestre sans
    # données de vagues exploitables dans le modèle marin.
    {"id": "tunis_tunisie", "name": "Tunis, Tunisie", "lat": 36.82, "lon": 10.30},
    {"id": "sfax_tunisie", "name": "Sfax, Tunisie", "lat": 34.74, "lon": 10.76},
    {"id": "sousse_tunisie", "name": "Sousse, Tunisie", "lat": 35.83, "lon": 10.64},
    {"id": "bizerte_tunisie", "name": "Bizerte, Tunisie", "lat": 37.27, "lon": 9.87},
    {"id": "mahdia_tunisie", "name": "Mahdia, Tunisie", "lat": 35.50, "lon": 11.06},
    {"id": "tripoli_libye", "name": "Tripoli, Libye", "lat": 32.89, "lon": 13.18},
    {"id": "benghazi_libye", "name": "Benghazi, Libye", "lat": 32.12, "lon": 20.07},
    {"id": "misrata_libye", "name": "Misrata, Libye", "lat": 32.37, "lon": 15.09},
    {"id": "alexandria_egypte", "name": "Alexandrie, Egypte", "lat": 31.20, "lon": 29.92},
    {"id": "portsaid_egypte", "name": "Port Said, Egypte", "lat": 31.26, "lon": 32.29},
    {"id": "marsamatruh_egypte", "name": "Marsa Matruh, Egypte", "lat": 31.35, "lon": 27.24},
    {"id": "nouadhibou_mauritanie", "name": "Nouadhibou, Mauritanie", "lat": 20.93, "lon": -17.03},
    {"id": "nouakchott_mauritanie", "name": "Nouakchott, Mauritanie", "lat": 18.08, "lon": -15.98},
    {"id": "dakar_senegal", "name": "Dakar, Sénégal", "lat": 14.69, "lon": -17.44},
    {"id": "saintlouis_senegal", "name": "Saint-Louis, Sénégal", "lat": 16.03, "lon": -16.49},
    {"id": "thies_senegal", "name": "Mbour, Sénégal", "lat": 14.42, "lon": -16.97},

    # === Afrique de l'Ouest (Golfe de Guinée) ===
    {"id": "banjul_gambie", "name": "Banjul, Gambie", "lat": 13.45, "lon": -16.58},
    {"id": "bissau_guinee_bissau", "name": "Bissau, Guinée-Bissau", "lat": 11.86, "lon": -15.60},
    {"id": "conakry_guinee", "name": "Conakry, Guinée", "lat": 9.64, "lon": -13.58},
    {"id": "freetown_sierra_leone", "name": "Freetown, Sierra Leone", "lat": 8.48, "lon": -13.23},
    {"id": "monrovia_liberia", "name": "Monrovia, Libéria", "lat": 6.30, "lon": -10.80},
    {"id": "abidjan_cote_ivoire", "name": "Abidjan, Côte d'Ivoire", "lat": 5.36, "lon": -4.01},
    {"id": "sanpedro_cote_ivoire", "name": "San-Pédro, Côte d'Ivoire", "lat": 4.75, "lon": -6.64},
    {"id": "accra_ghana", "name": "Accra, Ghana", "lat": 5.60, "lon": -0.17},
    {"id": "takoradi_ghana", "name": "Takoradi, Ghana", "lat": 4.90, "lon": -1.76},
    {"id": "lome_togo", "name": "Lomé, Togo", "lat": 6.13, "lon": 1.22},
    {"id": "cotonou_benin", "name": "Cotonou, Bénin", "lat": 6.37, "lon": 2.43},
    {"id": "lagos_nigeria", "name": "Lagos, Nigéria", "lat": 6.45, "lon": 3.40},
    # Bonny est l'accès maritime de Port Harcourt, hors des cellules du delta
    # qui sont classées terrestres par le modèle marin.
    {"id": "portharcourt_nigeria", "name": "Bonny (Port Harcourt), Nigéria", "lat": 4.45, "lon": 7.17},
    {"id": "douala_cameroun", "name": "Douala, Cameroun", "lat": 4.05, "lon": 9.70},
    {"id": "limbe_cameroun", "name": "Limbé, Cameroun", "lat": 4.02, "lon": 9.22},
    {"id": "malabo_guinee_equatoriale", "name": "Malabo, Guinée Équatoriale", "lat": 3.75, "lon": 8.78},
    {"id": "libreville_gabon", "name": "Libreville, Gabon", "lat": 0.39, "lon": 9.45},
    {"id": "portgentil_gabon", "name": "Port-Gentil, Gabon", "lat": -0.72, "lon": 8.78},
    {"id": "pointe_noire_congo", "name": "Pointe-Noire, Congo", "lat": -4.78, "lon": 11.86},
    {"id": "luanda_angola", "name": "Luanda, Angola", "lat": -8.84, "lon": 13.23},
    {"id": "benguela_angola", "name": "Benguela, Angola", "lat": -12.58, "lon": 13.40},
    {"id": "lobito_angola", "name": "Lobito, Angola", "lat": -12.35, "lon": 13.55},
    {"id": "namibe_angola", "name": "Namibe, Angola", "lat": -15.20, "lon": 12.15},

    # === Afrique australe ===
    {"id": "walvisbay_namibie", "name": "Walvis Bay, Namibie", "lat": -22.96, "lon": 14.51},
    {"id": "swakopmund_namibie", "name": "Swakopmund, Namibie", "lat": -22.68, "lon": 14.53},
    {"id": "capetown_afrique_sud", "name": "Le Cap, Afrique du Sud", "lat": -33.92, "lon": 18.42},
    {"id": "durban_afrique_sud", "name": "Durban, Afrique du Sud", "lat": -29.86, "lon": 31.03},
    {"id": "portelizabeth_afrique_sud", "name": "Port Elizabeth, Afrique du Sud", "lat": -33.96, "lon": 25.60},
    {"id": "eastlondon_afrique_sud", "name": "East London, Afrique du Sud", "lat": -33.02, "lon": 27.90},
    {"id": "mosselbay_afrique_sud", "name": "Mossel Bay, Afrique du Sud", "lat": -34.18, "lon": 22.13},
    {"id": "maputo_mozambique", "name": "Maputo, Mozambique", "lat": -25.97, "lon": 32.59},
    {"id": "beira_mozambique", "name": "Beira, Mozambique", "lat": -19.83, "lon": 34.84},
    {"id": "nampula_mozambique", "name": "Nacala, Mozambique", "lat": -14.54, "lon": 40.67},
    {"id": "dar_essalaam_tanzanie", "name": "Dar es Salaam, Tanzanie", "lat": -6.79, "lon": 39.21},
    {"id": "zanzibar_tanzanie", "name": "Zanzibar, Tanzanie", "lat": -6.16, "lon": 39.19},
    {"id": "mombasa_kenya", "name": "Mombasa, Kenya", "lat": -4.04, "lon": 39.67},
    {"id": "malindi_kenya", "name": "Malindi, Kenya", "lat": -3.22, "lon": 40.12},
    {"id": "mogadiscio_somalie", "name": "Mogadiscio, Somalie", "lat": 2.04, "lon": 45.34},
    {"id": "berbera_somaliland", "name": "Berbera, Somaliland", "lat": 10.44, "lon": 45.01},
    {"id": "djibouti_ville", "name": "Djibouti, Djibouti", "lat": 11.59, "lon": 43.15},

    # === Afrique de l'Est / Océan Indien ===
    {"id": "portlouis_maurice", "name": "Port Louis, Maurice", "lat": -20.16, "lon": 57.50},
    {"id": "saintdenis_reunion", "name": "Saint-Denis, Réunion", "lat": -20.88, "lon": 55.45},
    {"id": "toamasina_madagascar", "name": "Toamasina, Madagascar", "lat": -18.15, "lon": 49.40},
    {"id": "antananarivo_madagascar", "name": "Mahajanga, Madagascar", "lat": -15.72, "lon": 46.32},
    {"id": "male_maldives", "name": "Malé, Maldives", "lat": 4.18, "lon": 73.51},
    {"id": "victoria_seychelles", "name": "Victoria, Seychelles", "lat": -4.62, "lon": 55.45},

    # === Moyen-Orient / Proche-Orient ===
    {"id": "jedda_arabie_saoudite", "name": "Jeddah, Arabie Saoudite", "lat": 21.54, "lon": 39.17},
    {"id": "yanbu_arabie_saoudite", "name": "Yanbu, Arabie Saoudite", "lat": 24.09, "lon": 38.06},
    {"id": "dammam_arabie_saoudite", "name": "Dammam, Arabie Saoudite", "lat": 26.42, "lon": 50.10},
    {"id": "jubail_arabie_saoudite", "name": "Jubail, Arabie Saoudite", "lat": 27.00, "lon": 49.66},
    {"id": "dubai_emirats", "name": "Dubaï, EAU", "lat": 25.20, "lon": 55.27},
    {"id": "abudhabi_emirats", "name": "Abou Dhabi, EAU", "lat": 24.45, "lon": 54.38},
    {"id": "sharjah_emirats", "name": "Sharjah, EAU", "lat": 25.35, "lon": 55.39},
    {"id": "fujairah_emirats", "name": "Fujairah, EAU", "lat": 25.13, "lon": 56.33},
    {"id": "muscat_oman", "name": "Mascate, Oman", "lat": 23.61, "lon": 58.59},
    {"id": "salalah_oman", "name": "Salalah, Oman", "lat": 17.02, "lon": 54.09},
    {"id": "sohar_oman", "name": "Sohar, Oman", "lat": 24.36, "lon": 56.75},
    {"id": "doha_qatar", "name": "Doha, Qatar", "lat": 25.29, "lon": 51.53},
    {"id": "manama_bahrein", "name": "Manama, Bahreïn", "lat": 26.22, "lon": 50.59},
    {"id": "koweit_city_koweit", "name": "Koweït City, Koweït", "lat": 29.37, "lon": 47.98},
    # Al-Faw est l'accès maritime de la province de Bassorah. La coordonnée du
    # centre-ville de Bassorah est trop éloignée de la mer pour GFS-Wave.
    {"id": "basra_irak", "name": "Al-Faw (Bassorah), Irak", "lat": 29.97, "lon": 48.47},
    {"id": "aden_yemen", "name": "Aden, Yémen", "lat": 12.78, "lon": 45.03},
    {"id": "mukalla_yemen", "name": "Mukalla, Yémen", "lat": 14.54, "lon": 49.13},
    {"id": "hodeidah_yemen", "name": "Al Hudaydah, Yémen", "lat": 14.80, "lon": 42.95},
    {"id": "port_soudan_soudan", "name": "Port-Soudan, Soudan", "lat": 19.62, "lon": 37.22},
    # Le nord du golfe est plus étroit que la grille GFS-Wave. Ces points,
    # toujours proches des deux villes, sont associés à une cellule marine.
    {"id": "aqaba_jordanie", "name": "Aqaba, Jordanie", "lat": 29.45, "lon": 35.00},
    {"id": "eilat_israel", "name": "Eilat, Israël", "lat": 29.48, "lon": 34.94},
    {"id": "telaviv_israel", "name": "Tel Aviv, Israël", "lat": 32.09, "lon": 34.78},
    {"id": "haifa_israel", "name": "Haïfa, Israël", "lat": 32.82, "lon": 34.99},
    {"id": "beyrouth_liban", "name": "Beyrouth, Liban", "lat": 33.89, "lon": 35.50},
    {"id": "tripoli_liban", "name": "Tripoli, Liban", "lat": 34.44, "lon": 35.84},
    {"id": "saida_liban", "name": "Saïda, Liban", "lat": 33.56, "lon": 35.37},
    {"id": "lattaquie_syrie", "name": "Lattaquié, Syrie", "lat": 35.52, "lon": 35.78},
    {"id": "tartous_syrie", "name": "Tartous, Syrie", "lat": 34.89, "lon": 35.89},
    {"id": "istanbul_turquie", "name": "Istanbul, Turquie", "lat": 41.01, "lon": 28.98},
    {"id": "izmir_turquie", "name": "Izmir, Turquie", "lat": 38.42, "lon": 27.14},
    {"id": "antalya_turquie", "name": "Antalya, Turquie", "lat": 36.90, "lon": 30.70},
    {"id": "mersin_turquie", "name": "Mersin, Turquie", "lat": 36.80, "lon": 34.63},
    {"id": "samsun_turquie", "name": "Samsun, Turquie", "lat": 41.29, "lon": 36.33},
    {"id": "trabzon_turquie", "name": "Trabzon, Turquie", "lat": 41.00, "lon": 39.72},
    {"id": "bodrum_turquie", "name": "Bodrum, Turquie", "lat": 37.03, "lon": 27.43},
    {"id": "larnaca_chypre", "name": "Larnaca, Chypre", "lat": 34.92, "lon": 33.63},
    {"id": "limassol_chypre", "name": "Limassol, Chypre", "lat": 34.68, "lon": 33.04},
    {"id": "sharm_el_sheikh_egypte", "name": "Sharm El-Sheikh, Egypte", "lat": 27.97, "lon": 34.39},
    {"id": "hurgada_egypte", "name": "Hurghada, Egypte", "lat": 27.26, "lon": 33.81},
]

FORECAST_DAYS = 15
STEP_HOURS = 3  # on garde 1 creneau toutes les 3h, comme sur le tableau Windguru
MS_TO_KNOTS = 1.94384
MAX_HTTP_ATTEMPTS = 3
HTTP_TIMEOUT = (10, 60)  # secondes : connexion, puis lecture
MAX_STATION_WORKERS = 6
RETRYABLE_HTTP_STATUSES = {408, 425, 429, 500, 502, 503, 504}
_HTTP_LOCAL = threading.local()

# Chaque point côtier dispose de son propre document léger `conditions/{id}`.
# L'identifiant reste strictement identique dans le catalogue, Firestore et le
# client Flutter : aucune ville ne peut ainsi recevoir silencieusement les
# données d'une autre station.
CONDITIONS_SPOT_IDS = {spot["id"]: spot["id"] for spot in SPOTS}
# Compatibilité temporaire avec BoosterFish 1.0.9 (24), qui lit encore ces
# cinq identifiants courts. Ces alias reçoivent exactement le même document que
# leur station canonique, sans nouvel appel Open-Meteo. Ils pourront être
# retirés seulement après la fin du test fermé et l'adoption de la version 25.
LEGACY_CONDITIONS_ALIASES = {
    "casablanca_maroc": "casablanca",
    "rabat_maroc": "rabat",
    "agadir_maroc": "agadir",
    "tanger_maroc": "tanger",
    "essaouira_maroc": "essaouira",
}
# La météo générale reste publiée sur dix jours. L'API Marine documente en
# revanche un maximum de huit jours : la page Marées se limite donc à cette
# fenêtre complète au lieu de fabriquer ou d'afficher des niveaux manquants.
PUBLISHED_FORECAST_DAYS = 10
CONDITIONS_FORECAST_DAYS = 8
EXPECTED_SLOTS_PER_DAY = 24 // STEP_HOURS
FRESHNESS_CLOCK_SKEW = timedelta(minutes=5)


def _effective_conditions_aliases(conditions_spot_ids, aliases):
    """N'active les alias historiques que pour la configuration Production."""
    if aliases is not None:
        return aliases
    return (
        LEGACY_CONDITIONS_ALIASES
        if conditions_spot_ids is CONDITIONS_SPOT_IDS
        else {}
    )


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _base_params(lat, lon):
    """Params communs a tous les appels forecast."""
    p = {
        "latitude": lat,
        "longitude": lon,
        "timezone": "auto",
        "forecast_days": FORECAST_DAYS,
    }
    if OPEN_METEO_API_KEY:
        p["apikey"] = OPEN_METEO_API_KEY
    return p


def ms_to_knots(v):
    return round(v * MS_TO_KNOTS, 1) if v is not None else None


def compute_rating(wind_kt, wave_m, precip_pct):
    """Note simplifiee sur 5 etoiles, uniquement si elle est complète."""
    if wind_kt is None or wave_m is None or precip_pct is None:
        return None
    score = 0
    if 8 <= wind_kt <= 22:
        score += 2
    elif 5 <= wind_kt < 8 or 22 < wind_kt <= 28:
        score += 1
    if 0.5 <= wave_m <= 2.5:
        score += 2
    elif wave_m < 0.5:
        score += 1
    if precip_pct < 30:
        score += 1
    return max(0, min(5, score))


def _safe_num(v, default=None):
    """Extrait un float d'une valeur, retourne default si None."""
    if v is None:
        return default
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def _hourly_num(hourly, key, index, default=None):
    """Lit une variable horaire optionnelle sans faire échouer la récolte."""
    values = hourly.get(key)
    if not isinstance(values, (list, tuple)) or index >= len(values):
        return default
    return _safe_num(values[index], default)


def _open_meteo_timezone(timezone_name, utc_offset_seconds=0):
    """Retourne le fuseau IANA de la réponse, ou le décalage historique.

    ``utc_offset_seconds`` reste accepté pour les anciens documents/tests et
    pour une éventuelle réponse dépourvue de nom de fuseau. Une réponse qui
    annonce un nom IANA invalide échoue volontairement : utiliser alors le
    décalage unique pourrait décaler silencieusement une partie des 15 jours.
    """
    if isinstance(timezone_name, str) and timezone_name.strip():
        try:
            return ZoneInfo(timezone_name.strip())
        except ZoneInfoNotFoundError as error:
            raise ValueError(
                f"Fuseau Open-Meteo inconnu : {timezone_name!r}."
            ) from error
    return timezone(timedelta(seconds=int(utc_offset_seconds or 0)))


def _utc_candidates_for_local(local_time, station_timezone):
    """Instants UTC valides correspondant à une heure civile locale."""
    if local_time.tzinfo is not None:
        return [local_time.astimezone(timezone.utc)]

    candidates = []
    for fold in (0, 1):
        aware = local_time.replace(tzinfo=station_timezone, fold=fold)
        candidate = aware.astimezone(timezone.utc)
        # Un aller-retour élimine les heures inexistantes du passage à
        # l'heure d'été. Les deux folds restent disponibles lors du retour à
        # l'heure standard.
        round_trip = candidate.astimezone(station_timezone).replace(tzinfo=None)
        if round_trip == local_time and candidate not in candidates:
            candidates.append(candidate)
    return sorted(candidates)


def _utc_datetimes_from_open_meteo(
    local_timestamps,
    utc_offset_seconds=0,
    timezone_name=None,
):
    """Résout une série locale Open-Meteo en instants UTC non ambigus.

    L'ordre de la série permet de distinguer les deux occurrences d'une heure
    répétée à la fin de l'heure d'été. Une heure civile inexistante ou une
    série qui recule fait échouer la récolte avant toute écriture Firestore.
    """
    station_timezone = _open_meteo_timezone(
        timezone_name,
        utc_offset_seconds,
    )
    resolved = []
    previous = None
    for raw_timestamp in local_timestamps:
        if not isinstance(raw_timestamp, str) or not raw_timestamp.strip():
            raise ValueError("Horodatage Open-Meteo absent ou invalide.")
        try:
            local_time = datetime.fromisoformat(raw_timestamp)
        except ValueError as error:
            raise ValueError(
                f"Horodatage Open-Meteo invalide : {raw_timestamp!r}."
            ) from error

        candidates = _utc_candidates_for_local(local_time, station_timezone)
        if previous is not None:
            candidates = [candidate for candidate in candidates if candidate > previous]
        if not candidates:
            raise ValueError(
                "Impossible de résoudre sans ambiguïté l'heure locale "
                f"Open-Meteo {raw_timestamp!r} dans {timezone_name or 'le fuseau fixe'}."
            )
        selected = candidates[0]
        resolved.append(selected)
        previous = selected
    return resolved


def _utc_iso(instant):
    return instant.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def _parse_utc_instant(raw_timestamp, label="instant UTC"):
    if not isinstance(raw_timestamp, str) or not raw_timestamp.strip():
        raise ValueError(f"{label} absent ou invalide.")
    try:
        parsed = datetime.fromisoformat(raw_timestamp.replace("Z", "+00:00"))
    except ValueError as error:
        raise ValueError(f"{label} invalide : {raw_timestamp!r}.") from error
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError(f"{label} doit contenir un décalage UTC explicite.")
    return parsed.astimezone(timezone.utc)


def _expected_utc_grid_instants(
    first_local_date,
    day_count,
    station_timezone,
    *,
    step_hours,
):
    """Instants d'une grille UTC appartenant à des dates civiles locales."""
    last_local_date = first_local_date + timedelta(days=day_count)
    # Deux jours de marge couvrent tous les décalages IANA actuels, y compris
    # les changements exceptionnels de date civile.
    cursor = datetime.combine(
        first_local_date - timedelta(days=2),
        datetime.min.time(),
        tzinfo=timezone.utc,
    )
    end = datetime.combine(
        last_local_date + timedelta(days=2),
        datetime.min.time(),
        tzinfo=timezone.utc,
    )
    remainder = cursor.hour % step_hours
    if remainder:
        cursor += timedelta(hours=step_hours - remainder)

    expected = []
    while cursor < end:
        local_date = cursor.astimezone(station_timezone).date()
        if first_local_date <= local_date < last_local_date:
            expected.append(cursor)
        cursor += timedelta(hours=step_hours)
    return expected


def _is_native_gfs_instant(utc_time):
    return (
        utc_time.second == 0
        and utc_time.microsecond == 0
        and utc_time.minute == 0
        and utc_time.hour % STEP_HOURS == 0
    )


def _is_native_gfs_step(
    local_timestamp,
    utc_offset_seconds,
    timezone_name=None,
):
    """Indique si une heure locale correspond à un pas GFS UTC de 3 h.

    Open-Meteo renvoie les horodatages dans le fuseau demandé. La grille GFS
    reste toutefois calée sur 00/03/06 UTC. À Casablanca (UTC+1), les créneaux
    comparables sont donc 01/04/07, et non 00/03/06.
    """
    utc_time = _utc_datetimes_from_open_meteo(
        [local_timestamp],
        utc_offset_seconds,
        timezone_name,
    )[0]
    return _is_native_gfs_instant(utc_time)


def _error_summary(error):
    """Résumé sûr pour les logs : ne jamais imprimer une URL avec apikey."""
    if isinstance(error, ValueError):
        # Les messages de validation sont générés localement et ne contiennent
        # ni URL ni clé API. Ils sont indispensables au diagnostic des données.
        return f"ValueError: {error}"
    status = getattr(error, "status_code", None)
    if status is not None:
        return f"HTTP {status} ({type(error).__name__})"
    response = getattr(error, "response", None)
    status = getattr(response, "status_code", None)
    if status is not None:
        return f"HTTP {status} ({type(error).__name__})"
    return type(error).__name__


class OpenMeteoHttpError(RuntimeError):
    """Erreur HTTP volontairement dépourvue d'URL et de paramètres secrets."""

    def __init__(self, status_code):
        super().__init__(f"Open-Meteo HTTP {status_code}")
        self.status_code = status_code


def _http_session():
    """Retourne une Session propre au thread pour réutiliser les connexions."""
    session = getattr(_HTTP_LOCAL, "session", None)
    if session is None:
        session = requests.Session()
        adapter = requests.adapters.HTTPAdapter(
            pool_connections=3,
            pool_maxsize=3,
        )
        session.mount("https://", adapter)
        _HTTP_LOCAL.session = session
    return session


# ---------------------------------------------------------------------------
# 2. Fonctions de fetch par modele
# ---------------------------------------------------------------------------
HOURLY_COMMON_WIND = (
    "wind_speed_10m,wind_gusts_10m,wind_direction_10m,"
    "temperature_2m,cloud_cover_low,cloud_cover_mid,cloud_cover_high,"
    "precipitation_probability,pressure_msl,relative_humidity_2m"
)

# Les trois mesures supplémentaires sont demandées uniquement au GFS, qui
# les publie officiellement. Le flux ECMWF reste inchangé afin qu'une variable
# optionnelle non prise en charge ne bloque jamais la récolte haute résolution.
HOURLY_GFS_WIND = (
    f"{HOURLY_COMMON_WIND},cloud_cover,precipitation,visibility,weather_code,is_day"
)

HOURLY_WAVE = (
    "wave_height,wave_period,wave_direction,"
    "swell_wave_height,swell_wave_period,swell_wave_direction,"
    "secondary_swell_wave_height,secondary_swell_wave_period,"
    "secondary_swell_wave_direction,"
    "wind_wave_height,wind_wave_period,wind_wave_direction,"
    "sea_surface_temperature,ocean_current_velocity,ocean_current_direction,"
    "sea_level_height_msl"
)


def _fetch_json(
    url,
    params,
    *,
    requester=None,
    sleeper=None,
    jitter=None,
    max_attempts=MAX_HTTP_ATTEMPTS,
):
    """
    Appel HTTP résilient sans exposer la clé apikey dans les erreurs.

    Les délais réseau et les erreurs temporaires (429/5xx) sont retentés avec
    un recul exponentiel borné. Les erreurs client permanentes (autres 4xx)
    échouent immédiatement.
    """
    if requester is None:
        requester = _http_session().get
    if sleeper is None:
        sleeper = time.sleep
    if jitter is None:
        jitter = lambda: random.uniform(0.0, 0.25)
    if max_attempts < 1:
        raise ValueError("max_attempts doit être supérieur ou égal à 1.")

    last_error = None
    for attempt in range(1, max_attempts + 1):
        try:
            response = requester(url, params=params, timeout=HTTP_TIMEOUT)
            if response.ok:
                return response.json()

            error = OpenMeteoHttpError(response.status_code)
            if response.status_code not in RETRYABLE_HTTP_STATUSES:
                raise error
            last_error = error
        except (requests.Timeout, requests.ConnectionError) as error:
            last_error = error
        except ValueError as error:
            # Une réponse temporairement tronquée peut produire un JSON
            # invalide. Elle est retentée comme une erreur réseau.
            last_error = error
        except requests.RequestException:
            # Une autre erreur requests est considérée permanente : cela évite
            # de masquer une mauvaise configuration ou une requête invalide.
            raise

        if attempt == max_attempts:
            raise last_error

        delay_seconds = (2 ** (attempt - 1)) + jitter()
        sleeper(delay_seconds)

    raise RuntimeError("État de reprise HTTP inattendu.")


def fetch_wind_model(lat, lon):
    """GFS ~13km — modele vent principal."""
    url = FORECAST_BASE_URL
    params = _base_params(lat, lon)
    params.update({
        "hourly": HOURLY_GFS_WIND,
        "daily": "sunrise,sunset",
        "wind_speed_unit": "ms",
        "models": "gfs_seamless",
    })
    return _fetch_json(url, params)


def fetch_hires_model(lat, lon):
    """ECMWF IFS-HRES ~9km — modele haute resolution."""
    url = FORECAST_BASE_URL
    params = _base_params(lat, lon)
    params.update({
        "hourly": HOURLY_COMMON_WIND,
        "wind_speed_unit": "ms",
        "models": "ecmwf_ifs",
    })
    return _fetch_json(url, params)


def fetch_wave_model(lat, lon):
    """GFS-Wave ~25km — modele vagues."""
    url = MARINE_BASE_URL
    params = _base_params(lat, lon)
    params.update({
        "hourly": HOURLY_WAVE,
        # Explicite même si l'API Marine utilise actuellement `sea` par défaut.
        # Cette option empêche une future évolution de valeur par défaut de
        # sélectionner une cellule terrestre pour une ville côtière.
        "cell_selection": "sea",
    })
    return _fetch_json(url, params)


def _fetch_station_models(spot, fetchers=None):
    """Récupère les trois modèles et s'arrête au premier échec."""
    if fetchers is None:
        fetchers = (
            ("wind", fetch_wind_model),
            ("hires", fetch_hires_model),
            ("wave", fetch_wave_model),
        )

    results = {}
    errors = {}
    for model_name, fetcher in fetchers:
        try:
            results[model_name] = fetcher(spot["lat"], spot["lon"])
        except Exception as error:
            results[model_name] = None
            errors[model_name] = error
            # Inutile de consommer deux autres appels commerciaux lorsque la
            # station ne pourra de toute façon pas être publiée. Le consommateur
            # interrompt ensuite le run avant toute écriture Firestore.
            break
    return {
        "spot": spot,
        "models": results,
        "errors": errors,
    }


def _iter_station_results(spots, max_workers=MAX_STATION_WORKERS):
    """
    Exécute un nombre borné de stations en parallèle.

    Seuls ``max_workers`` payloads complets sont conservés simultanément afin
    d'éviter une hausse de mémoire avec les réponses horaires sur 15 jours.
    """
    if max_workers < 1:
        raise ValueError("max_workers doit être supérieur ou égal à 1.")

    spots_iterator = iter(spots)
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        pending = {}

        def submit_next():
            try:
                next_spot = next(spots_iterator)
            except StopIteration:
                return False
            future = executor.submit(_fetch_station_models, next_spot)
            pending[future] = next_spot
            return True

        for _ in range(max_workers):
            if not submit_next():
                break

        while pending:
            completed, _ = wait(pending, return_when=FIRST_COMPLETED)
            for future in completed:
                spot = pending.pop(future)
                try:
                    yield future.result()
                except Exception as error:
                    # Un défaut inattendu du worker invalide le run complet.
                    # Les futures encore en attente ne déclenchent aucune
                    # écriture : la publication globale intervient seulement
                    # après consommation et validation de tous les résultats.
                    for pending_future in pending:
                        pending_future.cancel()
                    raise RuntimeError(
                        f"Récolte interrompue pour {spot['id']} : "
                        "erreur inattendue du worker."
                    ) from error
                submit_next()


# ---------------------------------------------------------------------------
# 3. Extraction du sous-objet "models" pour un slot donne
# ---------------------------------------------------------------------------
def _extract_wind_model_slot(wind_data, wind_by_time, t):
    """Extrait les champs du modele vent GFS pour un timestamp donne."""
    i = wind_by_time.get(t)
    if i is None:
        return None
    h = wind_data["hourly"]
    return {
        "wind_speed_kt": ms_to_knots(_safe_num(h["wind_speed_10m"][i])),
        "wind_gust_kt": ms_to_knots(_safe_num(h["wind_gusts_10m"][i])),
        "wind_dir_deg": _safe_num(h["wind_direction_10m"][i]),
        "temp_c": _safe_num(h["temperature_2m"][i], None),
        "cloud_low_pct": _safe_num(h["cloud_cover_low"][i]),
        "cloud_mid_pct": _safe_num(h["cloud_cover_mid"][i]),
        "cloud_high_pct": _safe_num(h["cloud_cover_high"][i]),
        "cloud_total_pct": _hourly_num(h, "cloud_cover", i),
        "precipitation_mm": _hourly_num(h, "precipitation", i),
        "precip_prob_pct": _safe_num(h["precipitation_probability"][i]),
        "pressure_msl": _safe_num(h["pressure_msl"][i]),
        "rel_humidity_pct": _safe_num(h["relative_humidity_2m"][i]),
        "visibility_m": _hourly_num(h, "visibility", i),
        "weather_code": _hourly_num(h, "weather_code", i),
        "is_day": _hourly_num(h, "is_day", i),
    }


def _extract_hires_model_slot(hires_data, hires_by_time, t):
    """Extrait les champs du modele haute resolution pour un timestamp donne."""
    i = hires_by_time.get(t)
    if i is None:
        return None
    h = hires_data["hourly"]
    return {
        "wind_speed_kt": ms_to_knots(_safe_num(h["wind_speed_10m"][i])),
        "wind_gust_kt": ms_to_knots(_safe_num(h["wind_gusts_10m"][i])),
        "wind_dir_deg": _safe_num(h["wind_direction_10m"][i]),
        "temp_c": _safe_num(h["temperature_2m"][i], None),
        "cloud_low_pct": _safe_num(h["cloud_cover_low"][i]),
        "cloud_mid_pct": _safe_num(h["cloud_cover_mid"][i]),
        "cloud_high_pct": _safe_num(h["cloud_cover_high"][i]),
        "cloud_total_pct": _hourly_num(h, "cloud_cover", i),
        "precipitation_mm": _hourly_num(h, "precipitation", i),
        "precip_prob_pct": _safe_num(h["precipitation_probability"][i]),
        "pressure_msl": _safe_num(h["pressure_msl"][i]),
        "rel_humidity_pct": _safe_num(h["relative_humidity_2m"][i]),
        "visibility_m": _hourly_num(h, "visibility", i),
    }


def _extract_wave_model_slot(wave_data, wave_by_time, t):
    """Extrait les champs du modele vagues pour un timestamp donne."""
    i = wave_by_time.get(t)
    if i is None:
        return None
    h = wave_data["hourly"]
    return {
        "wave_height_m": _safe_num(h["wave_height"][i]),
        "wave_period_s": _safe_num(h["wave_period"][i]),
        "wave_dir_deg": _safe_num(h["wave_direction"][i]),
        "swell_height_m": _safe_num(h["swell_wave_height"][i]),
        "swell_period_s": _safe_num(h["swell_wave_period"][i]),
        "swell_dir_deg": _safe_num(h["swell_wave_direction"][i]),
        "swell2_height_m": _safe_num(h["secondary_swell_wave_height"][i]),
        "swell2_period_s": _safe_num(h["secondary_swell_wave_period"][i]),
        "swell2_dir_deg": _safe_num(h["secondary_swell_wave_direction"][i]),
        "windwave_height_m": _safe_num(h["wind_wave_height"][i]),
        "windwave_period_s": _safe_num(h["wind_wave_period"][i]),
        "windwave_dir_deg": _safe_num(h["wind_wave_direction"][i]),
        "sst_c": _safe_num(h["sea_surface_temperature"][i]),
        "ocean_current_velocity_kmh": _hourly_num(
            h, "ocean_current_velocity", i
        ),
        "ocean_current_direction_deg": _hourly_num(
            h, "ocean_current_direction", i
        ),
        "sea_level_height_msl": _hourly_num(h, "sea_level_height_msl", i),
    }


# ---------------------------------------------------------------------------
# 4. Fusion des 3 modeles + champs racine historiques
# ---------------------------------------------------------------------------
def build_days_payload(
    wind_json,
    hires_json,
    wave_json,
    daily_json,
    *,
    reference_time=None,
):
    """
    wind_json  : reponse GFS (contient aussi sunrise/sunset dans daily)
    hires_json : reponse ECMWF IFS
    wave_json  : reponse GFS-Wave
    daily_json : dict {"2026-07-08": {"sunrise": ..., "sunset": ...}, ...}
    Retourne :
      - days_payload : liste de jours avec slots
      - water_temp_c : float ou None
    """
    w_data = wind_json["hourly"]
    h_data = hires_json["hourly"]
    m_data = wave_json["hourly"]

    days = defaultdict(list)
    reference_time = reference_time or datetime.now(timezone.utc)
    if reference_time.tzinfo is None:
        reference_time = reference_time.replace(tzinfo=timezone.utc)
    else:
        reference_time = reference_time.astimezone(timezone.utc)
    water_temp_values = []
    utc_offset_seconds = int(
        _safe_num(wind_json.get("utc_offset_seconds"), 0) or 0
    )
    wind_timezone_name = wind_json.get("timezone")
    wind_utc_times = _utc_datetimes_from_open_meteo(
        w_data["time"],
        utc_offset_seconds,
        wind_timezone_name,
    )
    hires_utc_times = _utc_datetimes_from_open_meteo(
        h_data["time"],
        int(_safe_num(hires_json.get("utc_offset_seconds"), 0) or 0),
        hires_json.get("timezone"),
    )
    wave_utc_times = _utc_datetimes_from_open_meteo(
        m_data["time"],
        int(_safe_num(wave_json.get("utc_offset_seconds"), 0) or 0),
        wave_json.get("timezone"),
    )
    wind_by_time = {instant: i for i, instant in enumerate(wind_utc_times)}
    hires_by_time = {instant: i for i, instant in enumerate(hires_utc_times)}
    wave_by_time = {instant: i for i, instant in enumerate(wave_utc_times)}

    for i, (t, utc_time) in enumerate(zip(w_data["time"], wind_utc_times)):
        if not _is_native_gfs_instant(utc_time):
            continue

        # --- modele vent GFS (utilise comme champs racine pour compat arriere) ---
        wind_kt = ms_to_knots(_safe_num(w_data["wind_speed_10m"][i]))
        gust_kt = ms_to_knots(_safe_num(w_data["wind_gusts_10m"][i]))
        wind_dir = _safe_num(w_data["wind_direction_10m"][i])
        temp_c = _safe_num(w_data["temperature_2m"][i], None)
        precip = _safe_num(w_data["precipitation_probability"][i])

        # --- modele vagues (houle primaire pour champs racine) ---
        mi = wave_by_time.get(utc_time)
        wave_h = _safe_num(m_data["wave_height"][mi]) if mi is not None else None
        wave_p = _safe_num(m_data["wave_period"][mi]) if mi is not None else None
        wave_d = _safe_num(m_data["wave_direction"][mi]) if mi is not None else None

        # SST
        sst = _safe_num(m_data["sea_surface_temperature"][mi]) if mi is not None else None
        if sst is not None:
            water_temp_values.append(
                (
                    abs((utc_time - reference_time).total_seconds()),
                    sst,
                )
            )

        # --- sous-objet models ---
        wind_slot = _extract_wind_model_slot(wind_json, wind_by_time, utc_time)
        hires_slot = _extract_hires_model_slot(hires_json, hires_by_time, utc_time)
        wave_slot = _extract_wave_model_slot(wave_json, wave_by_time, utc_time)

        # --- cloud_pct pour champs racine (on utilise low+mid+high du modele vent) ---
        cloud_total = _hourly_num(w_data, "cloud_cover", i)
        if cloud_total is None:
            cloud_layers = [
                value
                for value in (
                    _safe_num(w_data["cloud_cover_low"][i]),
                    _safe_num(w_data["cloud_cover_mid"][i]),
                    _safe_num(w_data["cloud_cover_high"][i]),
                )
                if value is not None
            ]
            cloud_total = max(cloud_layers) if cloud_layers else None

        slot = {
            # champs racine (compat arriere)
            "hour": t,
            # Champ additif : la v1.0.9 (24) continue de lire `hour`, tandis
            # que les nouveaux consommateurs disposent d'un instant absolu.
            "hour_utc": _utc_iso(utc_time),
            "wind_speed_kt": wind_kt,
            "wind_gust_kt": gust_kt,
            "wind_dir_deg": wind_dir,
            "wave_height_m": wave_h,
            "wave_period_s": wave_p,
            "wave_dir_deg": wave_d,
            "temp_c": round(temp_c) if temp_c is not None else None,
            "cloud_pct": round(cloud_total) if cloud_total is not None else None,
            "precip_pct": precip,
            "weather_code": _hourly_num(w_data, "weather_code", i),
            "is_day": _hourly_num(w_data, "is_day", i),
            "rating": compute_rating(wind_kt, wave_h, precip),
            # nouveau sous-objet additif
            "models": {
                "wind": wind_slot,
                "hires": hires_slot,
                "wave": wave_slot,
            },
        }

        day_key = t[:10]
        days[day_key].append(slot)

    # Construire les jours triés
    days_payload = []
    for d, slots in sorted(days.items()):
        day_info = {"date": d, "slots": slots}
        if d in daily_json:
            day_info["sunrise"] = daily_json[d].get("sunrise")
            day_info["sunset"] = daily_json[d].get("sunset")
        days_payload.append(day_info)

    # La valeur racine est présentée comme la température actuelle dans
    # Marées Pro. Choisir le créneau le plus proche de l'heure du run évite
    # d'afficher comme actuelle une SST située plusieurs jours dans le futur.
    water_temp_c = (
        round(min(water_temp_values, key=lambda item: item[0])[1], 1)
        if water_temp_values
        else None
    )
    return days_payload, water_temp_c


# ---------------------------------------------------------------------------
# 5. Validation
# ---------------------------------------------------------------------------
def validate_payload(
    days_payload,
    utc_offset_seconds=0,
    required_days=PUBLISHED_FORECAST_DAYS,
    timezone_name=None,
):
    """Valide la structure servie par l'application avant toute écriture.

    Les échéances GFS natives sont espacées de trois heures en UTC. Le nom IANA
    renvoyé par Open-Meteo est utilisé pour chaque créneau : un changement
    d'heure inclus dans la fenêtre ne dépend donc jamais du décalage unique de
    tête de réponse.

    La validation historique de couverture vent/vagues reste appliquée à
    l'ensemble du payload après les contrôles structurels des dix premiers
    jours.
    """
    if not isinstance(days_payload, list) or len(days_payload) < required_days:
        raise ValueError(
            f"Prévisions insuffisantes : {len(days_payload or [])} jour(s), "
            f"{required_days} requis."
        )

    if any(not isinstance(day, dict) for day in days_payload):
        raise ValueError("Chaque journée de prévision doit être un objet.")

    raw_dates = [day.get("date") for day in days_payload]
    if any(not isinstance(value, str) for value in raw_dates):
        raise ValueError("Chaque journée doit posséder une date ISO valide.")
    if len(set(raw_dates)) != len(raw_dates):
        raise ValueError("Les dates de prévision doivent être uniques.")
    if raw_dates != sorted(raw_dates):
        raise ValueError("Les dates de prévision doivent être triées.")

    try:
        parsed_dates = [date.fromisoformat(value) for value in raw_dates]
    except ValueError as error:
        raise ValueError("Une date de prévision n'est pas au format ISO.") from error

    first_dates = parsed_dates[:required_days]
    station_timezone = _open_meteo_timezone(
        timezone_name,
        utc_offset_seconds,
    )
    expected_utc_times = _expected_utc_grid_instants(
        first_dates[0],
        required_days,
        station_timezone,
        step_hours=STEP_HOURS,
    )
    expected_by_date = defaultdict(list)
    for instant in expected_utc_times:
        expected_by_date[instant.astimezone(station_timezone).date()].append(instant)

    validated_slots = []
    for index, current_date in enumerate(first_dates):
        expected_date = first_dates[0] + timedelta(days=index)
        if current_date != expected_date:
            raise ValueError(
                f"Les {required_days} premières dates doivent être consécutives : "
                f"{expected_date.isoformat()} attendu, "
                f"{current_date.isoformat()} reçu."
            )

        slots = days_payload[index].get("slots")
        expected_count = len(expected_by_date[current_date])
        if not isinstance(slots, list) or len(slots) != expected_count:
            if not timezone_name and expected_count == EXPECTED_SLOTS_PER_DAY:
                raise ValueError(
                    f"{current_date.isoformat()} doit contenir exactement "
                    f"{EXPECTED_SLOTS_PER_DAY} créneaux GFS natifs."
                )
            raise ValueError(
                f"{current_date.isoformat()} doit contenir exactement "
                f"{expected_count} créneaux GFS natifs selon le fuseau "
                f"{timezone_name}."
            )

        if any(not isinstance(slot, dict) for slot in slots):
            raise ValueError(
                f"Chaque créneau du {current_date.isoformat()} doit être un objet."
            )
        raw_hours = [slot.get("hour") for slot in slots]
        if any(not isinstance(value, str) for value in raw_hours):
            raise ValueError(
                f"Créneau horaire ISO manquant le {current_date.isoformat()}."
            )
        if raw_hours != sorted(raw_hours) or (
            not timezone_name and len(set(raw_hours)) != len(raw_hours)
        ):
            raise ValueError(
                f"Les créneaux du {current_date.isoformat()} doivent être "
                "uniques et triés."
            )

        try:
            parsed_hours = [datetime.fromisoformat(value) for value in raw_hours]
        except ValueError as error:
            raise ValueError(
                f"Créneau horaire ISO invalide le {current_date.isoformat()}."
            ) from error

        for slot_time, raw_hour in zip(parsed_hours, raw_hours):
            if slot_time.tzinfo is not None:
                raise ValueError(
                    f"Le créneau local {raw_hour} ne doit pas contenir de fuseau."
                )
            if slot_time.date() != current_date:
                raise ValueError(
                    f"Le créneau {raw_hour} n'appartient pas au jour "
                    f"{current_date.isoformat()}."
                )
            if slot_time.second != 0 or slot_time.microsecond != 0:
                raise ValueError(f"Le créneau {raw_hour} n'est pas une heure pleine.")
            if not timezone_name and not _is_native_gfs_step(
                raw_hour,
                utc_offset_seconds,
            ):
                raise ValueError(
                    f"Le créneau {raw_hour} n'est pas aligné sur un pas GFS UTC."
                )
        if not timezone_name:
            for previous, current in zip(parsed_hours, parsed_hours[1:]):
                if current - previous == timedelta(hours=STEP_HOURS):
                    continue
                raise ValueError(
                    f"Les créneaux du {current_date.isoformat()} ne sont pas "
                    f"espacés de {STEP_HOURS} heures."
                )
        validated_slots.extend(zip(slots, parsed_hours))

    explicit_utc = [slot.get("hour_utc") for slot, _ in validated_slots]
    has_explicit_utc = [
        isinstance(value, str) and bool(value.strip())
        for value in explicit_utc
    ]
    if any(has_explicit_utc) and not all(has_explicit_utc):
        raise ValueError("Les instants UTC des créneaux sont partiellement absents.")

    if all(has_explicit_utc):
        try:
            actual_utc_times = [
                _parse_utc_instant(value, "Instant UTC de créneau")
                for value in explicit_utc
            ]
        except ValueError as error:
            raise ValueError("Un instant UTC de créneau est invalide.") from error
    else:
        actual_utc_times = _utc_datetimes_from_open_meteo(
            [slot["hour"] for slot, _ in validated_slots],
            utc_offset_seconds,
            timezone_name,
        )

    for (slot, local_time), utc_time in zip(validated_slots, actual_utc_times):
        if not _is_native_gfs_instant(utc_time):
            raise ValueError(
                f"Le créneau {slot['hour']} n'est pas aligné sur un pas GFS UTC."
            )
        resolved_local = utc_time.astimezone(station_timezone).replace(tzinfo=None)
        if resolved_local != local_time:
            raise ValueError(
                f"Le créneau local {slot['hour']} ne correspond pas à "
                f"l'instant UTC {slot.get('hour_utc')}."
            )

    if actual_utc_times != expected_utc_times:
        raise ValueError(
            "La séquence des créneaux GFS UTC est incomplète, dupliquée ou décalée."
        )

    total = 0
    ok_wind = 0
    ok_hires = 0
    ok_wave = 0
    for day in days_payload:
        for slot in day["slots"]:
            total += 1
            if slot.get("wind_speed_kt") is not None:
                ok_wind += 1
            models = slot.get("models", {})
            hires_model = models.get("hires", {}) if models else {}
            if hires_model and hires_model.get("wind_speed_kt") is not None:
                ok_hires += 1
            wave_model = models.get("wave", {}) if models else {}
            if wave_model and wave_model.get("wave_height_m") is not None:
                ok_wave += 1

    if total == 0:
        raise ValueError("Payload vide : aucun slot genere.")

    ratio_wind = ok_wind / total
    ratio_hires = ok_hires / total
    ratio_wave = ok_wave / total

    if ratio_wind < 0.5:
        raise ValueError(
            f"Validation echouee : seulement {ratio_wind:.1%} des slots "
            f"ont wind_speed_kt non-null (seuil 50%)."
        )
    if ratio_hires < 0.95:
        raise ValueError(
            f"Validation echouee : seulement {ratio_hires:.1%} des slots "
            "ont une prévision IFS-HRES exploitable (seuil 95%)."
        )
    if ratio_wave < 0.5:
        raise ValueError(
            f"Validation echouee : seulement {ratio_wave:.1%} des slots "
            f"ont wave.height_m non-null (seuil 50%)."
        )

    print(
        f"  Validation OK : wind={ratio_wind:.1%} "
        f"hires={ratio_hires:.1%} wave={ratio_wave:.1%} sur {total} slots."
    )


def build_conditions_gfs_summary(
    days_payload,
    max_days=CONDITIONS_FORECAST_DAYS,
    *,
    utc_offset_seconds=0,
    timezone_name=None,
    forecast_run_id=None,
    spot_id=None,
    last_update=None,
):
    """Construit le résumé horaire consommé par la page Marées.

    Les mesures restent dans le document ``conditions`` déjà lu par
    l'application : aucune lecture Firestore supplémentaire n'est nécessaire.
    Les valeurs absentes restent ``None`` et ne sont jamais remplacées par un
    faux zéro.
    """
    hourly = []
    for day in days_payload[:max_days]:
        for slot in day.get("slots", []):
            models = slot.get("models") or {}
            wind = models.get("wind") or {}
            wave = models.get("wave") or {}
            gust_knots = wind.get("wind_gust_kt")
            visibility_m = wind.get("visibility_m")
            raw_time = slot.get("hour")
            raw_utc_time = slot.get("hour_utc")
            values = {
                # `days` conserve les heures locales historiques consommées
                # par Marées Pro. Le résumé `conditions.gfs`, lui, est
                # rapproché des séries marines et météo horaires publiées en
                # UTC. Un ISO UTC explicite évite que le téléphone interprète
                # cette heure comme appartenant à son propre fuseau.
                "time": (
                    _utc_iso(
                        _parse_utc_instant(
                            raw_utc_time,
                            "Instant UTC du résumé GFS",
                        )
                    )
                    if isinstance(raw_utc_time, str) and raw_utc_time.strip()
                    else (
                        _utc_iso_from_open_meteo(
                            raw_time,
                            utc_offset_seconds,
                            timezone_name,
                        )
                        if isinstance(raw_time, str) and raw_time.strip()
                        else None
                    )
                ),
                "windSpeedKmh": (
                    round(slot["wind_speed_kt"] * 1.852, 1)
                    if slot.get("wind_speed_kt") is not None
                    else None
                ),
                "windGustKmh": (
                    round(gust_knots * 1.852, 1)
                    if gust_knots is not None
                    else None
                ),
                "visibilityKm": (
                    round(visibility_m / 1000.0, 1)
                    if visibility_m is not None
                    else None
                ),
                "cloudCoverPct": wind.get("cloud_total_pct"),
                "windDirectionDeg": slot.get("wind_dir_deg"),
                "weatherCode": (
                    round(slot["weather_code"])
                    if slot.get("weather_code") is not None
                    else None
                ),
                "isDay": (
                    round(slot["is_day"])
                    if slot.get("is_day") is not None
                    else None
                ),
                "temperatureC": slot.get("temp_c"),
                "waveHeightM": slot.get("wave_height_m"),
                "wavePeriodS": slot.get("wave_period_s"),
                "waveDirectionDeg": slot.get("wave_dir_deg"),
                "activityScore": (
                    round(slot["rating"] * 20)
                    if slot.get("rating") is not None
                    else None
                ),
                "precipitationMm": wind.get("precipitation_mm"),
                "precipitationProbabilityPct": wind.get("precip_prob_pct"),
                "pressureHpa": wind.get("pressure_msl"),
                "relativeHumidityPct": wind.get("rel_humidity_pct"),
                "swellHeightM": wave.get("swell_height_m"),
                "swellPeriodS": wave.get("swell_period_s"),
                "swellDirectionDeg": wave.get("swell_dir_deg"),
                "secondarySwellHeightM": wave.get("swell2_height_m"),
                "secondarySwellPeriodS": wave.get("swell2_period_s"),
                "secondarySwellDirectionDeg": wave.get("swell2_dir_deg"),
                "seaSurfaceTemperatureC": wave.get("sst_c"),
                "oceanCurrentSpeedKmh": wave.get(
                    "ocean_current_velocity_kmh"
                ),
                "oceanCurrentDirectionDeg": wave.get(
                    "ocean_current_direction_deg"
                ),
            }
            if values["time"] and any(
                values[key] is not None
                for key in values
                if key != "time"
            ):
                hourly.append(values)

    summary = {
        "model": "GFS ~13km",
        "hourly": hourly,
    }
    if forecast_run_id is not None:
        summary["forecast_run_id"] = forecast_run_id
    if spot_id is not None:
        summary["spot_id"] = spot_id
    if last_update is not None:
        summary["last_update"] = last_update
    return summary


_MARINE_CONDITIONS_FIELDS = (
    ("sea_level_height_msl", "height", -10.0, 10.0),
    ("wave_height", "waveHeightM", 0.0, 40.0),
    ("wave_period", "wavePeriodS", 0.0, 60.0),
    ("wave_direction", "waveDirectionDeg", 0.0, 360.0),
    ("wind_wave_height", "windWaveHeightM", 0.0, 40.0),
    ("wind_wave_period", "windWavePeriodS", 0.0, 60.0),
    ("wind_wave_direction", "windWaveDirectionDeg", 0.0, 360.0),
    ("swell_wave_height", "swellHeightM", 0.0, 40.0),
    ("swell_wave_period", "swellPeriodS", 0.0, 60.0),
    ("swell_wave_direction", "swellDirectionDeg", 0.0, 360.0),
    ("secondary_swell_wave_height", "secondarySwellHeightM", 0.0, 40.0),
    ("secondary_swell_wave_period", "secondarySwellPeriodS", 0.0, 60.0),
    ("secondary_swell_wave_direction", "secondarySwellDirectionDeg", 0.0, 360.0),
    ("sea_surface_temperature", "seaSurfaceTemperatureC", -5.0, 45.0),
    ("ocean_current_velocity", "oceanCurrentSpeedKmh", 0.0, 30.0),
    ("ocean_current_direction", "oceanCurrentDirectionDeg", 0.0, 360.0),
)

_WEATHER_CONDITIONS_FIELDS = (
    ("temperature_2m", "temperatureC", -90.0, 60.0, 1.0),
    ("wind_speed_10m", "windSpeedKmh", 0.0, 400.0, 3.6),
    ("wind_gusts_10m", "windGustKmh", 0.0, 500.0, 3.6),
    ("wind_direction_10m", "windDirectionDeg", 0.0, 360.0, 1.0),
    ("weather_code", "weatherCode", 0.0, 99.0, 1.0),
    ("is_day", "isDay", 0.0, 1.0, 1.0),
    ("pressure_msl", "pressureHpa", 800.0, 1200.0, 1.0),
    ("precipitation_probability", "precipitationProbabilityPct", 0.0, 100.0, 1.0),
    ("precipitation", "precipitationMm", 0.0, 500.0, 1.0),
    ("relative_humidity_2m", "relativeHumidityPct", 0.0, 100.0, 1.0),
    ("cloud_cover", "cloudCoverPct", 0.0, 100.0, 1.0),
    ("visibility", "visibilityKm", 0.0, 100.0, 0.001),
)


def _utc_iso_from_open_meteo(
    local_timestamp,
    utc_offset_seconds,
    timezone_name=None,
):
    """Normalise une heure locale Open-Meteo vers un ISO UTC non ambigu."""
    parsed = _utc_datetimes_from_open_meteo(
        [local_timestamp],
        utc_offset_seconds,
        timezone_name,
    )[0]
    return _utc_iso(parsed)


def _haversine_km(lat1, lon1, lat2, lon2):
    radians = math.pi / 180.0
    d_lat = (lat2 - lat1) * radians
    d_lon = (lon2 - lon1) * radians
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(lat1 * radians)
        * math.cos(lat2 * radians)
        * math.sin(d_lon / 2) ** 2
    )
    return 6371.0 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _validated_number(hourly, api_key, index, minimum, maximum, label):
    value = _hourly_num(hourly, api_key, index)
    if value is None or not math.isfinite(value) or value < minimum or value > maximum:
        raise ValueError(
            f"{label} : {api_key} absent ou hors limites au créneau {index}."
        )
    return value


def _validate_hourly_continuity(
    slots,
    label,
    expected_hours=CONDITIONS_FORECAST_DAYS * 24,
):
    if len(slots) != expected_hours:
        raise ValueError(
            f"{label} : couverture incorrecte ({len(slots)}/{expected_hours} "
            "créneaux)."
        )
    parsed = []
    for slot in slots:
        raw_time = slot.get("time")
        if not isinstance(raw_time, str):
            raise ValueError(f"{label} : heure absente.")
        parsed.append(_parse_utc_instant(raw_time, f"{label} : heure"))
    if parsed != sorted(parsed) or len(set(parsed)) != len(parsed):
        raise ValueError(f"{label} : heures dupliquées ou non triées.")
    for previous, current in zip(parsed, parsed[1:]):
        if current - previous != timedelta(hours=1):
            raise ValueError(
                f"{label} : rupture horaire entre {previous} et {current}."
            )


def build_conditions_document(
    spot,
    wind_json,
    wave_json,
    published_days,
    *,
    forecast_run_id,
    last_update,
):
    """Construit le document complet consommé par la page Marées.

    Toute valeur visible dans l'application est obligatoire ici. Une valeur
    absente fait échouer le run avant écriture, ce qui conserve dans Firestore
    le dernier document complet au lieu de publier un faux zéro.
    """
    if len(published_days) != CONDITIONS_FORECAST_DAYS:
        raise ValueError(
            f"conditions/{spot['id']} : {len(published_days)} jour(s), "
            f"{CONDITIONS_FORECAST_DAYS} requis."
        )
    published_dates = {day["date"] for day in published_days}
    wave_hourly = wave_json.get("hourly") or {}
    wind_hourly = wind_json.get("hourly") or {}
    wave_times = wave_hourly.get("time") or []
    wind_times = wind_hourly.get("time") or []
    wave_offset = int(_safe_num(wave_json.get("utc_offset_seconds"), 0) or 0)
    wind_offset = int(_safe_num(wind_json.get("utc_offset_seconds"), 0) or 0)
    wave_timezone_name = wave_json.get("timezone")
    wind_timezone_name = wind_json.get("timezone")
    wave_timezone = _open_meteo_timezone(wave_timezone_name, wave_offset)
    wind_timezone = _open_meteo_timezone(wind_timezone_name, wind_offset)
    wave_utc_times = _utc_datetimes_from_open_meteo(
        wave_times,
        wave_offset,
        wave_timezone_name,
    )
    wind_utc_times = _utc_datetimes_from_open_meteo(
        wind_times,
        wind_offset,
        wind_timezone_name,
    )
    first_published_date = date.fromisoformat(published_days[0]["date"])
    expected_wave_times = _expected_utc_grid_instants(
        first_published_date,
        CONDITIONS_FORECAST_DAYS,
        wave_timezone,
        step_hours=1,
    )
    expected_wind_times = _expected_utc_grid_instants(
        first_published_date,
        CONDITIONS_FORECAST_DAYS,
        wind_timezone,
        step_hours=1,
    )

    tide_slots = []
    for index, (local_time, utc_time) in enumerate(
        zip(wave_times, wave_utc_times)
    ):
        if not isinstance(local_time, str) or local_time[:10] not in published_dates:
            continue
        slot = {"time": _utc_iso(utc_time)}
        for api_key, output_key, minimum, maximum in _MARINE_CONDITIONS_FIELDS:
            slot[output_key] = _validated_number(
                wave_hourly,
                api_key,
                index,
                minimum,
                maximum,
                f"conditions/{spot['id']}.tide",
            )
        tide_slots.append(slot)
    _validate_hourly_continuity(
        tide_slots,
        f"conditions/{spot['id']}.tide",
        expected_hours=len(expected_wave_times),
    )
    if [slot["time"] for slot in tide_slots] != [
        _utc_iso(instant) for instant in expected_wave_times
    ]:
        raise ValueError(
            f"conditions/{spot['id']}.tide : grille UTC incomplète ou décalée."
        )

    weather_slots = []
    for index, (local_time, utc_time) in enumerate(
        zip(wind_times, wind_utc_times)
    ):
        if not isinstance(local_time, str) or local_time[:10] not in published_dates:
            continue
        slot = {"time": _utc_iso(utc_time)}
        for api_key, output_key, minimum, maximum, multiplier in _WEATHER_CONDITIONS_FIELDS:
            value = _validated_number(
                wind_hourly,
                api_key,
                index,
                minimum / multiplier,
                maximum / multiplier,
                f"conditions/{spot['id']}.weather",
            )
            converted = value * multiplier
            slot[output_key] = round(converted) if output_key in {"weatherCode", "isDay"} else round(converted, 2)
        weather_slots.append(slot)
    _validate_hourly_continuity(
        weather_slots,
        f"conditions/{spot['id']}.weather",
        expected_hours=len(expected_wind_times),
    )
    if [slot["time"] for slot in weather_slots] != [
        _utc_iso(instant) for instant in expected_wind_times
    ]:
        raise ValueError(
            f"conditions/{spot['id']}.weather : grille UTC incomplète ou décalée."
        )
    if [slot["time"] for slot in tide_slots] != [
        slot["time"] for slot in weather_slots
    ]:
        raise ValueError(
            f"conditions/{spot['id']} : les séries marines et météo ne sont "
            "pas alignées heure par heure."
        )

    daily_sun = []
    for day in published_days:
        day_date = day.get("date")
        sunrise = day.get("sunrise")
        sunset = day.get("sunset")
        if not all(
            isinstance(value, str) and value.strip()
            for value in (day_date, sunrise, sunset)
        ):
            raise ValueError(
                f"conditions/{spot['id']} : lever ou coucher du soleil "
                "quotidien absent."
            )
        daily_sun.append(
            {
                "date": day_date,
                "sunrise": sunrise,
                "sunset": sunset,
            }
        )
    first_sun = daily_sun[0]

    source_latitude = _safe_num(wave_json.get("latitude"))
    source_longitude = _safe_num(wave_json.get("longitude"))
    if source_latitude is None or source_longitude is None:
        raise ValueError(f"conditions/{spot['id']} : cellule marine absente.")
    source_distance_km = _haversine_km(
        spot["lat"],
        spot["lon"],
        source_latitude,
        source_longitude,
    )
    if source_distance_km > 30.0:
        raise ValueError(
            f"conditions/{spot['id']} : cellule marine à "
            f"{source_distance_km:.1f} km (> 30 km)."
        )

    document = {
        "schema_version": 2,
        "forecast_run_id": forecast_run_id,
        "spot_id": spot["id"],
        "name": spot["name"],
        "lat": spot["lat"],
        "lon": spot["lon"],
        "utc_offset_seconds": wind_offset,
        "timestamp": last_update,
        "tide_datum": "global_mean_sea_level",
        "source": {
            "provider": "Open-Meteo",
            "marineLatitude": source_latitude,
            "marineLongitude": source_longitude,
            "marineDistanceKm": round(source_distance_km, 1),
        },
        "sun": {
            # Champs historiques conservés pour BoosterFish 1.0.9 (24).
            "date": first_sun["date"],
            "sunrise": first_sun["sunrise"],
            "sunset": first_sun["sunset"],
            # Le client récent choisit le jour de la station. Cela empêche
            # d'afficher les horaires de la veille entre minuit et le prochain
            # passage du job planifié.
            "daily": daily_sun,
        },
        "tide": {"hourly": tide_slots},
        "weather": {"hourly": weather_slots},
        "gfs": build_conditions_gfs_summary(
            published_days,
            utc_offset_seconds=wind_offset,
            timezone_name=wind_timezone_name,
            forecast_run_id=forecast_run_id,
            spot_id=spot["id"],
            last_update=last_update,
        ),
    }
    if isinstance(wind_timezone_name, str) and wind_timezone_name.strip():
        document["timezone"] = wind_timezone_name.strip()
    return document


def _require_station_models(station_result):
    """Retourne les trois modèles ou interrompt la récolte au premier manque."""
    spot = station_result["spot"]
    models = station_result.get("models") or {}
    errors = station_result.get("errors") or {}
    required = {}
    for model_name in ("wind", "hires", "wave"):
        model_json = models.get(model_name)
        if model_json is None:
            error = errors.get(model_name) or errors.get("station")
            detail = _error_summary(error) if error is not None else "réponse absente"
            raise RuntimeError(
                f"Récolte interrompue pour {spot['id']} : "
                f"modèle {model_name} indisponible ({detail})."
            )
        hourly = model_json.get("hourly")
        times = hourly.get("time") if isinstance(hourly, dict) else None
        if not isinstance(times, list) or not times:
            raise RuntimeError(
                f"Récolte interrompue pour {spot['id']} : "
                f"modèle {model_name} sans série horaire."
            )
        required[model_name] = model_json
    return required["wind"], required["hires"], required["wave"]


def _build_station_publication(
    station_result,
    run_id,
    *,
    conditions_spot_ids=CONDITIONS_SPOT_IDS,
):
    """Construit et valide une station sans effectuer d'écriture Firestore."""
    spot = station_result["spot"]
    models = station_result.get("models") or {}
    wind_json, hires_json, wave_json = _require_station_models(station_result)

    for model_name in ("wind", "hires", "wave"):
        slot_count = len(models[model_name].get("hourly", {}).get("time", []))
        print(f"  [{model_name}] OK ({slot_count} slots)")

    daily_json = {}
    if "daily" in wind_json:
        daily = wind_json["daily"]
        for index, day_value in enumerate(daily.get("time", [])):
            daily_json[day_value] = {
                "sunrise": (
                    daily["sunrise"][index]
                    if index < len(daily.get("sunrise", []))
                    else None
                ),
                "sunset": (
                    daily["sunset"][index]
                    if index < len(daily.get("sunset", []))
                    else None
                ),
            }

    days_payload, water_temp_c = build_days_payload(
        wind_json,
        hires_json,
        wave_json,
        daily_json,
    )
    utc_offset_seconds = int(
        _safe_num(wind_json.get("utc_offset_seconds"), 0) or 0
    )
    timezone_name = wind_json.get("timezone")
    if not isinstance(timezone_name, str) or not timezone_name.strip():
        raise ValueError(
            f"Récolte interrompue pour {spot['id']} : fuseau IANA absent."
        )
    timezone_name = timezone_name.strip()
    _open_meteo_timezone(timezone_name, utc_offset_seconds)
    for model_name, model_json in (("hires", hires_json), ("wave", wave_json)):
        model_timezone = model_json.get("timezone")
        if not isinstance(model_timezone, str) or model_timezone.strip() != timezone_name:
            raise ValueError(
                f"Récolte interrompue pour {spot['id']} : fuseau IANA "
                f"incohérent pour {model_name}."
            )
    validate_payload(
        days_payload,
        utc_offset_seconds,
        timezone_name=timezone_name,
    )

    # La météo générale conserve dix jours. Les conditions de la page Marées
    # utilisent les huit jours entièrement couverts par l'API Marine.
    published_days = days_payload[:PUBLISHED_FORECAST_DAYS]
    conditions_days = published_days[:CONDITIONS_FORECAST_DAYS]

    weather_doc = {
        "forecast_run_id": run_id,
        "spot_id": spot["id"],
        "last_update": firestore.SERVER_TIMESTAMP,
        "location_name": spot["name"],
        "latitude": spot["lat"],
        "longitude": spot["lon"],
        "utc_offset_seconds": utc_offset_seconds,
        "days": published_days,
    }
    if isinstance(timezone_name, str) and timezone_name.strip():
        weather_doc["timezone"] = timezone_name.strip()
    if water_temp_c is not None:
        weather_doc["water_temp_c"] = water_temp_c
    first_day = published_days[0]
    if "sunrise" in first_day:
        weather_doc["sunrise"] = first_day["sunrise"]
    if "sunset" in first_day:
        weather_doc["sunset"] = first_day["sunset"]

    conditions_doc = None
    if spot["id"] in conditions_spot_ids:
        conditions_doc = build_conditions_document(
            spot,
            wind_json,
            wave_json,
            conditions_days,
            forecast_run_id=run_id,
            last_update=firestore.SERVER_TIMESTAMP,
        )

    return {
        "spot": spot,
        "weather_doc": weather_doc,
        "conditions_doc": conditions_doc,
    }


def _validate_publications_before_commit(
    publications,
    run_id,
    conditions_spot_ids,
):
    """Valide le lot complet avant même de créer le WriteBatch."""
    seen_spot_ids = set()
    condition_spot_ids = set(conditions_spot_ids)
    for publication in publications:
        spot = publication.get("spot") or {}
        spot_id = spot.get("id")
        if not spot_id or spot_id in seen_spot_ids:
            raise ValueError(
                f"Publication absente ou dupliquée pour le spot {spot_id!r}."
            )
        seen_spot_ids.add(spot_id)

        weather_doc = publication.get("weather_doc")
        if not isinstance(weather_doc, dict):
            raise ValueError(f"Document météo manquant pour {spot_id}.")
        if weather_doc.get("forecast_run_id") != run_id:
            raise ValueError(f"Run id météo incohérent pour {spot_id}.")
        if weather_doc.get("spot_id") != spot_id:
            raise ValueError(f"Spot id météo incohérent pour {spot_id}.")
        if weather_doc.get("location_name") != spot.get("name"):
            raise ValueError(f"Nom météo incohérent pour {spot_id}.")
        if weather_doc.get("latitude") != spot.get("lat") or weather_doc.get(
            "longitude"
        ) != spot.get("lon"):
            raise ValueError(f"Coordonnées météo incohérentes pour {spot_id}.")

        conditions_doc = publication.get("conditions_doc")
        if spot_id in condition_spot_ids:
            if not isinstance(conditions_doc, dict):
                raise ValueError(
                    f"Document conditions manquant pour le spot requis {spot_id}."
                )
            if conditions_doc.get("forecast_run_id") != run_id:
                raise ValueError(
                    f"Run id conditions incohérent pour le spot {spot_id}."
                )
            if conditions_doc.get("spot_id") != spot_id:
                raise ValueError(
                    f"Spot id conditions incohérent pour le spot {spot_id}."
                )
            if conditions_doc.get("name") != spot.get("name"):
                raise ValueError(f"Nom conditions incohérent pour {spot_id}.")
        elif conditions_doc is not None:
            raise ValueError(
                f"Document conditions inattendu pour le spot {spot_id}."
            )

    missing_conditions = condition_spot_ids - seen_spot_ids
    if missing_conditions:
        raise ValueError(
            "Spot(s) requis pour conditions absent(s) du lot : "
            + ", ".join(sorted(missing_conditions))
        )


def _write_forecast_batches(
    db,
    publications,
    run_id,
    *,
    conditions_spot_ids=CONDITIONS_SPOT_IDS,
    conditions_aliases=None,
):
    """Publie des lots atomiques bornés après validation du run complet.

    Les documents d'une station (météo, index, conditions canonique et éventuel
    alias historique) restent toujours dans le même WriteBatch. Si un Commit échoue,
    les stations déjà publiées restent cohérentes et les autres conservent leur
    dernière version valide ; l'exception interrompt immédiatement le job.
    """
    _validate_publications_before_commit(
        publications,
        run_id,
        conditions_spot_ids,
    )

    conditions_aliases = _effective_conditions_aliases(
        conditions_spot_ids,
        conditions_aliases,
    )
    unknown_alias_sources = set(conditions_aliases) - set(conditions_spot_ids)
    if unknown_alias_sources:
        raise ValueError(
            "Alias conditions sans station canonique : "
            + ", ".join(sorted(unknown_alias_sources))
        )
    document_ids = list(conditions_spot_ids.values()) + list(
        conditions_aliases.values()
    )
    if len(document_ids) != len(set(document_ids)):
        raise ValueError("Identifiants de documents conditions dupliqués.")

    expected_write_count = (
        len(publications) * 2
        + len(conditions_spot_ids)
        + len(conditions_aliases)
    )
    write_count = 0
    commit_count = 0
    # BoosterFish 1.0.9 (24) ne sait lire `conditions.timestamp` que sous
    # forme de chaîne ISO. Les documents canoniques conservent le Timestamp
    # serveur ; seuls les cinq alias temporaires reçoivent cette représentation
    # historique, calculée une fois pour rendre le lot cohérent.
    legacy_alias_timestamp = (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )
    for start in range(0, len(publications), PUBLISH_BATCH_STATION_COUNT):
        station_batch = publications[
            start : start + PUBLISH_BATCH_STATION_COUNT
        ]
        batch = db.batch()
        batch_write_count = 0
        for publication in station_batch:
            spot = publication["spot"]
            spot_id = spot["id"]
            weather_ref = db.collection("spots_meteo").document(spot_id)
            index_ref = db.collection("spots_index").document(spot_id)
            batch.set(weather_ref, publication["weather_doc"])
            write_count += 1
            batch_write_count += 1
            batch.set(
                index_ref,
                {
                    "forecast_run_id": run_id,
                    "spot_id": spot_id,
                    "last_update": firestore.SERVER_TIMESTAMP,
                    "name": spot["name"],
                    "latitude": spot["lat"],
                    "longitude": spot["lon"],
                },
            )
            write_count += 1
            batch_write_count += 1

            conditions_id = conditions_spot_ids.get(spot_id)
            if conditions_id is not None:
                conditions_ref = db.collection("conditions").document(
                    conditions_id
                )
                # Remplacement complet : un ancien champ ne doit pas survivre à
                # une évolution de schéma et être pris pour une donnée fraîche.
                batch.set(conditions_ref, publication["conditions_doc"])
                write_count += 1
                batch_write_count += 1

                alias_id = conditions_aliases.get(spot_id)
                if alias_id is not None:
                    alias_ref = db.collection("conditions").document(alias_id)
                    alias_document = {
                        **publication["conditions_doc"],
                        "timestamp": legacy_alias_timestamp,
                    }
                    batch.set(alias_ref, alias_document)
                    write_count += 1
                    batch_write_count += 1

        maximum_batch_writes = (
            PUBLISH_BATCH_STATION_COUNT * 3
            + len(conditions_aliases)
        )
        if batch_write_count > maximum_batch_writes:
            raise RuntimeError(
                f"Sous-lot Firestore inattendu : {batch_write_count} écritures."
            )
        batch.commit()
        commit_count += 1
        print(
            f"  -> Lot Firestore {commit_count} publié : "
            f"{len(station_batch)} station(s), {batch_write_count} écriture(s)."
        )

    if write_count != expected_write_count:
        raise RuntimeError(
            f"Lot Firestore incomplet : {write_count}/{expected_write_count} écritures."
        )
    return write_count, commit_count


def _prepare_and_publish_forecasts(
    db,
    station_results,
    run_id,
    *,
    expected_spot_count,
    conditions_spot_ids=CONDITIONS_SPOT_IDS,
    conditions_aliases=None,
):
    """Valide toutes les stations, puis seulement ensuite publie le lot."""
    publications = []
    for station_result in station_results:
        spot = station_result["spot"]
        print(f"Recolte pour {spot['name']}...")
        publication = _build_station_publication(
            station_result,
            run_id,
            conditions_spot_ids=conditions_spot_ids,
        )
        publications.append(publication)
        day_count = len(publication["weather_doc"]["days"])
        print(f"  -> {day_count} jours préparés et validés en mémoire.")

    if len(publications) != expected_spot_count:
        raise RuntimeError(
            "Récolte incomplète avant publication : "
            f"{len(publications)}/{expected_spot_count} stations."
        )

    write_count, commit_count = _write_forecast_batches(
        db,
        publications,
        run_id,
        conditions_spot_ids=conditions_spot_ids,
        conditions_aliases=conditions_aliases,
    )
    return publications, write_count, commit_count


def _snapshot_data(snapshot, label):
    if not getattr(snapshot, "exists", False):
        raise RuntimeError(f"Vérification Production : {label} est absent.")
    data = snapshot.to_dict()
    if not isinstance(data, dict):
        raise RuntimeError(
            f"Vérification Production : {label} ne contient pas un objet valide."
        )
    return data


def _utc_datetime(value, label):
    if not isinstance(value, datetime):
        raise RuntimeError(
            f"Vérification Production : horodatage {label} absent ou invalide."
        )
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _verify_freshness(data, label, run_started_at, now):
    updated_at = _utc_datetime(data.get("last_update"), label)
    if updated_at < run_started_at - FRESHNESS_CLOCK_SKEW:
        raise RuntimeError(
            f"Vérification Production : {label} est antérieur au run courant."
        )
    if updated_at > now + FRESHNESS_CLOCK_SKEW:
        raise RuntimeError(
            f"Vérification Production : {label} possède une date future invalide."
        )


def _verify_timestamp_field(
    data,
    field,
    label,
    run_started_at,
    now,
    *,
    allow_iso_string=False,
):
    raw_value = data.get(field)
    if allow_iso_string and isinstance(raw_value, str):
        try:
            updated_at = datetime.fromisoformat(raw_value.replace("Z", "+00:00"))
        except ValueError as error:
            raise RuntimeError(
                f"Vérification Production : horodatage {label} "
                "absent ou invalide."
            ) from error
        updated_at = _utc_datetime(updated_at, label)
    else:
        updated_at = _utc_datetime(raw_value, label)
    if updated_at < run_started_at - FRESHNESS_CLOCK_SKEW:
        raise RuntimeError(
            f"Vérification Production : {label} est antérieur au run courant."
        )
    if updated_at > now + FRESHNESS_CLOCK_SKEW:
        raise RuntimeError(
            f"Vérification Production : {label} possède une date future invalide."
        )


def _verify_conditions_payload(
    data,
    spot,
    run_id,
    label,
    run_started_at,
    now,
    *,
    allow_iso_timestamp=False,
    expected_utc_offset_seconds=None,
    expected_timezone_name=None,
):
    if data.get("schema_version") != 2:
        raise RuntimeError(f"Vérification Production : schéma incorrect dans {label}.")
    if data.get("forecast_run_id") != run_id or data.get("spot_id") != spot["id"]:
        raise RuntimeError(
            f"Vérification Production : identité incorrecte dans {label}."
        )
    if data.get("name") != spot["name"]:
        raise RuntimeError(f"Vérification Production : nom incorrect dans {label}.")
    for field, expected in (("lat", spot["lat"]), ("lon", spot["lon"])):
        actual = data.get(field)
        if (
            isinstance(actual, bool)
            or not isinstance(actual, (int, float))
            or abs(float(actual) - float(expected)) > 1e-6
        ):
            raise RuntimeError(
                f"Vérification Production : {field} incorrect dans {label}."
            )
    _verify_timestamp_field(
        data,
        "timestamp",
        label,
        run_started_at,
        now,
        allow_iso_string=allow_iso_timestamp,
    )
    utc_offset_seconds = data.get("utc_offset_seconds")
    if (
        isinstance(utc_offset_seconds, bool)
        or not isinstance(utc_offset_seconds, (int, float))
        or (
            expected_utc_offset_seconds is not None
            and int(utc_offset_seconds) != int(expected_utc_offset_seconds)
        )
    ):
        raise RuntimeError(
            f"Vérification Production : décalage UTC incorrect dans {label}."
        )
    timezone_name = data.get("timezone")
    if expected_timezone_name is not None and timezone_name != expected_timezone_name:
        raise RuntimeError(
            f"Vérification Production : fuseau IANA incorrect dans {label}."
        )
    try:
        station_timezone = _open_meteo_timezone(
            timezone_name,
            utc_offset_seconds,
        )
    except ValueError as error:
        raise RuntimeError(
            f"Vérification Production : fuseau IANA invalide dans {label}."
        ) from error

    sun = data.get("sun")
    daily_sun = sun.get("daily") if isinstance(sun, dict) else None
    if not isinstance(daily_sun, list) or len(daily_sun) != CONDITIONS_FORECAST_DAYS:
        raise RuntimeError(
            f"Vérification Production : calendrier solaire incomplet dans {label}."
        )
    sun_dates = []
    for entry in daily_sun:
        if not isinstance(entry, dict):
            raise RuntimeError(
                f"Vérification Production : calendrier solaire invalide dans {label}."
            )
        raw_date = entry.get("date")
        sunrise = entry.get("sunrise")
        sunset = entry.get("sunset")
        try:
            parsed_date = date.fromisoformat(raw_date)
            parsed_sunrise = datetime.fromisoformat(sunrise)
            parsed_sunset = datetime.fromisoformat(sunset)
        except (TypeError, ValueError) as error:
            raise RuntimeError(
                f"Vérification Production : calendrier solaire invalide dans {label}."
            ) from error
        if (
            parsed_sunrise.date() != parsed_date
            or parsed_sunset.date() != parsed_date
            or parsed_sunrise >= parsed_sunset
        ):
            raise RuntimeError(
                f"Vérification Production : calendrier solaire incohérent "
                f"dans {label}."
            )
        sun_dates.append(parsed_date)
    if any(
        current != sun_dates[0] + timedelta(days=index)
        for index, current in enumerate(sun_dates)
    ):
        raise RuntimeError(
            f"Vérification Production : dates solaires non consécutives "
            f"dans {label}."
        )
    if any(sun.get(key) != daily_sun[0].get(key) for key in ("date", "sunrise", "sunset")):
        raise RuntimeError(
            f"Vérification Production : champs solaires historiques incohérents "
            f"dans {label}."
        )
    if data.get("tide_datum") != "global_mean_sea_level":
        raise RuntimeError(
            f"Vérification Production : référence de marée incorrecte dans {label}."
        )

    tide = data.get("tide")
    weather = data.get("weather")
    tide_slots = tide.get("hourly") if isinstance(tide, dict) else None
    weather_slots = weather.get("hourly") if isinstance(weather, dict) else None
    if not isinstance(tide_slots, list) or not isinstance(weather_slots, list):
        raise RuntimeError(
            f"Vérification Production : séries horaires absentes dans {label}."
        )
    try:
        expected_hourly_times = _expected_utc_grid_instants(
            sun_dates[0],
            CONDITIONS_FORECAST_DAYS,
            station_timezone,
            step_hours=1,
        )
        expected_hour_count = len(expected_hourly_times)
        _validate_hourly_continuity(
            tide_slots,
            f"{label}.tide",
            expected_hours=expected_hour_count,
        )
        _validate_hourly_continuity(
            weather_slots,
            f"{label}.weather",
            expected_hours=expected_hour_count,
        )
        expected_iso_times = [
            _utc_iso(instant) for instant in expected_hourly_times
        ]
        if [slot.get("time") for slot in tide_slots] != expected_iso_times:
            raise ValueError(f"{label}.tide : grille UTC incomplète ou décalée.")
        if [slot.get("time") for slot in weather_slots] != expected_iso_times:
            raise ValueError(f"{label}.weather : grille UTC incomplète ou décalée.")
    except ValueError as error:
        raise RuntimeError(f"Vérification Production : {error}") from error

    for index, slot in enumerate(tide_slots):
        for _, output_key, minimum, maximum in _MARINE_CONDITIONS_FIELDS:
            value = slot.get(output_key)
            if (
                isinstance(value, bool)
                or not isinstance(value, (int, float))
                or not math.isfinite(value)
                or value < minimum
                or value > maximum
            ):
                raise RuntimeError(
                    f"Vérification Production : {label}.tide[{index}]."
                    f"{output_key} invalide."
                )
    for index, slot in enumerate(weather_slots):
        for _, output_key, minimum, maximum, _ in _WEATHER_CONDITIONS_FIELDS:
            value = slot.get(output_key)
            if (
                isinstance(value, bool)
                or not isinstance(value, (int, float))
                or not math.isfinite(value)
                or value < minimum
                or value > maximum
            ):
                raise RuntimeError(
                    f"Vérification Production : {label}.weather[{index}]."
                    f"{output_key} invalide."
                )


def _verify_spot_identity(data, spot, run_id, name_field, label):
    if data.get("forecast_run_id") != run_id:
        raise RuntimeError(
            f"Vérification Production : run id incorrect dans {label}."
        )
    if data.get("spot_id") != spot["id"]:
        raise RuntimeError(
            f"Vérification Production : spot id incorrect dans {label}."
        )
    if data.get(name_field) != spot["name"]:
        raise RuntimeError(
            f"Vérification Production : nom incorrect dans {label}."
        )
    for field, expected in (("latitude", spot["lat"]), ("longitude", spot["lon"])):
        actual = data.get(field)
        if (
            isinstance(actual, bool)
            or not isinstance(actual, (int, float))
            or abs(float(actual) - float(expected)) > 1e-6
        ):
            raise RuntimeError(
                f"Vérification Production : {field} incorrect dans {label}."
            )


def verify_production_state(
    db,
    spots,
    run_id,
    run_started_at,
    *,
    conditions_spot_ids=CONDITIONS_SPOT_IDS,
    conditions_aliases=None,
    now=None,
):
    """Relit et valide chaque document publié par le run courant.

    Firestore fournit des lectures fortement cohérentes : une différence de
    run, d'identité, de fraîcheur ou de payload immédiatement après les commits
    révèle donc une écriture manquante ou partielle et fait échouer le job.
    """
    run_started_at = _utc_datetime(run_started_at, "début du run")
    now = _utc_datetime(now or datetime.now(timezone.utc), "fin du run")

    conditions_aliases = _effective_conditions_aliases(
        conditions_spot_ids,
        conditions_aliases,
    )
    catalog_ids = {spot["id"] for spot in spots}
    missing_conditions = set(conditions_spot_ids) - catalog_ids
    if missing_conditions:
        raise RuntimeError(
            "Vérification Production : spot(s) conditions absent(s) du catalogue : "
            + ", ".join(sorted(missing_conditions))
        )
    missing_alias_sources = set(conditions_aliases) - set(conditions_spot_ids)
    if missing_alias_sources:
        raise RuntimeError(
            "Vérification Production : alias sans document canonique : "
            + ", ".join(sorted(missing_alias_sources))
        )

    expected_condition_document_ids = set(conditions_spot_ids.values()) | set(
        conditions_aliases.values()
    )
    if len(expected_condition_document_ids) != (
        len(conditions_spot_ids) + len(conditions_aliases)
    ):
        raise RuntimeError(
            "Vérification Production : identifiants conditions dupliqués."
        )

    verified_conditions = set()
    verified_condition_documents = set()
    for spot in spots:
        weather_label = f"spots_meteo/{spot['id']}"
        weather = _snapshot_data(
            db.collection("spots_meteo").document(spot["id"]).get(),
            weather_label,
        )
        _verify_spot_identity(
            weather,
            spot,
            run_id,
            "location_name",
            weather_label,
        )
        _verify_freshness(weather, weather_label, run_started_at, now)
        utc_offset_seconds = weather.get("utc_offset_seconds")
        if isinstance(utc_offset_seconds, bool) or not isinstance(
            utc_offset_seconds, (int, float)
        ):
            raise RuntimeError(
                f"Vérification Production : décalage UTC invalide dans {weather_label}."
            )
        timezone_name = weather.get("timezone")
        weather_days = weather.get("days")
        if not (
            isinstance(timezone_name, str) and timezone_name.strip()
        ):
            raise RuntimeError(
                f"Vérification Production : fuseau IANA absent dans {weather_label}."
            )
        if isinstance(timezone_name, str):
            timezone_name = timezone_name.strip() or None
        try:
            validate_payload(
                weather_days,
                int(utc_offset_seconds),
                PUBLISHED_FORECAST_DAYS,
                timezone_name=timezone_name,
            )
        except (TypeError, ValueError) as error:
            raise RuntimeError(
                f"Vérification Production : payload invalide dans {weather_label} : "
                f"{error}"
            ) from error

        index_label = f"spots_index/{spot['id']}"
        index_data = _snapshot_data(
            db.collection("spots_index").document(spot["id"]).get(),
            index_label,
        )
        _verify_spot_identity(index_data, spot, run_id, "name", index_label)
        _verify_freshness(index_data, index_label, run_started_at, now)

        canonical_conditions_id = conditions_spot_ids.get(spot["id"])
        if canonical_conditions_id is None:
            continue
        condition_document_ids = [canonical_conditions_id]
        alias_id = conditions_aliases.get(spot["id"])
        if alias_id is not None:
            condition_document_ids.append(alias_id)

        expected_summary = build_conditions_gfs_summary(
            weather["days"],
            CONDITIONS_FORECAST_DAYS,
            utc_offset_seconds=int(utc_offset_seconds),
            timezone_name=timezone_name,
        )
        for conditions_id in condition_document_ids:
            conditions_label = f"conditions/{conditions_id}"
            conditions_doc = _snapshot_data(
                db.collection("conditions").document(conditions_id).get(),
                conditions_label,
            )
            _verify_conditions_payload(
                conditions_doc,
                spot,
                run_id,
                conditions_label,
                run_started_at,
                now,
                allow_iso_timestamp=(
                    alias_id is not None and conditions_id == alias_id
                ),
                expected_utc_offset_seconds=int(utc_offset_seconds),
                expected_timezone_name=timezone_name,
            )
            gfs = conditions_doc.get("gfs")
            if not isinstance(gfs, dict):
                raise RuntimeError(
                    f"Vérification Production : {conditions_label}.gfs est absent "
                    "ou invalide."
                )
            if (
                gfs.get("forecast_run_id") != run_id
                or gfs.get("spot_id") != spot["id"]
            ):
                raise RuntimeError(
                    f"Vérification Production : métadonnées incorrectes dans "
                    f"{conditions_label}.gfs."
                )
            _verify_freshness(
                gfs,
                f"{conditions_label}.gfs",
                run_started_at,
                now,
            )
            if gfs.get("model") != expected_summary["model"]:
                raise RuntimeError(
                    f"Vérification Production : modèle incorrect dans "
                    f"{conditions_label}."
                )
            if gfs.get("hourly") != expected_summary["hourly"]:
                raise RuntimeError(
                    f"Vérification Production : résumé horaire incohérent dans "
                    f"{conditions_label}.gfs."
                )
            station_timezone = _open_meteo_timezone(
                timezone_name,
                utc_offset_seconds,
            )
            expected_gfs_count = len(
                _expected_utc_grid_instants(
                    date.fromisoformat(weather["days"][0]["date"]),
                    CONDITIONS_FORECAST_DAYS,
                    station_timezone,
                    step_hours=STEP_HOURS,
                )
            )
            if len(expected_summary["hourly"]) != expected_gfs_count:
                raise RuntimeError(
                    f"Vérification Production : {conditions_label} ne contient pas "
                    f"les {expected_gfs_count} "
                    "créneaux attendus."
                )
            verified_condition_documents.add(conditions_id)
        verified_conditions.add(spot["id"])

    if verified_conditions != set(conditions_spot_ids):
        raise RuntimeError(
            "Vérification Production : tous les résumés conditions n'ont pas été relus."
        )
    if verified_condition_documents != expected_condition_document_ids:
        raise RuntimeError(
            "Vérification Production : tous les documents conditions et leurs "
            "alias n'ont pas été relus."
        )

    print(
        "Vérification Production OK : "
        f"{len(spots)} météo + {len(spots)} index + "
        f"{len(verified_condition_documents)} conditions, run={run_id}."
    )


# ---------------------------------------------------------------------------
# 6. Pipeline principal (collection de test)
# ---------------------------------------------------------------------------
def main_test_single_spot(spot_id, spots_list=None):
    """
    Execute tout le pipeline pour UN SEUL spot et ecrit dans
    "spots_meteo_test/{spot_id}" — jamais dans "spots_meteo".
    """
    if not OPEN_METEO_API_KEY:
        raise SystemExit(
            "OPEN_METEO_API_KEY est obligatoire pour l'usage commercial d'Open-Meteo."
        )
    if spots_list is None:
        spots_list = SPOTS
    spot = next((s for s in spots_list if s["id"] == spot_id), None)
    if spot is None:
        raise ValueError(f"Spot '{spot_id}' introuvable dans la liste.")

    cred = credentials.Certificate("firebase-key.json")
    try:
        app = firebase_admin.get_app()
    except ValueError:
        app = firebase_admin.initialize_app(cred)
    db = firestore.client()

    lat, lon = spot["lat"], spot["lon"]
    print(f"=== TEST SINGLE SPOT : {spot['name']} ({lat}, {lon}) ===")

    # 3 appels API
    print("  [1/3] fetch_wind_model (GFS)...")
    wind_json = fetch_wind_model(lat, lon)
    print(f"        -> {len(wind_json['hourly']['time'])} creneaux horaires")

    print("  [2/3] fetch_hires_model (ECMWF IFS)...")
    hires_json = fetch_hires_model(lat, lon)
    print(f"        -> {len(hires_json['hourly']['time'])} creneaux horaires")

    print("  [3/3] fetch_wave_model (GFS-Wave)...")
    wave_json = fetch_wave_model(lat, lon)
    print(f"        -> {len(wave_json['hourly']['time'])} creneaux horaires")

    # Extraire daily (sunrise/sunset) depuis wind_json
    daily_json = {}
    if "daily" in wind_json:
        daily = wind_json["daily"]
        for i, d in enumerate(daily.get("time", [])):
            daily_json[d] = {
                "sunrise": daily["sunrise"][i] if i < len(daily.get("sunrise", [])) else None,
                "sunset": daily["sunset"][i] if i < len(daily.get("sunset", [])) else None,
            }

    days_payload, water_temp_c = build_days_payload(wind_json, hires_json, wave_json, daily_json)

    # Validation
    validate_payload(
        days_payload,
        int(_safe_num(wind_json.get("utc_offset_seconds"), 0) or 0),
    )

    # Construction du document
    doc = {
        "last_update": firestore.SERVER_TIMESTAMP,
        "location_name": spot["name"],
        "latitude": spot["lat"],
        "longitude": spot["lon"],
        "days": days_payload,
    }
    if water_temp_c is not None:
        doc["water_temp_c"] = water_temp_c
    # sunrise/sunset du jour courant (J+0)
    first_day = days_payload[0] if days_payload else None
    if first_day:
        if "sunrise" in first_day:
            doc["sunrise"] = first_day["sunrise"]
        if "sunset" in first_day:
            doc["sunset"] = first_day["sunset"]

    # Ecriture dans collection de TEST
    db.collection("spots_meteo_test").document(spot["id"]).set(doc)
    print(f"  -> Document ecrit dans spots_meteo_test/{spot['id']}")

    # Stats
    slot_count = sum(len(day["slots"]) for day in days_payload)
    import sys
    size_kb = sys.getsizeof(str(doc)) / 1024  # estimation grossiere
    print(f"  -> {len(days_payload)} jours, {slot_count} slots, ~{size_kb:.1f} KB")

    # Afficher les 2 premiers jours
    print("\n=== APERCU DU PAYLOAD (2 premiers jours) ===")
    import json
    for day in days_payload[:2]:
        print(f"\n--- {day['date']} ({len(day['slots'])} slots) ---")
        print(f"    sunrise: {day.get('sunrise')}, sunset: {day.get('sunset')}")
        for slot in day["slots"][:2]:
            # Afficher sans le sous-objet models pour lisibilite, puis le sous-objet a part
            slot_light = {k: v for k, v in slot.items() if k != "models"}
            print(f"    {json.dumps(slot_light, default=str)}")
            if slot.get("models"):
                print(f"    models.wind: {json.dumps(slot['models'].get('wind'), default=str)}")
                print(f"    models.hires: {json.dumps(slot['models'].get('hires'), default=str)}")
                print(f"    models.wave: {json.dumps(slot['models'].get('wave'), default=str)}")

    print(f"\n=== water_temp_c: {water_temp_c} ===")
    print("=== TERMINE ===")
    return doc


# ---------------------------------------------------------------------------
# 7. Main (utilise pour la recolte normale — Phase 3 uniquement)
# ---------------------------------------------------------------------------
def main():
    if not OPEN_METEO_API_KEY:
        raise SystemExit(
            "OPEN_METEO_API_KEY est obligatoire pour l'usage commercial d'Open-Meteo. "
            "Ajoutez-le aux secrets GitHub Actions."
        )
    if not FORECAST_RUN_ID:
        raise SystemExit(
            "FORECAST_RUN_ID est obligatoire pour tracer et vérifier chaque récolte."
        )
    if len(SPOTS) != EXPECTED_STATION_COUNT:
        raise SystemExit(
            "Catalogue de récolte inattendu : "
            f"{len(SPOTS)} spots au lieu de {EXPECTED_STATION_COUNT}."
        )
    if (
        len(CONDITIONS_SPOT_IDS) != EXPECTED_STATION_COUNT
        or set(CONDITIONS_SPOT_IDS) != {spot["id"] for spot in SPOTS}
        or any(
            source_id != document_id
            for source_id, document_id in CONDITIONS_SPOT_IDS.items()
        )
    ):
        raise SystemExit(
            "Configuration conditions inattendue : chaque station du catalogue "
            "doit posséder son propre document."
        )
    if (
        set(LEGACY_CONDITIONS_ALIASES)
        != {
            "casablanca_maroc",
            "rabat_maroc",
            "agadir_maroc",
            "tanger_maroc",
            "essaouira_maroc",
        }
        or set(LEGACY_CONDITIONS_ALIASES.values())
        & set(CONDITIONS_SPOT_IDS.values())
    ):
        raise SystemExit(
            "Configuration des alias historiques conditions inattendue."
        )

    start_time = time.time()
    run_started_at = datetime.now(timezone.utc)

    cred = credentials.Certificate("firebase-key.json")
    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(cred)
    db = firestore.client()

    # Aucune écriture n'est créée tant que les 143 stations n'ont pas
    # toutes passé les contrôles modèles/build/dates/créneaux. Les documents
    # sont ensuite publiés par lots atomiques bornés sous la limite de 10 Mio.
    publications, write_count, commit_count = _prepare_and_publish_forecasts(
        db,
        _iter_station_results(SPOTS),
        FORECAST_RUN_ID,
        expected_spot_count=len(SPOTS),
    )
    success = len(publications)

    elapsed = time.time() - start_time
    print(f"\n{'='*60}")
    print(f"Termine en {elapsed:.0f}s.")
    print(f"Réussis: {success}")
    print(f"Total spots: {len(SPOTS)}")
    print(f"Écritures Firestore: {write_count}")
    print(f"Lots Firestore atomiques: {commit_count}")
    if success != len(SPOTS):
        raise RuntimeError(
            f"Récolte incomplète : {success}/{len(SPOTS)} stations écrites."
        )
    expected_write_count = (
        len(SPOTS) * 2
        + len(CONDITIONS_SPOT_IDS)
        + len(LEGACY_CONDITIONS_ALIASES)
    )
    if write_count != expected_write_count:
        raise RuntimeError(
            "Publication incomplète : "
            f"{write_count}/{expected_write_count} écritures Firestore."
        )

    # Le job n'est vert qu'après relecture de l'intégralité de l'état publié.
    verify_production_state(
        db,
        SPOTS,
        FORECAST_RUN_ID,
        run_started_at,
    )


if __name__ == "__main__":
    main()
