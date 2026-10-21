import copy
import unittest
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import harvest_forecast as harvest
from tests_python.test_harvest_forecast import _dst_hourly_api_payloads


def fixed_offset_response(zone_name, first_day, *, epochs):
    spot = {'id': 'fixture', 'name': 'Fixture', 'lat': 31.2, 'lon': 29.92}
    wind, wave, _, _ = _dst_hourly_api_payloads(
        spot, first_day, day_count=15, timezone_name=zone_name,
    )
    offset = wind['utc_offset_seconds']
    start = datetime.combine(first_day, datetime.min.time(), tzinfo=timezone.utc) - timedelta(seconds=offset)
    utc_times = [start + timedelta(hours=i) for i in range(15 * 24)]
    for model in (wind, wave):
        model['hourly'] = {
            key: ([int(x.timestamp()) for x in utc_times] if epochs else [
                (x + timedelta(seconds=offset)).replace(tzinfo=None).isoformat(timespec='minutes')
                for x in utc_times
            ]) if key == 'time' else [values[0]] * len(utc_times)
            for key, values in model['hourly'].items()
        }
    daily = {'time': [], 'sunrise': [], 'sunset': []}
    zone = ZoneInfo(zone_name)
    for i in range(15):
        civil_day = first_day + timedelta(days=i)
        # Open-Meteo daily boundaries use the response's fixed offset.
        boundary = datetime.combine(civil_day, datetime.min.time(), tzinfo=timezone.utc) - timedelta(seconds=offset)
        daily['time'].append(int(boundary.timestamp()) if epochs else civil_day.isoformat())
        for field, hour in [('sunrise', 6), ('sunset', 18)]:
            instant = datetime.combine(civil_day, datetime.min.time()).replace(hour=hour, tzinfo=zone).astimezone(timezone.utc)
            daily[field].append(int(instant.timestamp()) if epochs else instant.astimezone(zone).replace(tzinfo=None).isoformat(timespec='minutes'))
    wind['daily'] = daily
    return spot, wind, wave, utc_times


def publication(zone_name, first_day, *, epochs):
    spot, wind, wave, utc_times = fixed_offset_response(zone_name, first_day, epochs=epochs)
    result = harvest._build_station_publication(
        {'spot': spot, 'models': {'wind': wind, 'hires': wind, 'wave': wave}},
        'epoch-dst-regression', conditions_spot_ids={spot['id']: spot['id']},
    )
    return result, utc_times


class OpenMeteoEpochDstTests(unittest.TestCase):
    def test_request_uses_unambiguous_epochs(self):
        self.assertEqual('unixtime', harvest._base_params(30.4, -9.6)['timeformat'])

    def test_cairo_fixed_iso_reproduces_production_failure(self):
        with self.assertRaisesRegex(ValueError, '9 créneaux GFS natifs'):
            publication('Africa/Cairo', date(2026, 10, 21), epochs=False)

    def test_cairo_epochs_publish_nine_native_steps_without_fabricating(self):
        result, _ = publication('Africa/Cairo', date(2026, 10, 21), epochs=True)
        days = result['weather_doc']['days']
        transition = next(d for d in days if d['date'] == '2026-10-29')
        self.assertEqual(9, len(transition['slots']))
        instants = [datetime.fromisoformat(s['hour_utc'].replace('Z', '+00:00')) for d in days for s in d['slots']]
        self.assertTrue(all(b - a == timedelta(hours=3) for a, b in zip(instants, instants[1:])))
        self.assertTrue(all(x.hour % 3 == 0 for x in instants))
        zone = ZoneInfo('Africa/Cairo')
        self.assertEqual([x.astimezone(zone).replace(tzinfo=None).isoformat(timespec='minutes') for x in instants], [s['hour'] for d in days for s in d['slots']])

    def test_missing_cairo_native_step_remains_rejected(self):
        result, _ = publication('Africa/Cairo', date(2026, 10, 21), epochs=True)
        days = result['weather_doc']['days']
        next(d for d in days if d['date'] == '2026-10-29')['slots'].pop()
        with self.assertRaisesRegex(ValueError, '9 créneaux GFS natifs'):
            harvest.validate_payload(days, 10800, timezone_name='Africa/Cairo')

    def test_morocco_payload_is_unchanged_by_epoch_transport(self):
        legacy, _ = publication('Africa/Casablanca', date(2026, 10, 21), epochs=False)
        epochs, _ = publication('Africa/Casablanca', date(2026, 10, 21), epochs=True)
        for key in ['weather_doc', 'conditions_doc']:
            for payload in [legacy[key], epochs[key]]:
                payload.pop('timestamp', None)
                payload.pop('last_update', None)
                if isinstance(payload.get('gfs'), dict):
                    payload['gfs'].pop('timestamp', None)
            self.assertEqual(legacy[key], epochs[key])

    def test_daily_fixed_offset_labels_survive_cairo_fall_back(self):
        result, _ = publication('Africa/Cairo', date(2026, 10, 21), epochs=True)
        for day in result['weather_doc']['days']:
            self.assertTrue(day['sunrise'].startswith(day['date']))
            self.assertTrue(day['sunset'].startswith(day['date']))
        self.assertEqual(10, len(result['weather_doc']['days']))

    def test_conditions_keep_continuous_epochs_across_cairo_transition(self):
        result, _ = publication('Africa/Cairo', date(2026, 10, 25), epochs=True)
        conditions = result['conditions_doc']
        tide = [s['time'] for s in conditions['tide']['hourly']]
        weather = [s['time'] for s in conditions['weather']['hourly']]
        self.assertEqual(tide, weather)
        self.assertEqual(193, len(tide))
        instants = [datetime.fromisoformat(x.replace('Z', '+00:00')) for x in tide]
        self.assertTrue(all(b - a == timedelta(hours=1) for a, b in zip(instants, instants[1:])))

    def test_reversed_and_duplicate_epoch_instants_are_rejected(self):
        for values in [[1792530000, 1792530000], [1792533600, 1792530000]]:
            with self.assertRaisesRegex(ValueError, 'strictement croissants'):
                harvest._utc_datetimes_from_open_meteo(values, 10800, 'Africa/Cairo')
