import unittest

from tools.enrich_spots_catalog import (
    DEFAULT_FISH,
    DEFAULT_NOTE,
    arabic_to_latin,
    enrich_rows,
    has_arabic,
    has_latin,
    latin_to_arabic,
    validate_transform,
)


def _row(name, latitude="30.1", longitude="-9.2", fish="", notes=""):
    return {
        "Nom": name,
        "Latitude": latitude,
        "Longitude": longitude,
        "Poissons": fish,
        "Notes": notes,
    }


class EnrichSpotsCatalogTest(unittest.TestCase):
    def test_common_geographic_words_are_translated(self):
        self.assertIn("Cap", arabic_to_latin("الرأس"))
        self.assertIn("شاطئ", latin_to_arabic("Plage Rouge"))

    def test_only_missing_values_are_completed(self):
        original = [
            _row("الرأس", fish="sar|dorade", notes="Note existante"),
            _row("Plage Rouge", latitude="31.2", longitude="-8.3"),
            _row(
                "واد اورير - Oued Aourir",
                latitude="32.3",
                longitude="-7.4",
            ),
        ]

        enriched, report = enrich_rows(original)

        self.assertEqual(enriched[0]["Poissons"], "sar|dorade")
        self.assertEqual(enriched[0]["Notes"], "Note existante")
        self.assertEqual(enriched[1]["Poissons"], DEFAULT_FISH)
        self.assertEqual(enriched[1]["Notes"], DEFAULT_NOTE)
        self.assertEqual(enriched[2]["Nom"], original[2]["Nom"])
        self.assertEqual(report.names_from_arabic, 1)
        self.assertEqual(report.names_from_latin, 1)
        self.assertEqual(report.names_already_bilingual, 1)

        for before, after in zip(original, enriched):
            self.assertEqual(after["Latitude"], before["Latitude"])
            self.assertEqual(after["Longitude"], before["Longitude"])
            self.assertIn(before["Nom"], after["Nom"])
            self.assertTrue(has_arabic(after["Nom"]))
            self.assertTrue(has_latin(after["Nom"]))

    def test_coordinate_change_is_rejected(self):
        original = [_row("الرأس")]
        enriched, _ = enrich_rows(original)
        enriched[0]["Latitude"] = "30.10001"

        with self.assertRaisesRegex(RuntimeError, "Latitude modifiée"):
            validate_transform(original, enriched)


if __name__ == "__main__":
    unittest.main()
