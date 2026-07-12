import re

with open('lib/pages/tide_page.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip_until = None

for line in lines:
    # 1. Remettre _bg en blanc d'origine
    if 'Color get _bg' in line and '0xFF6B7280' in line:
        line = line.replace('0xFF6B7280', '0xFFF0F4F8')

    # 2. Protéger la définition de _txt (elle contient Colors.white)
    if 'Color _txt(double opacity)' in line:
        skip_until = ';'
        new_lines.append(line)
        continue

    if skip_until is not None:
        new_lines.append(line)
        if line.strip().endswith(skip_until):
            skip_until = None
        continue

    # 3. Protéger le ShaderMask (Colors.white sert de masque, pas de texte)
    if 'ShaderMask(' in line:
        skip_until = 'blendMode: BlendMode.dstIn,'
        new_lines.append(line)
        continue

    if skip_until is not None:
        new_lines.append(line)
        if skip_until in line:
            skip_until = None
        continue

    # 4. Remplacer Colors.white.withOpacity( par _txt(
    line = line.replace('Colors.white.withOpacity(', '_txt(')

    # 5. Remplacer color: Colors.white, par color: _txt(1.0),
    line = line.replace('color: Colors.white,', 'color: _txt(1.0),')

    new_lines.append(line)

with open('lib/pages/tide_page.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print('Done')
