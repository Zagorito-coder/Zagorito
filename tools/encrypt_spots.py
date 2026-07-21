#!/usr/bin/env python3
"""Chiffre et verifie l'asset de spots avec la cle Release locale."""

from __future__ import annotations

import argparse
import base64
import csv
import hashlib
import io
import math
import os
import sys
from pathlib import Path

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes


ROOT = Path(__file__).resolve().parents[1]
PLAIN_PATH = ROOT / "assets" / "spots.csv"
ENCRYPTED_PATH = ROOT / "assets" / "spots.csv.enc"


def _read_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        if line.startswith("export "):
            line = line[7:].lstrip()
        name, value = line.split("=", 1)
        values[name.strip()] = value.strip().strip('"').strip("'")
    return values


def _load_key(env_path: Path) -> bytes:
    encoded = os.environ.get("CSV_ENCRYPTION_KEY")
    if not encoded:
        encoded = _read_env_file(env_path).get("CSV_ENCRYPTION_KEY")
    if not encoded:
        raise RuntimeError(
            "CSV_ENCRYPTION_KEY est absent. Configurez-le dans .env ou dans "
            "l'environnement du build."
        )

    try:
        key = base64.b64decode(encoded, validate=True)
    except ValueError as error:
        raise RuntimeError("CSV_ENCRYPTION_KEY n'est pas un Base64 valide.") from error
    if len(key) != 32:
        raise RuntimeError("CSV_ENCRYPTION_KEY doit decoder exactement 32 octets.")
    return key


def _encrypt(plaintext: bytes, key: bytes) -> bytes:
    iv = os.urandom(16)
    pad_len = 16 - (len(plaintext) % 16)
    padded = plaintext + bytes([pad_len] * pad_len)
    encryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
    return iv + encryptor.update(padded) + encryptor.finalize()


def _decrypt(payload: bytes, key: bytes) -> bytes:
    if len(payload) <= 16 or (len(payload) - 16) % 16 != 0:
        raise RuntimeError("L'asset chiffre a une taille AES-CBC invalide.")

    decryptor = Cipher(algorithms.AES(key), modes.CBC(payload[:16])).decryptor()
    padded = decryptor.update(payload[16:]) + decryptor.finalize()
    pad_len = padded[-1]
    if not 1 <= pad_len <= 16 or padded[-pad_len:] != bytes([pad_len] * pad_len):
        raise RuntimeError("La cle Release ne correspond pas a l'asset chiffre.")
    return padded[:-pad_len]


def _validate_csv(content: bytes) -> int:
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError as error:
        raise RuntimeError("Le catalogue dechiffre n'est pas en UTF-8.") from error

    rows = list(csv.reader(io.StringIO(text)))
    if not rows or rows[0][:3] != ["Nom", "Latitude", "Longitude"]:
        raise RuntimeError("L'en-tete CSV du catalogue est invalide.")
    if len(rows) <= 1:
        raise RuntimeError("Le catalogue ne contient aucun spot.")

    for line_number, row in enumerate(rows[1:], start=2):
        if len(row) < 3 or not row[0].strip():
            raise RuntimeError(f"Spot invalide a la ligne {line_number}.")
        try:
            latitude = float(row[1])
            longitude = float(row[2])
        except ValueError as error:
            raise RuntimeError(
                f"Coordonnees invalides a la ligne {line_number}."
            ) from error
        if (
            not math.isfinite(latitude)
            or not math.isfinite(longitude)
            or not -90 <= latitude <= 90
            or not -180 <= longitude <= 180
        ):
            raise RuntimeError(
                f"Coordonnees hors limites a la ligne {line_number}."
            )
    return len(rows) - 1


def _check(key: bytes) -> None:
    if not ENCRYPTED_PATH.exists():
        raise RuntimeError(f"Asset introuvable: {ENCRYPTED_PATH}")

    encrypted = ENCRYPTED_PATH.read_bytes()
    plaintext = _decrypt(encrypted, key)
    records = _validate_csv(plaintext)

    if PLAIN_PATH.exists() and plaintext != PLAIN_PATH.read_bytes():
        raise RuntimeError(
            "L'asset chiffre ne correspond pas a assets/spots.csv. "
            "Relancez tools/encrypt_spots.py avant le build."
        )

    fingerprint = hashlib.sha256(encrypted).hexdigest()[:12]
    print(f"OK: {records} spots, asset SHA-256 {fingerprint}...")


def _write_encrypted_asset(key: bytes) -> None:
    if not PLAIN_PATH.exists():
        raise RuntimeError(f"Source CSV introuvable: {PLAIN_PATH}")

    plaintext = PLAIN_PATH.read_bytes()
    records = _validate_csv(plaintext)
    encrypted = _encrypt(plaintext, key)
    if _decrypt(encrypted, key) != plaintext:
        raise RuntimeError("La verification apres chiffrement a echoue.")

    temporary = ENCRYPTED_PATH.with_suffix(ENCRYPTED_PATH.suffix + ".tmp")
    temporary.write_bytes(encrypted)
    temporary.replace(ENCRYPTED_PATH)

    fingerprint = hashlib.sha256(encrypted).hexdigest()[:12]
    print(f"Asset genere: {records} spots, SHA-256 {fingerprint}...")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="Verifie la cle, le dechiffrement et la coherence avec le CSV local.",
    )
    parser.add_argument(
        "--env-file",
        type=Path,
        default=ROOT / ".env",
        help="Fichier .env contenant CSV_ENCRYPTION_KEY.",
    )
    args = parser.parse_args()

    key = _load_key(args.env_file.expanduser().resolve())
    if args.check:
        _check(key)
    else:
        _write_encrypted_asset(key)


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as error:
        print(f"ERREUR: {error}", file=sys.stderr)
        raise SystemExit(1) from None
