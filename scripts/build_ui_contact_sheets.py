"""Build review sheets from actual Flutter tester captures (requires Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw

for theme in ['blue_day', 'blue_night', 'pink_day', 'pink_night']:
    files = (sorted(Path('test/ui_audit/goldens/catalog').glob(f'*_{theme}_390_1.0.png'))
             + sorted(Path('test/ui_audit/goldens/roles').glob(f'*_{theme}_390_1.0_*.png')))
    sheet = Image.new('RGB', (1320, ((len(files)+5)//6)*490), '#eee')
    draw = ImageDraw.Draw(sheet)
    for index, path in enumerate(files):
        with Image.open(path) as source:
            frame = source.convert('RGB')
            frame.thumbnail((210, 460))
            x, y = (index % 6)*220, (index//6)*490
            draw.text((x, y+3), path.stem.replace('_'+theme+'_390_1.0', ''), fill='black')
            sheet.paste(frame, (x, y+25))
    sheet.save(f'docs/ui_evidence/phase2-{theme}-screens.png')
