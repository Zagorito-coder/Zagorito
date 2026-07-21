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
#   "water_temp_c": 22.4,            // nouveau – derniere SST non-null
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
import time
import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
from collections import defaultdict

# ---------------------------------------------------------------------------
# URLs commerciales : la clé doit rester côté serveur/GitHub Actions.
# ---------------------------------------------------------------------------
# Clé commerciale injectée uniquement par le job serveur/GitHub Actions.
OPEN_METEO_API_KEY = os.environ.get("OPEN_METEO_API_KEY")

FORECAST_BASE_URL = "https://customer-api.open-meteo.com/v1/forecast"
MARINE_BASE_URL = "https://customer-marine-api.open-meteo.com/v1/marine"

# ---------------------------------------------------------------------------
# 1. Liste des spots a moissonner. Ajoute-en autant que tu veux.
# ---------------------------------------------------------------------------
SPOTS = [
    # === Afrique du Nord (Maghreb) ===
    {"id": "casablanca_maroc", "name": "Casablanca, Maroc", "lat": 33.57, "lon": -7.59},
    {"id": "agadir_maroc", "name": "Agadir, Maroc", "lat": 30.42, "lon": -9.60},
    {"id": "tanger_maroc", "name": "Tanger, Maroc", "lat": 35.77, "lon": -5.81},
    {"id": "rabat_maroc", "name": "Rabat, Maroc", "lat": 34.02, "lon": -6.84},
    {"id": "essaouira_maroc", "name": "Essaouira, Maroc", "lat": 31.51, "lon": -9.77},
    {"id": "dakhla_maroc", "name": "Dakhla, Maroc", "lat": 23.70, "lon": -15.93},
    {"id": "laayoune_maroc", "name": "Laayoune, Maroc", "lat": 27.15, "lon": -13.20},
    {"id": "safi_maroc", "name": "Safi, Maroc", "lat": 32.30, "lon": -9.24},
    {"id": "eljadida_maroc", "name": "El Jadida, Maroc", "lat": 33.23, "lon": -8.50},
    {"id": "mohammedia_maroc", "name": "Mohammedia, Maroc", "lat": 33.69, "lon": -7.38},
    {"id": "tetouan_maroc", "name": "Tetouan, Maroc", "lat": 35.57, "lon": -5.37},
    {"id": "alhoceima_maroc", "name": "Al Hoceima, Maroc", "lat": 35.25, "lon": -3.93},
    {"id": "nador_maroc", "name": "Nador, Maroc", "lat": 35.17, "lon": -2.93},
    {"id": "larache_maroc", "name": "Larache, Maroc", "lat": 35.19, "lon": -6.15},
    {"id": "mdiq_maroc", "name": "Mdiq, Maroc", "lat": 35.69, "lon": -5.32},
    {"id": "alger_algerie", "name": "Alger, Algérie", "lat": 36.75, "lon": 3.04},
    {"id": "oran_algerie", "name": "Oran, Algérie", "lat": 35.70, "lon": -0.64},
    {"id": "annaba_algerie", "name": "Annaba, Algérie", "lat": 36.90, "lon": 7.77},
    {"id": "bejaia_algerie", "name": "Bejaia, Algérie", "lat": 36.75, "lon": 5.07},
    {"id": "skikda_algerie", "name": "Skikda, Algérie", "lat": 36.88, "lon": 6.90},
    {"id": "mostaganem_algerie", "name": "Mostaganem, Algérie", "lat": 35.93, "lon": 0.09},
    {"id": "tipaza_algerie", "name": "Tipaza, Algérie", "lat": 36.59, "lon": 2.44},
    {"id": "tunis_tunisie", "name": "Tunis, Tunisie", "lat": 36.80, "lon": 10.18},
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
    {"id": "portharcourt_nigeria", "name": "Port Harcourt, Nigéria", "lat": 4.82, "lon": 7.05},
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
    {"id": "basra_irak", "name": "Bassorah, Irak", "lat": 30.50, "lon": 47.82},
    {"id": "aden_yemen", "name": "Aden, Yémen", "lat": 12.78, "lon": 45.03},
    {"id": "mukalla_yemen", "name": "Mukalla, Yémen", "lat": 14.54, "lon": 49.13},
    {"id": "hodeidah_yemen", "name": "Al Hudaydah, Yémen", "lat": 14.80, "lon": 42.95},
    {"id": "port_soudan_soudan", "name": "Port-Soudan, Soudan", "lat": 19.62, "lon": 37.22},
    {"id": "aqaba_jordanie", "name": "Aqaba, Jordanie", "lat": 29.53, "lon": 35.01},
    {"id": "eilat_israel", "name": "Eilat, Israël", "lat": 29.56, "lon": 34.95},
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
    """Note simplifiee sur 5 etoiles."""
    score = 0
    if wind_kt is not None:
        if 8 <= wind_kt <= 22:
            score += 2
        elif 5 <= wind_kt < 8 or 22 < wind_kt <= 28:
            score += 1
    if wave_m is not None:
        if 0.5 <= wave_m <= 2.5:
            score += 2
        elif wave_m < 0.5:
            score += 1
    if precip_pct is not None and precip_pct < 30:
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


def _error_summary(error):
    """Résumé sûr pour les logs : ne jamais imprimer une URL avec apikey."""
    response = getattr(error, "response", None)
    status = getattr(response, "status_code", None)
    if status is not None:
        return f"HTTP {status} ({type(error).__name__})"
    return type(error).__name__


# ---------------------------------------------------------------------------
# 2. Fonctions de fetch par modele
# ---------------------------------------------------------------------------
HOURLY_COMMON_WIND = (
    "wind_speed_10m,wind_gusts_10m,wind_direction_10m,"
    "temperature_2m,cloud_cover_low,cloud_cover_mid,cloud_cover_high,"
    "precipitation_probability,pressure_msl,relative_humidity_2m"
)

HOURLY_WAVE = (
    "wave_height,wave_period,wave_direction,"
    "swell_wave_height,swell_wave_period,swell_wave_direction,"
    "secondary_swell_wave_height,secondary_swell_wave_period,"
    "secondary_swell_wave_direction,"
    "wind_wave_height,wind_wave_period,wind_wave_direction,"
    "sea_surface_temperature"
)


def _fetch_json(url, params):
    """Appel HTTP sans laisser la clé apikey apparaître dans les erreurs."""
    response = requests.get(url, params=params, timeout=30)
    if not response.ok:
        raise RuntimeError(f"Open-Meteo HTTP {response.status_code}")
    return response.json()


def fetch_wind_model(lat, lon):
    """GFS ~13km — modele vent principal."""
    url = FORECAST_BASE_URL
    params = _base_params(lat, lon)
    params.update({
        "hourly": HOURLY_COMMON_WIND,
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
    })
    return _fetch_json(url, params)


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
        "precip_prob_pct": _safe_num(h["precipitation_probability"][i]),
        "pressure_msl": _safe_num(h["pressure_msl"][i]),
        "rel_humidity_pct": _safe_num(h["relative_humidity_2m"][i]),
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
        "precip_prob_pct": _safe_num(h["precipitation_probability"][i]),
        "pressure_msl": _safe_num(h["pressure_msl"][i]),
        "rel_humidity_pct": _safe_num(h["relative_humidity_2m"][i]),
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
    }


