"""Reproducible source inventory; never presents source scanning as visual review."""
import json
import re
from pathlib import Path
from PIL import Image

rows = []
for folder in ('lib/screens', 'lib/widgets', 'lib/theme'):
    for path in sorted(Path(folder).rglob('*.dart')):
        source = path.read_text()
        rows.append({'path': str(path), 'lines': len(source.splitlines()),
                     'classes': re.findall(r'class (\w+)', source),
                     'literal_colors': len(re.findall(r'Color\(0x', source)),
                     'visual_review': 'NOT VERIFIED'})
assets = []
for path in sorted(Path('assets').rglob('*')):
    if path.suffix.lower() in ('.png', '.jpeg', '.webp'):
        try:
            with Image.open(path) as im:
                im.load()
                assets.append({'path': str(path), 'size': im.size, 'decode': 'PASS'})
        except Exception as exc:
            assets.append({'path': str(path), 'decode': 'FAIL', 'error': str(exc)})
Path('docs/ui_evidence/source_inventory.json').write_text(
    json.dumps({'files': rows, 'images': assets}, ensure_ascii=False, indent=2)+'\n')
print(f'{len(rows)} source files; {sum(r["literal_colors"] for r in rows)} literal color occurrences')
