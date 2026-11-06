"""Draws logo mockups for Kai around ϗ (the kai compendium, U+03D7), from
EB Garamond's outline, as SVG files, plus a page that shows them."""
import ast, math, os

GOLD = "#e8c872"
OUT = "out"
os.makedirs(OUT, exist_ok=True)

glyph = {w: ast.literal_eval(open(f"kai-{w}.json").read()) for w in ("400", "600")}


def kai(cx, cy, height, weight="600", fill=GOLD):
    """ϗ centred at (cx, cy), `height` tall (font units have y up)."""
    g = glyph[weight]
    xmin, ymin, xmax, ymax = g["bounds"]
    s = height / (ymax - ymin)
    tx = cx - (xmin + xmax) / 2 * s
    ty = cy + (ymin + ymax) / 2 * s
    return f'<path fill="{fill}" transform="translate({tx:.2f} {ty:.2f}) scale({s:.4f} {-s:.4f})" d="{g["d"]}"/>'


def svg(body, w=512, h=512):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">{body}</svg>'


def meander_band(x0, x1, y, u, sw):
    """A Greek-key band from x0 to x1, top rule at y, `u` tall: outer and
    inner rules and a hooked spiral per unit, opening toward the inside."""
    parts = [f'M{x0} {y}H{x1}', f'M{x0} {y + u}H{x1}']
    n = int((x1 - x0) // u)
    pad = ((x1 - x0) - n * u) / 2
    for i in range(n):
        x = x0 + pad + i * u
        parts.append(
            f'M{x + 0.18*u:.2f} {y + u:.2f}V{y + 0.2*u:.2f}H{x + 0.82*u:.2f}'
            f'V{y + 0.66*u:.2f}H{x + 0.44*u:.2f}V{y + 0.44*u:.2f}'
        )
    return f'<path fill="none" stroke="{GOLD}" stroke-width="{sw}" stroke-linecap="square" d="{" ".join(parts)}"/>'


def meander_frame(m, u, sw, size=512):
    """A square frame of four meander bands with boxed corners, `m` in from
    the edge, bands `u` deep."""
    c = size / 2
    band = meander_band(m + u, size - m - u, m, u, sw)
    sides = "".join(f'<g transform="rotate({a} {c} {c})">{band}</g>' for a in (0, 90, 180, 270))
    corner = "".join(
        f'<rect x="{x}" y="{y}" width="{u}" height="{u}" fill="none" stroke="{GOLD}" stroke-width="{sw}"/>'
        f'<rect x="{x + u*0.3:.2f}" y="{y + u*0.3:.2f}" width="{u*0.4:.2f}" height="{u*0.4:.2f}" fill="{GOLD}"/>'
        for x in (m, size - m - u) for y in (m, size - m - u)
    )
    return sides + corner


def gear(cx, cy, r_in, r_out, teeth, sw):
    pts = []
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4)
        r = r_out if i % 4 in (1, 2) else r_in
        pts.append(f"{cx + r*math.cos(a):.2f},{cy + r*math.sin(a):.2f}")
    return (f'<polygon fill="none" stroke="{GOLD}" stroke-width="{sw}" stroke-linejoin="round" points="{" ".join(pts)}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r_in - 22}" fill="none" stroke="{GOLD}" stroke-width="{sw*0.6:.1f}"/>')


marks = {
    "1-plain": ("ϗ alone", svg(kai(256, 256, 380))),
    "2-coin": ("ϗ on a coin's double ring",
               svg(f'<circle cx="256" cy="256" r="232" fill="none" stroke="{GOLD}" stroke-width="10"/>'
                   f'<circle cx="256" cy="256" r="210" fill="none" stroke="{GOLD}" stroke-width="3"/>'
                   + kai(256, 256, 290))),
    "3-meander-fine": ("ϗ in a fine meander frame",
                       svg(meander_frame(22, 54, 6) + kai(256, 256, 250))),
    "4-meander-bold": ("ϗ in a bold meander frame",
                       svg(meander_frame(16, 84, 13) + kai(256, 256, 210))),
    "5-arrow": ("the archer's kairos: an arrow through the narrow opening",
                svg(f'<rect x="200" y="96" width="34" height="320" fill="{GOLD}"/>'
                    f'<rect x="278" y="96" width="34" height="320" fill="{GOLD}"/>'
                    f'<path d="M60 256H430" stroke="{GOLD}" stroke-width="12"/>'
                    f'<path d="M462 256L410 228V284Z" fill="{GOLD}"/>'
                    f'<path d="M60 256l-26-26M60 256l-26 26M84 256l-26-26M84 256l-26 26" stroke="{GOLD}" stroke-width="8" fill="none"/>')),
    "6-gear": ("ϗ in an Antikythera gear", svg(gear(256, 256, 196, 236, 30, 8) + kai(256, 256, 250))),
    "7-meander-gear": ("ϗ in a gear, in a meander frame",
                       svg(meander_frame(14, 46, 5) + gear(256, 256, 150, 176, 26, 6) + kai(256, 256, 190))),
}

# Appended to mockups.py: a meander bent into a ring.
import math