# ---------------------------------------------------------------------------
# 4. Fusion des 3 modeles + champs racine historiques
# ---------------------------------------------------------------------------
def build_days_payload(wind_json, hires_json, wave_json, daily_json):
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

    wind_by_time = {t: i for i, t in enumerate(w_data["time"])}
    hires_by_time = {t: i for i, t in enumerate(h_data["time"])}
    wave_by_time = {t: i for i, t in enumerate(m_data["time"])}

    days = defaultdict(list)
    water_temp_values = []

    for i, t in enumerate(w_data["time"]):
        dt = datetime.fromisoformat(t)
        if dt.hour % STEP_HOURS != 0:
            continue

        # --- modele vent GFS (utilise comme champs racine pour compat arriere) ---
        wind_kt = ms_to_knots(_safe_num(w_data["wind_speed_10m"][i]))
        gust_kt = ms_to_knots(_safe_num(w_data["wind_gusts_10m"][i]))
        wind_dir = _safe_num(w_data["wind_direction_10m"][i])
        temp_c = _safe_num(w_data["temperature_2m"][i], None)
        precip = _safe_num(w_data["precipitation_probability"][i])

        # --- modele vagues (houle primaire pour champs racine) ---
        mi = wave_by_time.get(t)
        wave_h = _safe_num(m_data["wave_height"][mi]) if mi is not None else None
        wave_p = _safe_num(m_data["wave_period"][mi]) if mi is not None else None
        wave_d = _safe_num(m_data["wave_direction"][mi]) if mi is not None else None

        # SST
        sst = _safe_num(m_data["sea_surface_temperature"][mi]) if mi is not None else None
        if sst is not None:
            water_temp_values.append(sst)

        # --- sous-objet models ---
        wind_slot = _extract_wind_model_slot(wind_json, wind_by_time, t)
        hires_slot = _extract_hires_model_slot(hires_json, hires_by_time, t)
        wave_slot = _extract_wave_model_slot(wave_json, wave_by_time, t)

        # --- cloud_pct pour champs racine (on utilise low+mid+high du modele vent) ---
        cloud_low = _safe_num(w_data["cloud_cover_low"][i]) or 0
        cloud_mid = _safe_num(w_data["cloud_cover_mid"][i]) or 0
        cloud_high = _safe_num(w_data["cloud_cover_high"][i]) or 0
        cloud_total = max(cloud_low, cloud_mid, cloud_high)  # approximation

        slot = {
            # champs racine (compat arriere)
            "hour": t,
            "wind_speed_kt": wind_kt,
            "wind_gust_kt": gust_kt,
            "wind_dir_deg": wind_dir,
            "wave_height_m": wave_h,
            "wave_period_s": wave_p,
            "wave_dir_deg": wave_d,
            "temp_c": round(temp_c) if temp_c is not None else None,
            "cloud_pct": round(cloud_total),
            "precip_pct": precip,
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

    water_temp_c = round(water_temp_values[-1], 1) if water_temp_values else None
    return days_payload, water_temp_c


# ---------------------------------------------------------------------------
# 5. Validation
# ---------------------------------------------------------------------------
def validate_payload(days_payload):
    """
    Verifie qu'au moins 50% des slots ont des valeurs non-null pour
    wind_speed_kt et wave.height_m (dans le sous-objet models.wave).
    Leve ValueError si ce n'est pas le cas.
    """
    total = 0
    ok_wind = 0
    ok_wave = 0
    for day in days_payload:
        for slot in day["slots"]:
            total += 1
            if slot.get("wind_speed_kt") is not None:
                ok_wind += 1
            models = slot.get("models", {})
            wave_model = models.get("wave", {}) if models else {}
            if wave_model and wave_model.get("wave_height_m") is not None:
                ok_wave += 1

    if total == 0:
        raise ValueError("Payload vide : aucun slot genere.")

    ratio_wind = ok_wind / total
    ratio_wave = ok_wave / total

    if ratio_wind < 0.5:
        raise ValueError(
            f"Validation echouee : seulement {ratio_wind:.1%} des slots "
            f"ont wind_speed_kt non-null (seuil 50%)."
        )
    if ratio_wave < 0.5:
        raise ValueError(
            f"Validation echouee : seulement {ratio_wave:.1%} des slots "
            f"ont wave.height_m non-null (seuil 50%)."
        )

    print(f"  Validation OK : wind={ratio_wind:.1%} wave={ratio_wave:.1%} "
          f"sur {total} slots.")


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
    validate_payload(days_payload)

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
    import time as time_module
    if not OPEN_METEO_API_KEY:
        raise SystemExit(
            "OPEN_METEO_API_KEY est obligatoire pour l'usage commercial d'Open-Meteo. "
            "Ajoutez-le aux secrets GitHub Actions."
        )
    start_time = time_module.time()

    cred = credentials.Certificate("firebase-key.json")
    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(cred)
    db = firestore.client()

    success = 0
    partial = 0
    failed = 0

    for idx, spot in enumerate(SPOTS):
        missing_models = []
        wind_json = None
        hires_json = None
        wave_json = None

        print(f"Recolte pour {spot['name']}...")
        lat, lon = spot["lat"], spot["lon"]

        # --- try/except PAR MODELE ---
        try:
            wind_json = fetch_wind_model(lat, lon)
            print(f"  [wind] OK ({len(wind_json['hourly']['time'])} slots)")
        except Exception as e:
            print(f"  [wind] ECHEC: {_error_summary(e)}")
            missing_models.append("wind")

        try:
            hires_json = fetch_hires_model(lat, lon)
            print(f"  [hires] OK ({len(hires_json['hourly']['time'])} slots)")
        except Exception as e:
            print(f"  [hires] ECHEC: {_error_summary(e)}")
            missing_models.append("hires")

        try:
            wave_json = fetch_wave_model(lat, lon)
            print(f"  [wave] OK ({len(wave_json['hourly']['time'])} slots)")
        except Exception as e:
            print(f"  [wave] ECHEC: {_error_summary(e)}")
            missing_models.append("wave")

        # Si aucun modele vent (obligatoire), on skip ce spot
        if wind_json is None:
            print(f"  !! Aucun modele vent disponible pour {spot['name']}, spot ignore.")
            failed += 1
            if idx < len(SPOTS) - 1:
                time.sleep(0.2)
            continue

        # Construire quand meme avec les modeles disponibles
        daily_json = {}
        if "daily" in wind_json:
            daily = wind_json["daily"]
            for i, d in enumerate(daily.get("time", [])):
                daily_json[d] = {
                    "sunrise": daily["sunrise"][i] if i < len(daily.get("sunrise", [])) else None,
                    "sunset": daily["sunset"][i] if i < len(daily.get("sunset", [])) else None,
                }

        # Si hires ou wave manquent, on passe des json vides pour que build_days_payload
        # remplisse les slots avec null dans le sous-objet correspondant
        if hires_json is None:
            hires_json = {"hourly": {"time": [], "wind_speed_10m": [], "wind_gusts_10m": [],
                                     "wind_direction_10m": [], "temperature_2m": [],
                                     "cloud_cover_low": [], "cloud_cover_mid": [],
                                     "cloud_cover_high": [], "precipitation_probability": [],
                                     "pressure_msl": [], "relative_humidity_2m": []}}
        if wave_json is None:
            wave_json = {"hourly": {"time": [], "wave_height": [], "wave_period": [],
                                    "wave_direction": [], "swell_wave_height": [],
                                    "swell_wave_period": [], "swell_wave_direction": [],
                                    "secondary_swell_wave_height": [],
                                    "secondary_swell_wave_period": [],
                                    "secondary_swell_wave_direction": [],
                                    "wind_wave_height": [], "wind_wave_period": [],
                                    "wind_wave_direction": [],
                                    "sea_surface_temperature": []}}

        try:
            days_payload, water_temp_c = build_days_payload(wind_json, hires_json, wave_json, daily_json)
            validate_payload(days_payload)

            doc = {
                "last_update": firestore.SERVER_TIMESTAMP,
                "location_name": spot["name"],
                "latitude": spot["lat"],
                "longitude": spot["lon"],
                "days": days_payload,
            }
            if water_temp_c is not None:
                doc["water_temp_c"] = water_temp_c
            first_day = days_payload[0] if days_payload else None
            if first_day:
                if "sunrise" in first_day:
                    doc["sunrise"] = first_day["sunrise"]
                if "sunset" in first_day:
                    doc["sunset"] = first_day["sunset"]

            db.collection("spots_meteo").document(spot["id"]).set(doc)
            # Ecrit aussi l'index leger pour listAvailableSpots() sans OOM
            db.collection("spots_index").document(spot["id"]).set({
                "name": spot["name"],
                "latitude": spot["lat"],
                "longitude": spot["lon"],
            })
            print(f"  -> {len(days_payload)} jours envoyes sur Firestore.")

            if missing_models:
                partial += 1
                print(f"  -> PARTIEL (modeles manquants: {missing_models})")
            else:
                success += 1

        except Exception as e:
            print(f"  !! Erreur build/write pour {spot['name']}: {_error_summary(e)}")
            failed += 1

        # Delai entre spots pour rester sous 600 appels/minute
        if idx < len(SPOTS) - 1:
            time.sleep(0.2)

    elapsed = time_module.time() - start_time
    print(f"\n{'='*60}")
    print(f"Termine en {elapsed:.0f}s.")
    print(f"Reussis: {success}, Partiels: {partial}, Echoues: {failed}")
    print(f"Total spots: {len(SPOTS)}")

    # Ne pas laisser GitHub Actions afficher un succès lorsque des spots
    # n'ont pas été actualisés : l'application risquerait de servir des
    # prévisions périmées sans alerte opérationnelle. Les documents écrits
    # avec succès restent disponibles pour les utilisateurs.
    if failed > 0 or partial > 0:
        raise SystemExit(
            f"Récolte incomplète : {failed} échec(s), {partial} résultat(s) partiel(s)."
        )


if __name__ == "__main__":
    main()
