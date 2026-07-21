#!/usr/bin/env python3
"""Compte les spots de l'asset AES-256-CBC avec la clé Release locale."""

from encrypt_spots import ENCRYPTED_PATH, ROOT, _decrypt, _load_key, _validate_csv


def main() -> None:
    key = _load_key(ROOT / ".env")
    records = _validate_csv(_decrypt(ENCRYPTED_PATH.read_bytes(), key))
    print(f"Nombre de spots : {records}")


if __name__ == "__main__":
    main()
