import threading
import time
import unittest
from unittest import mock

import requests

import harvest_forecast


class FakeResponse:
    def __init__(self, status_code=200, payload=None):
        self.status_code = status_code
        self.ok = 200 <= status_code < 300
        self._payload = {} if payload is None else payload

    def json(self):
        if isinstance(self._payload, Exception):
            raise self._payload
        return self._payload


class FetchJsonTests(unittest.TestCase):
    def test_read_timeout_is_retried_then_succeeds(self):
        requester = mock.Mock(
            side_effect=[
                requests.ReadTimeout("secret URL must not be logged"),
                FakeResponse(payload={"hourly": {"time": []}}),
            ]
        )
        delays = []

        result = harvest_forecast._fetch_json(
            "https://example.invalid",
            {"apikey": "top-secret"},
            requester=requester,
            sleeper=delays.append,
            jitter=lambda: 0.0,
        )

        self.assertEqual({"hourly": {"time": []}}, result)
        self.assertEqual(2, requester.call_count)
        self.assertEqual([1.0], delays)
        self.assertEqual(
            harvest_forecast.HTTP_TIMEOUT,
            requester.call_args_list[0].kwargs["timeout"],
        )

    def test_retryable_http_status_is_retried(self):
        requester = mock.Mock(
            side_effect=[
                FakeResponse(status_code=429),
                FakeResponse(payload={"ok": True}),
            ]
        )
        delays = []

        result = harvest_forecast._fetch_json(
            "https://example.invalid",
            {},
            requester=requester,
            sleeper=delays.append,
            jitter=lambda: 0.0,
        )

        self.assertEqual({"ok": True}, result)
        self.assertEqual(2, requester.call_count)
        self.assertEqual([1.0], delays)

    def test_permanent_http_status_fails_without_retry(self):
        requester = mock.Mock(return_value=FakeResponse(status_code=400))
        delays = []

        with self.assertRaises(harvest_forecast.OpenMeteoHttpError) as context:
            harvest_forecast._fetch_json(
                "https://example.invalid",
                {},
                requester=requester,
                sleeper=delays.append,
                jitter=lambda: 0.0,
            )

        self.assertEqual(400, context.exception.status_code)
        self.assertEqual(1, requester.call_count)
        self.assertEqual([], delays)

    def test_invalid_json_is_retried(self):
        requester = mock.Mock(
            side_effect=[
                FakeResponse(payload=ValueError("truncated")),
                FakeResponse(payload={"ok": True}),
            ]
        )

        result = harvest_forecast._fetch_json(
            "https://example.invalid",
            {},
            requester=requester,
            sleeper=lambda _: None,
            jitter=lambda: 0.0,
        )

        self.assertEqual({"ok": True}, result)
        self.assertEqual(2, requester.call_count)

    def test_error_summary_never_echoes_request_details(self):
        error = requests.ReadTimeout(
            "https://example.invalid?apikey=top-secret timed out"
        )

        self.assertEqual("ReadTimeout", harvest_forecast._error_summary(error))


class StationCollectionTests(unittest.TestCase):
    def test_station_model_failure_is_isolated(self):
        spot = {"id": "test", "name": "Test", "lat": 1.0, "lon": 2.0}

        def success(_lat, _lon):
            return {"hourly": {"time": []}}

        def failure(_lat, _lon):
            raise requests.ReadTimeout("timeout")

        result = harvest_forecast._fetch_station_models(
            spot,
            fetchers=(
                ("wind", success),
                ("hires", failure),
                ("wave", success),
            ),
        )

        self.assertIs(result["spot"], spot)
        self.assertIsNone(result["models"]["hires"])
        self.assertIsInstance(result["errors"]["hires"], requests.ReadTimeout)
        self.assertIsNotNone(result["models"]["wind"])
        self.assertIsNotNone(result["models"]["wave"])

    def test_parallel_iterator_is_bounded_and_returns_every_spot(self):
        spots = [
            {"id": str(index), "name": str(index), "lat": 0.0, "lon": 0.0}
            for index in range(12)
        ]
        active = 0
        maximum_active = 0
        lock = threading.Lock()

        def fake_fetch(spot):
            nonlocal active, maximum_active
            with lock:
                active += 1
                maximum_active = max(maximum_active, active)
            time.sleep(0.005)
            with lock:
                active -= 1
            return {"spot": spot, "models": {}, "errors": {}}

        with mock.patch.object(
            harvest_forecast,
            "_fetch_station_models",
            side_effect=fake_fetch,
        ):
            results = list(
                harvest_forecast._iter_station_results(spots, max_workers=3)
            )

        self.assertEqual(
            {spot["id"] for spot in spots},
            {result["spot"]["id"] for result in results},
        )
        self.assertLessEqual(maximum_active, 3)
        self.assertGreater(maximum_active, 1)


if __name__ == "__main__":
    unittest.main()
