"""Renders App/Assets.xcassets/AppIcon.appiconset/icon-1024.png from the fox art (needs Playwright)."""
import os, subprocess, sys
from art import *

HERE = os.path.dirname(os.path.abspath(__file__))
svg = preview_svg(species("fox"), {"eyes.open", "mouth.happy"}, size=1024)
svg = svg.replace('viewBox="0 0 100 100"', 'viewBox="3 5 92 92"')
html = f"""<!doctype html><html><body style="margin:0">
<div style="width:1024px;height:1024px;position:relative;overflow:hidden;background:linear-gradient(#9ed6ff,#e3f4ff)">
<div style="position:absolute;left:-30%;right:-30%;top:{(88-5)/92*1024 - 18}px;height:700px;border-radius:50%;background:#99d980"></div>
<div style="position:absolute;inset:0">{svg}</div></div></body></html>"""
out_html = os.path.join(HERE, "icon.html")
open(out_html, "w").write(html)
target = os.path.join(HERE, "..", "App", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png")
subprocess.run(["node", os.path.join(HERE, "shot.js"), out_html, target, "1024"], check=True)
os.remove(out_html)
