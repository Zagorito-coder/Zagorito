"""
generate_launcher_icon.py
Génère une icône d'application 1024×1024 à partir de assets/logo.png
avec un effet relief / ombre / reflet glossy épuré.
"""
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageEnhance
import math
import os

SIZE = 1024
INNER_PADDING = 80
LOGO_SIZE = 520
SHADOW_BLUR = 40

# Couleurs océan
C_DEEP = (12, 55, 72)
C_MID = (22, 110, 120)
C_LIGHT = (29, 185, 184)

# Fond blanc cassé pour le badge central
C_BADGE = (250, 253, 255)


def radial_gradient(size, c1, c2, c3):
    """Dégradé radial approximatif."""
    img = Image.new('RGBA', size)
    draw = ImageDraw.Draw(img)
    cx, cy = size[0] / 2, size[1] / 2
    max_r = math.hypot(cx, cy)
    for r in range(int(max_r), -1, -12):
        t = r / max_r
        if t < 0.5:
            ratio = t * 2
            c = (
                int(c1[0] + (c2[0] - c1[0]) * ratio),
                int(c1[1] + (c2[1] - c1[1]) * ratio),
                int(c1[2] + (c2[2] - c1[2]) * ratio),
            )
        else:
            ratio = (t - 0.5) * 2
            c = (
                int(c2[0] + (c3[0] - c2[0]) * ratio),
                int(c2[1] + (c3[1] - c2[1]) * ratio),
                int(c2[2] + (c3[2] - c2[2]) * ratio),
            )
        draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            fill=c + (255,),
        )
    return img


def squircle_mask(size, radius_ratio=0.28):
    """Masque squircle via super-ellipse."""
    mask = Image.new('L', size, 0)
    draw = ImageDraw.Draw(mask)
    w, h = size
    n = 4
    rx = w / 2 * radius_ratio
    ry = h / 2 * radius_ratio
    cx, cy = w / 2, h / 2
    points = []
    for angle in range(360, -1, -1):
        rad = math.radians(angle)
        cos_a = math.cos(rad)
        sin_a = math.sin(rad)
        x = rx * math.copysign(abs(cos_a) ** (2 / n), cos_a)
        y = ry * math.copysign(abs(sin_a) ** (2 / n), sin_a)
        points.append((cx + x * (w / 2) / rx, cy + y * (h / 2) / ry))
    draw.polygon(points, fill=255)
    return mask


def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    logo_path = os.path.join(base_dir, 'assets', 'logo.png')
    out_path = os.path.join(base_dir, 'assets', 'launcher_icon.png')

    # Fond océan
    bg = radial_gradient((SIZE, SIZE), C_DEEP, C_MID, C_LIGHT)

    # Ombre portée du badge
    shadow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    shadow_mask = squircle_mask((SIZE - INNER_PADDING * 2, SIZE - INNER_PADDING * 2))
    shadow_mask = shadow_mask.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    shadow.paste((0, 30, 40, 160), (0, 0), shadow_mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))

    # Badge central blanc
    badge_size = SIZE - INNER_PADDING * 2
    badge = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    badge_mask = squircle_mask((badge_size, badge_size))
    badge_mask = badge_mask.resize((badge_size, badge_size), Image.Resampling.LANCZOS)
    badge.paste(C_BADGE + (255,), (INNER_PADDING, INNER_PADDING), badge_mask)

    # Bordure subtile
    border = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    border_mask = squircle_mask((badge_size, badge_size))
    border_mask = border_mask.resize((badge_size, badge_size), Image.Resampling.LANCZOS)
    border_draw = ImageDraw.Draw(border)
    # On trace un anneau fin en blanc très transparent
    for offset in range(2):
        o = offset
        m = border_mask.resize((badge_size - o * 2, badge_size - o * 2), Image.Resampling.LANCZOS)
        border.paste((255, 255, 255, 50 - offset * 25), (INNER_PADDING + o, INNER_PADDING + o), m)

    # Logo
    logo = Image.open(logo_path).convert('RGBA')
    logo = logo.resize((LOGO_SIZE, LOGO_SIZE), Image.Resampling.LANCZOS)
    # Ombre légère du logo
    logo_shadow = Image.new('RGBA', (LOGO_SIZE + 40, LOGO_SIZE + 40), (0, 0, 0, 0))
    logo_shadow.paste(logo, (20, 20), logo)
    logo_shadow = logo_shadow.filter(ImageFilter.GaussianBlur(18))
    logo_shadow = ImageEnhance.Brightness(logo_shadow).enhance(0.4)

    # Reflet glossy
    gloss = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    gloss_mask = squircle_mask((badge_size, badge_size))
    gloss_mask = gloss_mask.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    gloss_draw = ImageDraw.Draw(gloss)
    # Dégradé linéaire haut -> bas sur le haut du badge
    for y in range(INNER_PADDING, INNER_PADDING + badge_size // 2):
        alpha = int(90 * (1 - (y - INNER_PADDING) / (badge_size // 2)))
        gloss_draw.line(
            [(INNER_PADDING, y), (SIZE - INNER_PADDING, y)],
            fill=(255, 255, 255, max(0, min(alpha, 60))),
        )
    gloss.putalpha(ImageChops.multiply(gloss.getchannel('A'), gloss_mask))

    # Assemblage
    icon = bg.copy()
    icon = Image.alpha_composite(icon, shadow)
    icon = Image.alpha_composite(icon, badge)
    icon = Image.alpha_composite(icon, border)

    # Centrer logo et son ombre
    lx = (SIZE - LOGO_SIZE) // 2
    ly = (SIZE - LOGO_SIZE) // 2
    icon.paste(logo_shadow, (lx - 20, ly - 20), logo_shadow)
    icon.paste(logo, (lx, ly), logo)

    icon = Image.alpha_composite(icon, gloss)

    icon.save(out_path)
    print(f'Icône générée : {out_path}')


if __name__ == '__main__':
    main()