def meander_ring(cx, cy, r_out, depth, n, sw):
    """A Greek-key band bent round a circle: outer and inner rules, and n
    hooked spirals, each a unit of the straight band mapped onto the ring
    (along the band becomes the angle, into the band the radius)."""
    hook = [(0.18, 1.0), (0.18, 0.2), (0.82, 0.2), (0.82, 0.66), (0.44, 0.66), (0.44, 0.44)]

    def pt(i, ux, uy):
        a = (i + ux) / n * 2 * math.pi - math.pi / 2
        r = r_out - uy * depth
        return cx + r * math.cos(a), cy + r * math.sin(a)

    parts = []
    for i in range(n):
        d = []
        for k, ((x0, y0), (x1, y1)) in enumerate(zip(hook, hook[1:])):
            # Segments along the band are arcs: sample them.
            steps = 8 if y0 == y1 else 1
            for s in range(0 if k == 0 else 1, steps + 1):
                t = s / steps
                x, y = pt(i, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)
                d.append(("M" if not d else "L") + f"{x:.2f} {y:.2f}")
        parts.append("".join(d))
    rules = (f'<circle cx="{cx}" cy="{cy}" r="{r_out}" fill="none" stroke="{GOLD}" stroke-width="{sw}"/>'
             f'<circle cx="{cx}" cy="{cy}" r="{r_out - depth}" fill="none" stroke="{GOLD}" stroke-width="{sw}"/>')
    return rules + f'<path fill="none" stroke="{GOLD}" stroke-width="{sw}" stroke-linejoin="miter" stroke-linecap="square" d="{" ".join(parts)}"/>'


marks["9-meander-ring"] = ("ϗ in a circular meander", svg(meander_ring(256, 256, 236, 52, 22, 5) + kai(256, 256, 240)))
marks["10-meander-ring-bold"] = ("ϗ in a bold circular meander", svg(meander_ring(256, 256, 240, 76, 18, 10) + kai(256, 256, 190)))
marks["11-meander-ring-coin"] = ("ϗ on a coin, a circular meander at its rim",
    svg(meander_ring(256, 256, 244, 44, 26, 4.5) + f'<circle cx="256" cy="256" r="182" fill="none" stroke="{GOLD}" stroke-width="2.5"/>' + kai(256, 256, 230)))

lockup = svg(
    f'<text x="400" y="190" text-anchor="middle" font-family="GFS Didot, serif" font-size="210" fill="{GOLD}">kαί</text>'
    + meander_band(80, 720, 236, 40, 5),
    800, 300)
open(f"{OUT}/8-wordmark-meander.svg", "w").write(lockup)

for name, (label, s) in marks.items():
    open(f"{OUT}/{name}.svg", "w").write(s)

cards = "".join(
    f'<figure><img class="big" src="{n}.svg" alt=""><div class="small">'
    + "".join(f'<img src="{n}.svg" width="{px}" height="{px}" alt="">' for px in (64, 32, 16))
    + f'</div><figcaption>{l}</figcaption></figure>'
    for n, (l, _) in marks.items()
)
page = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Kai logo mockups</title>
<link href="https://fonts.googleapis.com/css2?family=EB+Garamond&family=GFS+Didot&family=JetBrains+Mono&display=swap" rel="stylesheet">
<style>
body {{ margin: 0; color: #ece8dc; font: 14px/1.5 "JetBrains Mono", monospace;
  background: radial-gradient(ellipse at center, rgb(17 17 17 / 55%), rgb(17 17 17 / 82%) 75%),
  url("/images/pastoral-1920.webp") center / cover fixed, #111; }}
h1 {{ color: {GOLD}; font: 400 2.4rem "EB Garamond", serif; margin: 2rem 2rem 0.3rem; }}
p {{ margin: 0 2rem 1.5rem; color: #a8a08a; max-width: 70ch; }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 1rem; padding: 0 2rem 2rem; }}
figure {{ margin: 0; padding: 1rem; border: 1px solid rgb(232 200 114 / 25%); border-radius: 10px;
  background: rgb(10 10 10 / 50%); backdrop-filter: blur(5px); display: flex; flex-direction: column; align-items: center; gap: 0.8rem; }}
.big {{ width: 220px; height: 220px; }}
.small {{ display: flex; align-items: end; gap: 1rem; }}
figcaption {{ color: {GOLD}; text-align: center; }}
.wide {{ grid-column: 1 / -1; }} .wide img {{ width: min(100%, 640px); }}
</style></head><body>
<h1>ϗ: logo mockups</h1>
<p>ϗ is the kai compendium (Unicode GREEK KAI SYMBOL, U+03D7), the medieval Greek shorthand for καί, "and": Greek's ampersand. Drawn from EB Garamond's outline. Each mark at full size, then 64, 32 and 16 pixels (favicon sizes).</p>
<div class="grid">{cards}
<figure class="wide"><img src="8-wordmark-meander.svg" alt=""><figcaption>the kαί wordmark over a meander band</figcaption></figure>
</div></body></html>"""
open(f"{OUT}/index.html", "w").write(page)
print("wrote", len(marks) + 1, "marks")
