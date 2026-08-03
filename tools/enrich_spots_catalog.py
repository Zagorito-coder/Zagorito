#!/usr/bin/env python3
"""Complète le catalogue de spots sans modifier ses données de référence.

Les noms propres sont translittérés localement : aucun service externe n'est
appelé. Les coordonnées, l'ordre des lignes et les champs déjà renseignés sont
considérés comme immuables et sont vérifiés avant toute écriture.
"""

from __future__ import annotations

import argparse
import csv
import re
import tempfile
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG = ROOT / "assets" / "spots.csv"
EXPECTED_HEADERS = ["Nom", "Latitude", "Longitude", "Poissons", "Notes"]

DEFAULT_FISH = "Sar|Loup-bar|Congre"
DEFAULT_NOTE = (
    "Prudence : vérifiez la route et l’accès ; attention aux rochers, "
    "falaises et fortes vagues. | تنبيه: تحقق من الطريق والولوج، واحذر "
    "الصخور والمنحدرات والأمواج القوية."
)

ARABIC_RE = re.compile(
    r"[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]"
)
ARABIC_TOKEN_RE = re.compile(
    r"[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]+"
)
LATIN_RE = re.compile(r"[A-Za-z\u00c0-\u024f]")
LATIN_TOKEN_RE = re.compile(r"[A-Za-z\u00c0-\u024f]+")


ARABIC_WORDS_TO_FRENCH = {
    "شاطئ": "Plage",
    "الشاطئ": "La Plage",
    "رأس": "Cap",
    "راس": "Cap",
    "الرأس": "Le Cap",
    "الراس": "Le Cap",
    "ميناء": "Port",
    "الميناء": "Le Port",
    "مرسى": "Port",
    "المرسى": "Le Port",
    "منارة": "Phare",
    "المنارة": "Le Phare",
    "جزيرة": "Île",
    "الجزيرة": "L’Île",
    "صخرة": "Rocher",
    "الصخرة": "Le Rocher",
    "صخور": "Rochers",
    "الصخور": "Les Rochers",
    "واد": "Oued",
    "الوادي": "L’Oued",
    "الواد": "L’Oued",
    "مصب": "Embouchure",
    "المصب": "L’Embouchure",
    "خليج": "Baie",
    "الخليج": "La Baie",
    "جرف": "Falaise",
    "الجرف": "La Falaise",
    "بحيرة": "Lac",
    "البحيرة": "Le Lac",
    "كهف": "Grotte",
    "الكهف": "La Grotte",
    "جسر": "Pont",
    "الجسر": "Le Pont",
    "قنطرة": "Pont",
    "القنطرة": "Le Pont",
    "نهر": "Rivière",
    "النهر": "La Rivière",
    "سيدي": "Sidi",
    "سيدهم": "Sidi",
    "بن": "Ben",
    "بنت": "Bent",
    "مولاي": "Moulay",
    "قصر": "Ksar",
    "الصغير": "Sghir",
    "الكبير": "Kbir",
    "عين": "Aïn",
    "سوق": "Souk",
    "باب": "Bab",
    "جبل": "Jbel",
    "القرية": "Le Village",
    "قرية": "Village",
}

FRENCH_WORDS_TO_ARABIC = {
    "plage": "شاطئ",
    "plages": "شواطئ",
    "beach": "شاطئ",
    "beaches": "شواطئ",
    "port": "ميناء",
    "ports": "موانئ",
    "harbor": "ميناء",
    "harbour": "ميناء",
    "cap": "رأس",
    "cape": "رأس",
    "pointe": "رأس",
    "point": "رأس",
    "rocher": "صخرة",
    "roché": "صخرة",
    "roche": "صخرة",
    "rochers": "صخور",
    "roches": "صخور",
    "rock": "صخرة",
    "rocks": "صخور",
    "phare": "منارة",
    "lighthouse": "منارة",
    "île": "جزيرة",
    "ile": "جزيرة",
    "island": "جزيرة",
    "îles": "جزر",
    "iles": "جزر",
    "islands": "جزر",
    "baie": "خليج",
    "bay": "خليج",
    "anse": "خليج صغير",
    "falaise": "جرف",
    "falaises": "منحدرات",
    "cliff": "جرف",
    "cliffs": "منحدرات",
    "digue": "حاجز بحري",
    "jetée": "رصيف بحري",
    "jetee": "رصيف بحري",
    "marina": "مارينا",
    "lac": "بحيرة",
    "lake": "بحيرة",
    "embouchure": "مصب",
    "estuary": "مصب",
    "station": "محطة",
    "club": "نادي",
    "grotte": "كهف",
    "cave": "كهف",
    "pont": "جسر",
    "bridge": "جسر",
    "rivière": "نهر",
    "riviere": "نهر",
    "river": "نهر",
    "reef": "شعاب",
    "sidi": "سيدي",
    "moulay": "مولاي",
    "ksar": "قصر",
    "souk": "سوق",
    "jbel": "جبل",
    "ain": "عين",
    "oued": "واد",
    "wad": "واد",
    "foum": "فم",
    "ras": "رأس",
    "sghir": "الصغير",
}

