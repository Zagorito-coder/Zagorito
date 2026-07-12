import base64
import csv
import io
import math
import sys
from collections import Counter
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

sys.stdout.reconfigure(encoding='utf-8')

KEY_B64 = 'q/F+3pnu668/hPnjF96uTqZH+7E24ppnH+53+rwdya0='

def decrypt_csv(path: str) -> str:
    key = base64.b64decode(KEY_B64)
    with open(path, 'rb') as f:
        data = f.read()
    iv, ct = data[:16], data[16:]
    dec = Cipher(algorithms.AES(key), modes.CBC(iv)).decryptor()
    pt = dec.update(ct) + dec.finalize()
    pad = pt[-1]
    return pt[:-pad].decode('utf-8')

def parse_csv(csv_text: str):
    reader = csv.DictReader(io.StringIO(csv_text))
    rows = []
    for r in reader:
        try:
            lat = float(r['Latitude'])
            lon = float(r['Longtitude'])
            rows.append((lat, lon, r.get('Pays', ''), r.get('Ville', '')))
        except Exception:
            continue
    return rows

def estimate_tiles(rows, radius_km: float, max_zoom: int):
    # bounding boxes autour de chaque spot avec rayon
    tile_set = set()
    for lat, lon, _, _ in rows:
        # deg = km / 111 km/deg approx
        dlat = radius_km / 111.0
        dlon = radius_km / (111.0 * math.cos(math.radians(lat)) + 1e-9)
        for lati in [lat - dlat, lat + dlat]:
            for loni in [lon - dlon, lon + dlon]:
                for z in range(1, max_zoom + 1):
                    tile_set.add((z, *latlon_to_tile(lati, loni, z)))
    return tile_set

def latlon_to_tile(lat, lon, zoom):
    lat_rad = math.radians(lat)
    n = 2 ** zoom
    x = int((lon + 180.0) / 360.0 * n)
    y = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
    return x, y

def bbox(rows):
    lats = [r[0] for r in rows]
    lons = [r[1] for r in rows]
    return min(lats), min(lons), max(lats), max(lons)

def grid_counts(rows, cell_deg=2.0):
    cells = Counter()
    for lat, lon, _, _ in rows:
        cells[(int(lat/cell_deg), int(lon/cell_deg))] += 1
    return cells

def main():
    csv_text = decrypt_csv('assets/spots.csv.enc')
    rows = parse_csv(csv_text)
    print(f'Total spots avec coords: {len(rows)}')

    bb = bbox(rows)
    print(f'BBOX globale: lat {bb[0]:.3f}..{bb[2]:.3f}, lon {bb[1]:.3f}..{bb[3]:.3f}')

    cells = grid_counts(rows, cell_deg=2.0)
    print(f'Cellules 2°x2° avec spots: {len(cells)}')
    for (cx, cy), n in cells.most_common(15):
        lat, lon = cx*2.0, cy*2.0
        print(f'  cellule centre ~{lat:.0f},{lon:.0f}: {n} spots')

    for r in [2, 5, 10]:
        for z in [14, 15, 16]:
            tiles = estimate_tiles(rows, r, z)
            size_png = len(tiles) * 45 / 1024 / 1024
            size_jpg = len(tiles) * 18 / 1024 / 1024
            size_pbf = len(tiles) * 6 / 1024 / 1024
            print(f'rayon {r}km zoom {z}: {len(tiles)} tuiles | PNG ~{size_png:.1f} Mo | JPEG ~{size_jpg:.1f} Mo | Vector ~{size_pbf:.1f} Mo')

if __name__ == '__main__':
    main()