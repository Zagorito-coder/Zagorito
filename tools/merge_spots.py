#!/usr/bin/env python3
"""
merge_spots.py — Merge un nouveau CSV de spots dans spots.csv.enc
=================================================================
- Dechiffre le fichier AES-256-CBC existant
- Lit un nouveau CSV
- Detection automatique du format (ancien/nouveau)
- Normalisation vers format unifie: Nom,Latitude,Longitude,Poissons,Notes
- Deduplication par (nom + lat/lon arrondis a 5 decimales)
- Rechiffre et ecrase spots.csv.enc
- Backup automatique

Usage:
  python3 tools/merge_spots.py <nouveau_fichier.csv>
"""

import csv
import io
import os
import shutil
import sys
from datetime import datetime
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from encrypt_spots import ROOT, _load_key

KEY = _load_key(ROOT / '.env')
ENC_PATH = 'assets/spots.csv.enc'
OUTPUT_HEADER = ['Nom', 'Latitude', 'Longitude', 'Poissons', 'Notes']
ROUND_DECIMALS = 5


# ── AES-256-CBC ───────────────────────────────────────────────
def decrypt(path: str) -> str:
    with open(path, 'rb') as f:
        data = f.read()
    iv, ct = data[:16], data[16:]
    cipher = Cipher(algorithms.AES(KEY), modes.CBC(iv))
    dec = cipher.decryptor()
    pt = dec.update(ct) + dec.finalize()
    pad = pt[-1]
    return pt[:-pad].decode('utf-8')


def encrypt(csv_text: str) -> bytes:
    iv = os.urandom(16)
    data = csv_text.encode('utf-8')
    pad_len = 16 - (len(data) % 16)
    data += bytes([pad_len] * pad_len)
    cipher = Cipher(algorithms.AES(KEY), modes.CBC(iv))
    enc = cipher.encryptor()
    return iv + enc.update(data) + enc.finalize()


# ── Detection de format ───────────────────────────────────────
# Ancien format: Spot,Latitude,Longtitude,Infos,Commentaires
# Nouveau format: Nom,Latitude,Longitude,Poissons,Notes
# Les deux ont les memes colonnes dans le meme ordre, seuls les headers changent.

OLD_HEADERS = {'Spot', 'Latitude', 'Longtitude', 'Infos', 'Commentaires'}
NEW_HEADERS = {'Nom', 'Latitude', 'Longitude', 'Poissons', 'Notes'}


def detect_and_parse(csv_text: str, label: str) -> list[dict]:
    """Detecte le format et parse en rows normalisees."""
    reader = csv.DictReader(io.StringIO(csv_text))
    columns = set(reader.fieldnames or [])

    if columns >= OLD_HEADERS:
        fmt = 'ANCIEN'
        name_col, lat_col, lon_col, fish_col, note_col = (
            'Spot', 'Latitude', 'Longtitude', 'Infos', 'Commentaires'
        )
    elif columns >= NEW_HEADERS:
        fmt = 'NOUVEAU'
        name_col, lat_col, lon_col, fish_col, note_col = (
            'Nom', 'Latitude', 'Longitude', 'Poissons', 'Notes'
        )
    else:
        # Fallback: parser par position (ignore les headers)
        print(f"  [{label}] Format inconnu, fallback par position (cols={columns})")
        return parse_by_position(csv_text, label)

    rows = []
    for r in reader:
        try:
            nom = r.get(name_col, '').strip()
            lat = r[lat_col].strip()
            lon = r[lon_col].strip()
            poissons = r.get(fish_col, '').strip()
            notes = r.get(note_col, '').strip()

            float(lat)
            float(lon)

            if nom:
                rows.append({
                    'Nom': nom,
                    'Latitude': lat,
                    'Longitude': lon,
                    'Poissons': poissons,
                    'Notes': notes,
                })
        except (ValueError, KeyError):
            pass  # skip silently

    print(f"  [{label}] {len(rows)} spots valides (format {fmt})")
    return rows