ARABIC_CHAR_TO_LATIN = {
    "ا": "a",
    "أ": "a",
    "إ": "i",
    "آ": "a",
    "ٱ": "a",
    "ب": "b",
    "پ": "p",
    "ت": "t",
    "ث": "th",
    "ج": "j",
    "چ": "ch",
    "ح": "h",
    "خ": "kh",
    "د": "d",
    "ذ": "dh",
    "ر": "r",
    "ز": "z",
    "ژ": "j",
    "س": "s",
    "ش": "ch",
    "ص": "s",
    "ض": "d",
    "ط": "t",
    "ظ": "dh",
    "ع": "a",
    "غ": "gh",
    "ف": "f",
    "ڤ": "v",
    "ق": "q",
    "ڨ": "g",
    "ك": "k",
    "ک": "k",
    "گ": "g",
    "ڭ": "g",
    "ل": "l",
    "م": "m",
    "ن": "n",
    "ه": "h",
    "ة": "a",
    "و": "ou",
    "ؤ": "ou",
    "ۆ": "o",
    "ي": "i",
    "ی": "i",
    "ى": "a",
    "ئ": "i",
    "ء": "’",
    "ﻻ": "la",
    "َ": "",
    "ً": "",
    "ُ": "",
    "ٌ": "",
    "ِ": "",
    "ٍ": "",
    "ْ": "",
    "ّ": "",
    "ـ": "",
}

LATIN_SEQUENCES_TO_ARABIC = {
    "tion": "سيون",
    "eau": "و",
    "tch": "تش",
    "sch": "ش",
    "ch": "ش",
    "sh": "ش",
    "kh": "خ",
    "gh": "غ",
    "ph": "ف",
    "th": "ث",
    "dh": "ذ",
    "dj": "ج",
    "gn": "ني",
    "qu": "ك",
    "ck": "ك",
    "ou": "و",
    "oo": "و",
    "ee": "ي",
    "ai": "اي",
    "ay": "اي",
    "ei": "اي",
    "au": "و",
    "oi": "وا",
}

LATIN_CHAR_TO_ARABIC = {
    "a": "ا",
    "b": "ب",
    "c": "ك",
    "d": "د",
    "e": "ي",
    "f": "ف",
    "g": "گ",
    "h": "ه",
    "i": "ي",
    "j": "ج",
    "k": "ك",
    "l": "ل",
    "m": "م",
    "n": "ن",
    "o": "و",
    "p": "ب",
    "q": "ق",
    "r": "ر",
    "s": "س",
    "t": "ت",
    "u": "و",
    "v": "ف",
    "w": "و",
    "x": "كس",
    "y": "ي",
    "z": "ز",
}


@dataclass(frozen=True)
class EnrichmentReport:
    total: int
    names_from_arabic: int
    names_from_latin: int
    names_already_bilingual: int
    fish_completed: int
    notes_completed: int


def has_arabic(value: str) -> bool:
    return any(
        unicodedata.category(char).startswith("L")
        and "ARABIC" in unicodedata.name(char, "")
        for char in value
    )


def has_latin(value: str) -> bool:
    return any(
        unicodedata.category(char).startswith("L")
        and "LATIN" in unicodedata.name(char, "")
        for char in value
    )


def _normalized_latin(value: str) -> str:
    value = value.replace("ı", "i").replace("İ", "I")
    return "".join(
        char
        for char in unicodedata.normalize("NFKD", value)
        if not unicodedata.combining(char)
    ).lower()


def _arabic_token_to_latin(
    token: str, learned_words: dict[str, str] | None = None
) -> str:
    translated = ARABIC_WORDS_TO_FRENCH.get(token)
    if translated is not None:
        return translated
    if learned_words is not None and token in learned_words:
        return learned_words[token]
    return "".join(ARABIC_CHAR_TO_LATIN.get(char, char) for char in token)


def arabic_to_latin(
    value: str, learned_words: dict[str, str] | None = None
) -> str:
    transliterated = ARABIC_TOKEN_RE.sub(
        lambda match: _arabic_token_to_latin(match.group(0), learned_words),
        value,
    )
    transliterated = re.sub(r"\s+", " ", transliterated).strip(" -")
    return transliterated.title()


