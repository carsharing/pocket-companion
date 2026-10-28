import sys
from art import *

def page(cards, out):
    html = ('<!doctype html><html><head><meta charset="utf-8"><style>body{margin:0;padding:20px;background:#b9e3df;'
            'font-family:system-ui;display:flex;flex-wrap:wrap;gap:16px} .c{background:#c8ece8;border-radius:20px;text-align:center;padding:6px}'
            '.t{font-weight:700;margin-bottom:6px}</style></head><body>' + "".join(
            f'<div class="c">{svg}<div class="t">{t}</div></div>' for t, svg in cards) + '</body></html>')
    open(out, "w").write(html)

if __name__ == "__main__":
    f = fox()
    cards = [
        ("content", preview_svg(f, {"eyes.open", "mouth.smile"})),
        ("happy", preview_svg(f, {"eyes.happy", "mouth.happy"})),
        ("open+happy mouth", preview_svg(f, {"eyes.open", "mouth.happy"})),
        ("sad", preview_svg(f, {"eyes.open", "mouth.frown", "brows.sad"})),
        ("asleep", preview_svg(f, {"eyes.closed", "mouth.sleep"})),
    ]
    page(cards, sys.argv[1])