def parse_by_position(csv_text: str, label: str) -> list[dict]:
    """Fallback: parse les colonnes par position (0=nom,1=lat,2=lon,3=poissons,4=notes)."""
    lines = csv_text.strip().split('\n')
    if not lines:
        return []
    # Skip header
    rows = []
    for i, line in enumerate(lines[1:], start=2):
        parts = line.split(',')
        if len(parts) < 3:
            continue
        try:
            nom = parts[0].strip()
            lat = float(parts[1].strip())
            lon = float(parts[2].strip())
            poissons = parts[3].strip() if len(parts) > 3 else ''
            notes = parts[4].strip() if len(parts) > 4 else ''
            if nom:
                rows.append({
                    'Nom': nom,
                    'Latitude': str(lat),
                    'Longitude': str(lon),
                    'Poissons': poissons,
                    'Notes': notes,
                })
        except (ValueError, IndexError):
            pass
    print(f"  [{label}] {len(rows)} spots valides (format POSITION)")
    return rows


def make_key(row: dict) -> tuple:
    name = row['Nom'].strip().lower()
    lat = round(float(row['Latitude']), ROUND_DECIMALS)
    lon = round(float(row['Longitude']), ROUND_DECIMALS)
    return (name, lat, lon)


def rows_to_csv(rows: list[dict]) -> str:
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=OUTPUT_HEADER)
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue()


# ── Main ──────────────────────────────────────────────────────
def main():
    if len(sys.argv) < 2:
        print("Usage: python3 tools/merge_spots.py <nouveau_fichier.csv>")
        sys.exit(1)

    new_csv_path = sys.argv[1]
    if not os.path.exists(new_csv_path):
        print(f"ERREUR: fichier introuvable: {new_csv_path}")
        sys.exit(1)
    if not os.path.exists(ENC_PATH):
        print(f"ERREUR: fichier encrypte introuvable: {ENC_PATH}")
        sys.exit(1)

    print("=" * 60)
    print("  MERGE SPOTS — Mise a jour de spots.csv.enc")
    print("=" * 60)

    # 1. Dechiffrer + parser l'existant
    print(f"\n[1/5] Dechiffrement de {ENC_PATH}...")
    existing_csv = decrypt(ENC_PATH)
    existing = detect_and_parse(existing_csv, "EXISTANT")
    print(f"       -> {len(existing)} spots conserves")

    # 2. Lire + parser le nouveau
    print(f"\n[2/5] Lecture du nouveau fichier: {new_csv_path}")
    with open(new_csv_path, 'r', encoding='utf-8') as f:
        new_raw = f.read()
    new = detect_and_parse(new_raw, "NOUVEAU")
    print(f"       -> {len(new)} spots dans le nouveau fichier")

    # 3. Deduplication
    print(f"\n[3/5] Deduplication (nom + coords a {ROUND_DECIMALS} decimales)...")
    seen = set()
    unique = []
    for row in existing:
        k = make_key(row)
        if k not in seen:
            seen.add(k)
            unique.append(row)

    dupes_in_existing = len(existing) - len(unique)
    print(f"       -> {dupes_in_existing} doublons internes supprimes")
    print(f"       -> {len(unique)} spots uniques conserves")

    added = 0
    skipped = 0
    for row in new:
        k = make_key(row)
        if k not in seen:
            seen.add(k)
            unique.append(row)
            added += 1
        else:
            skipped += 1

    print(f"       -> {added} nouveaux spots ajoutes")
    print(f"       -> {skipped} doublons ignores")

    # 4. Backup
    print(f"\n[4/5] Backup de l'ancien fichier...")
    backup_path = f"{ENC_PATH}.bak_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    shutil.copy2(ENC_PATH, backup_path)
    print(f"       -> Backup: {backup_path}")

    # 5. Rechiffrer
    print(f"\n[5/5] Chiffrement du nouveau fichier...")
    merged_csv = rows_to_csv(unique)
    encrypted = encrypt(merged_csv)
    with open(ENC_PATH, 'wb') as f:
        f.write(encrypted)
    print(f"       -> {ENC_PATH} mis a jour ({len(encrypted)} bytes)")

    # Resume
    print("\n" + "=" * 60)
    print("  RESUME")
    print("=" * 60)
    print(f"  Spots avant merge:      {len(existing)}")
    print(f"  Nouveaux spots fournis: {len(new)}")
    print(f"  Doublons ignores:       {skipped}")
    print(f"  Doublons internes:      {dupes_in_existing}")
    print(f"  Total final:            {len(unique)} spots")
    print(f"  Backup:                 {backup_path}")
    print("\n  N'oublie pas de vider le cache de l'app (spots_cache_v4.json).")
    print("=" * 60)


if __name__ == '__main__':
    main()