def _latin_token_to_arabic(
    token: str, learned_words: dict[str, str] | None = None
) -> str:
    normalized = _normalized_latin(token)
    translated = FRENCH_WORDS_TO_ARABIC.get(normalized)
    if translated is not None:
        return translated
    if learned_words is not None and normalized in learned_words:
        return learned_words[normalized]

    output: list[str] = []
    index = 0
    sequences = sorted(LATIN_SEQUENCES_TO_ARABIC, key=len, reverse=True)
    while index < len(normalized):
        sequence = next(
            (item for item in sequences if normalized.startswith(item, index)),
            None,
        )
        if sequence is not None:
            output.append(LATIN_SEQUENCES_TO_ARABIC[sequence])
            index += len(sequence)
            continue

        char = normalized[index]
        if char == "c" and index + 1 < len(normalized):
            output.append("س" if normalized[index + 1] in "eiy" else "ك")
        elif char == "g" and index + 1 < len(normalized):
            output.append("ج" if normalized[index + 1] in "eiy" else "گ")
        else:
            output.append(LATIN_CHAR_TO_ARABIC.get(char, char))
        index += 1
    return "".join(output)


def latin_to_arabic(
    value: str, learned_words: dict[str, str] | None = None
) -> str:
    transliterated = LATIN_TOKEN_RE.sub(
        lambda match: _latin_token_to_arabic(match.group(0), learned_words),
        value,
    )
    return re.sub(r"\s+", " ", transliterated).strip(" -")


def _bilingual_sides(value: str) -> tuple[str, str] | None:
    """Retourne (arabe, latin) quand un séparateur isole clairement les côtés."""
    for match in re.finditer(r"[-–—]", value):
        left = value[: match.start()].strip()
        right = value[match.end() :].strip()
        if not left or not right:
            continue
        left_arabic, left_latin = has_arabic(left), has_latin(left)
        right_arabic, right_latin = has_arabic(right), has_latin(right)
        if left_arabic and not left_latin and right_latin and not right_arabic:
            return left, right
        if left_latin and not left_arabic and right_arabic and not right_latin:
            return right, left
    return None


def build_learned_lexicons(
    rows: list[dict[str, str]],
) -> tuple[dict[str, str], dict[str, str]]:
    """Réutilise les équivalences déjà présentes dans le catalogue.

    Seules les paires dont le nombre de mots correspond exactement sont
    apprises, ce qui évite les alignements approximatifs.
    """
    arabic_candidates: dict[str, Counter[str]] = defaultdict(Counter)
    latin_candidates: dict[str, Counter[str]] = defaultdict(Counter)

    for row in rows:
        sides = _bilingual_sides(row["Nom"])
        if sides is None:
            continue
        arabic_side, latin_side = sides
        arabic_tokens = ARABIC_TOKEN_RE.findall(arabic_side)
        latin_tokens = LATIN_TOKEN_RE.findall(latin_side)
        if not arabic_tokens or len(arabic_tokens) != len(latin_tokens):
            continue
        for arabic_token, latin_token in zip(arabic_tokens, latin_tokens):
            arabic_candidates[arabic_token][latin_token] += 1
            latin_candidates[_normalized_latin(latin_token)][arabic_token] += 1

    arabic_to_french: dict[str, str] = {}
    for token, candidates in arabic_candidates.items():
        candidate, occurrences = candidates.most_common(1)[0]
        total = sum(candidates.values())
        latin_letters = "".join(char for char in candidate if has_latin(char))
        if total >= 2 and occurrences / total >= 0.75 and len(latin_letters) >= 3:
            arabic_to_french[token] = candidate

    latin_to_arabic_words: dict[str, str] = {}
    for token, candidates in latin_candidates.items():
        candidate, occurrences = candidates.most_common(1)[0]
        total = sum(candidates.values())
        if total >= 2 and occurrences / total >= 0.75 and len(token) >= 3:
            latin_to_arabic_words[token] = candidate
    return arabic_to_french, latin_to_arabic_words


