# ============================================================================
# harvest_forecast.py
# Recupere vent + houle + temperature/nuages/pluie via Open-Meteo (gratuit,
# sans cle API), calcule une note en etoiles, et pousse tout sur Firestore.
#
# Structure ecrite dans Firestore, collection "spots_meteo",
# document "{spot_id}" :
# {
#   "last_update": <timestamp serveur>,
#   "location_name": "Lancelin",
#   "latitude": -31.02, "longitude": 115.33,
#   "days": [
#     { "date": "2026-07-08",
#       "slots": [
#         { "hour": "2026-07-08T08:00", "wind_speed_kt": 7.2, "wind_gust_kt": 10.0,
#           "wind_dir_deg": 190, "wave_height_m": 1.7, "wave_period_s": 13,
#           "wave_dir_deg": 210, "temp_c": 24, "cloud_pct": 30,
#           "precip_pct": 10, "rating": 3 },
#         ...
#       ]
#     }, ...
#   ]
# }
#
# Usage : python harvest_forecast.py
# Variables a adapter : SPOTS ci-dessous.
# ============================================================================

import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
from collections import defaultdict

# ----------------------------------------------------------------------------
# 1. Liste des spots a moissonner. Ajoute-en autant que tu veux.
# ----------------------------------------------------------------------------
SPOTS = [
    {"id": "lancelin_australia", "name": "Australia - Lancelin", "lat": -31.02, "lon": 115.33},
    {"id": "casablanca_maroc", "name": "Casablanca Morocco", "lat": 33.57, "lon": -7.59},
]

FORECAST_DAYS = 15
STEP_HOURS = 3  # on garde 1 creneau toutes les 3h, comme sur le tableau Windguru

MS_TO_KNOTS = 1.94384


def ms_to_knots(v):
    return round(v * MS_TO_KNOTS, 1) if v is not None else None


def compute_rating(wind_kt, wave_m, precip_pct):
    """Note simplifiee sur 5 etoiles. A adapter selon tes propres criteres
    (spot de kite, surf, peche, apnee...)."""
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


def fetch_weather(lat, lon):
    """Vent, temperature, nuages, pluie (API forecast standard)."""
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": lat,
        "longitude": lon,
        "hourly": "wind_speed_10m,wind_gusts_10m,wind_direction_10m,"
                  "temperature_2m,cloudcover,precipitation_probability",
        "wind_speed_unit": "ms",
        "timezone": "auto",
        "forecast_days": FORECAST_DAYS,
    }
    r = requests.get(url, params=params, timeout=30)
    r.raise_for_status()
    return r.json()


def fetch_marine(lat, lon):
    """Houle (API marine dediee)."""
    url = "https://marine-api.open-meteo.com/v1/marine"
    params = {
        "latitude": lat,
        "longitude": lon,
        "hourly": "wave_height,wave_period,wave_direction",
        "timezone": "auto",
        "forecast_days": FORECAST_DAYS,
    }
    r = requests.get(url, params=params, timeout=30)
    r.raise_for_status()
    return r.json()


def build_days_payload(weather_json, marine_json):
    w = weather_json["hourly"]
    m = marine_json["hourly"]

    # On indexe la houle par timestamp pour merger facilement avec la meteo
    marine_by_time = {t: i for i, t in enumerate(m["time"])}

    days = defaultdict(list)

    for i, t in enumerate(w["time"]):
        dt = datetime.fromisoformat(t)
        if dt.hour % STEP_HOURS != 0:
            continue  # on ne garde qu'un creneau toutes les STEP_HOURS heures

        mi = marine_by_time.get(t)
        # Les champs houle sont None quand l'API Marine ne renvoie rien pour ce creneau
        wave_h = m["wave_height"][mi] if mi is not None else None
        wave_p = m["wave_period"][mi] if mi is not None else None
        wave_d = m["wave_direction"][mi] if mi is not None else None

        wind_kt = ms_to_knots(w["wind_speed_10m"][i])
        gust_kt = ms_to_knots(w["wind_gusts_10m"][i])
        precip = w["precipitation_probability"][i]

        slot = {
            "hour": t,
            "wind_speed_kt": wind_kt,
            "wind_gust_kt": gust_kt,
            "wind_dir_deg": w["wind_direction_10m"][i],
            "wave_height_m": wave_h,
            "wave_period_s": wave_p,
            "wave_dir_deg": wave_d,
            "temp_c": round(w["temperature_2m"][i]),
            "cloud_pct": w["cloudcover"][i],
            "precip_pct": precip,
            "rating": compute_rating(wind_kt, wave_h, precip),
        }

        day_key = t[:10]  # "YYYY-MM-DD"
        days[day_key].append(slot)

    return [{"date": d, "slots": slots} for d, slots in sorted(days.items())]


def main():
    cred = credentials.Certificate("firebase-key.json")
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    for spot in SPOTS:
        try:
            print(f"Recolte pour {spot['name']}...")
            weather_json = fetch_weather(spot["lat"], spot["lon"])
            marine_json = fetch_marine(spot["lat"], spot["lon"])
            days_payload = build_days_payload(weather_json, marine_json)

            db.collection("spots_meteo").document(spot["id"]).set({
                "last_update": firestore.SERVER_TIMESTAMP,
                "location_name": spot["name"],
                "latitude": spot["lat"],
                "longitude": spot["lon"],
                "days": days_payload,
            })
            print(f"  -> {len(days_payload)} jours envoyes sur Firestore.")
        except Exception as e:
            print(f"  !! Erreur pour {spot['name']}: {e}")

    print("Termine.")


if __name__ == "__main__":
    main()