def read_catalog(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as source:
        reader = csv.DictReader(source)
        if reader.fieldnames != EXPECTED_HEADERS:
            raise RuntimeError(
                f"En-tête invalide: {reader.fieldnames!r}; attendu: {EXPECTED_HEADERS!r}."
            )
        rows = list(reader)

    for line_number, row in enumerate(rows, start=2):
        if None in row or set(row) != set(EXPECTED_HEADERS):
            raise RuntimeError(f"Colonnes CSV invalides à la ligne {line_number}.")
        if not row["Nom"].strip():
            raise RuntimeError(f"Nom vide à la ligne {line_number}.")
        try:
            latitude = float(row["Latitude"])
            longitude = float(row["Longitude"])
        except ValueError as error:
            raise RuntimeError(
                f"Coordonnées invalides à la ligne {line_number}."
            ) from error
        if not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
            raise RuntimeError(f"Coordonnées hors limites à la ligne {line_number}.")
    return rows


def enrich_rows(
    rows: list[dict[str, str]],
) -> tuple[list[dict[str, str]], EnrichmentReport]:
    enriched: list[dict[str, str]] = []
    names_from_arabic = 0
    names_from_latin = 0
    names_already_bilingual = 0
    fish_completed = 0
    notes_completed = 0
    learned_arabic, learned_latin = build_learned_lexicons(rows)

    for line_number, original in enumerate(rows, start=2):
        row = dict(original)
        name = original["Nom"]
        arabic = has_arabic(name)
        latin = has_latin(name)

        if arabic and latin:
            names_already_bilingual += 1
        elif arabic:
            translated = arabic_to_latin(name, learned_arabic)
            if not translated or not has_latin(translated):
                raise RuntimeError(
                    f"Translittération française impossible à la ligne {line_number}."
                )
            row["Nom"] = f"{name} - {translated}"
            names_from_arabic += 1
        elif latin:
            translated = latin_to_arabic(name, learned_latin)
            if not translated or not has_arabic(translated):
                raise RuntimeError(
                    f"Translittération arabe impossible à la ligne {line_number}."
                )
            row["Nom"] = f"{translated} - {name}"
            names_from_latin += 1
        else:
            raise RuntimeError(
                f"Nom sans caractères arabes ou latins à la ligne {line_number}."
            )

        if not original["Poissons"].strip():
            row["Poissons"] = DEFAULT_FISH
            fish_completed += 1
        if not original["Notes"].strip():
            row["Notes"] = DEFAULT_NOTE
            notes_completed += 1
        enriched.append(row)

    report = EnrichmentReport(
        total=len(rows),
        names_from_arabic=names_from_arabic,
        names_from_latin=names_from_latin,
        names_already_bilingual=names_already_bilingual,
        fish_completed=fish_completed,
        notes_completed=notes_completed,
    )
    validate_transform(rows, enriched)
    return enriched, report


def validate_transform(
    original_rows: list[dict[str, str]],
    enriched_rows: list[dict[str, str]],
) -> None:
    if len(original_rows) != len(enriched_rows):
        raise RuntimeError("Le nombre ou l’ordre des spots a changé.")

    for line_number, (original, enriched) in enumerate(
        zip(original_rows, enriched_rows), start=2
    ):
        for coordinate in ("Latitude", "Longitude"):
            if original[coordinate] != enriched[coordinate]:
                raise RuntimeError(
                    f"{coordinate} modifiée à la ligne {line_number}."
                )

        original_name = original["Nom"]
        if has_arabic(original_name) and has_latin(original_name):
            if enriched["Nom"] != original_name:
                raise RuntimeError(
                    f"Nom bilingue existant modifié à la ligne {line_number}."
                )
        elif original_name not in enriched["Nom"]:
            raise RuntimeError(
                f"Nom original perdu à la ligne {line_number}."
            )

        if not has_arabic(enriched["Nom"]) or not has_latin(enriched["Nom"]):
            raise RuntimeError(f"Nom non bilingue à la ligne {line_number}.")

        for field in ("Poissons", "Notes"):
            if original[field].strip() and enriched[field] != original[field]:
                raise RuntimeError(
                    f"Champ {field} existant modifié à la ligne {line_number}."
                )
            if not enriched[field].strip():
                raise RuntimeError(
                    f"Champ {field} encore vide à la ligne {line_number}."
                )


def write_catalog(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        newline="",
        prefix=f"{path.name}.",
        suffix=".tmp",
        dir=path.parent,
        delete=False,
    ) as temporary:
        writer = csv.DictWriter(
            temporary,
            fieldnames=EXPECTED_HEADERS,
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)
        temporary_path = Path(temporary.name)

    temporary_path.replace(path)


def print_report(report: EnrichmentReport, *, wrote: bool) -> None:
    mode = "écrit" if wrote else "simulation"
    print(f"Catalogue {mode}: {report.total} spots")
    print(f"  noms arabes complétés en français: {report.names_from_arabic}")
    print(f"  noms latins complétés en arabe: {report.names_from_latin}")
    print(f"  noms bilingues conservés: {report.names_already_bilingual}")
    print(f"  champs Poissons complétés: {report.fish_completed}")
    print(f"  champs Notes complétés: {report.notes_completed}")
    print("  coordonnées et valeurs existantes: inchangées")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument(
        "--write",
        action="store_true",
        help="Écrit le résultat après validation complète; sinon simule seulement.",
    )
    args = parser.parse_args()

    catalog = args.catalog.expanduser().resolve()
    original_rows = read_catalog(catalog)
    enriched_rows, report = enrich_rows(original_rows)
    if args.write:
        write_catalog(catalog, enriched_rows)
        persisted_rows = read_catalog(catalog)
        validate_transform(original_rows, persisted_rows)
    print_report(report, wrote=args.write)


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as error:
        print(f"ERREUR: {error}")
        raise SystemExit(1) from None
