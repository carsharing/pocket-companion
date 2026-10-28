"""Single source of truth for the companion's artwork.

Each species is a list of layers (SVG path data restricted to M/L/C/Q/Z, absolute coordinates,
in a 100x100 grid with the ground at y=88). `preview.py` renders them as SVG to check the look;
`generate_swift.py` writes the same data to Shared/CreatureArt.swift for the app.

Parts are drawn in PART_ORDER and animated separately by the app (tail wag, head tilt, blinking).
Layers with a `tag` are alternatives chosen by expression, e.g. "eyes.open" or "mouth.happy".
"""
import math

OUTLINE = "#3B1E18"
PART_ORDER = ["back", "tail", "legsFar", "body", "legsNear", "head", "face", "front"]

# Pivots the app rotates/scales parts around.
NECK = (57.0, 63.0)
TAIL_ROOT = (31.0, 68.0)
GROUND = (46.0, 88.0)


def layer(part, d, fill=None, stroke=False, width=1.7, tag=None, opacity=1.0):
    return dict(part=part, d=d, fill=fill, stroke=stroke, width=width, tag=tag, opacity=opacity)


def ellipse(cx, cy, rx, ry):
    """Ellipse as four cubic curves (k = 0.5523)."""
    k = 0.5523
    return (f"M{cx+rx:.2f},{cy:.2f} "
            f"C{cx+rx:.2f},{cy+ry*k:.2f} {cx+rx*k:.2f},{cy+ry:.2f} {cx:.2f},{cy+ry:.2f} "
            f"C{cx-rx*k:.2f},{cy+ry:.2f} {cx-rx:.2f},{cy+ry*k:.2f} {cx-rx:.2f},{cy:.2f} "
            f"C{cx-rx:.2f},{cy-ry*k:.2f} {cx-rx*k:.2f},{cy-ry:.2f} {cx:.2f},{cy-ry:.2f} "
            f"C{cx+rx*k:.2f},{cy-ry:.2f} {cx+rx:.2f},{cy-ry*k:.2f} {cx+rx:.2f},{cy:.2f} Z")


def parse(d):
    """Path data -> [(cmd, [x0, y0, x1, y1, ...])]."""
    import re
    out = []
    for cmd, args in re.findall(r"([MLCQZ])([^MLCQZ]*)", d):
        nums = [float(n) for n in re.findall(r"-?\d*\.?\d+", args)]
        out.append((cmd, nums))
    return out


def unparse(cmds):
    parts = []
    for cmd, nums in cmds:
        pts = " ".join(f"{nums[i]:.2f},{nums[i+1]:.2f}" for i in range(0, len(nums), 2))
        parts.append(f"{cmd}{pts}")
    return " ".join(parts)


def transform(d, fn):
    """Applies fn(x, y) -> (x, y) to every point."""
    cmds = []
    for cmd, nums in parse(d):
        pts = []
        for i in range(0, len(nums), 2):
            pts += list(fn(nums[i], nums[i+1]))
        cmds.append((cmd, pts))
    return unparse(cmds)


def mirror(d, axis):
    """Mirror path data horizontally around x = axis."""
    return transform(d, lambda x, y: (2 * axis - x, y))


def leg(x, w, top, flare=1.0):
    """A short leg from inside the body down to the ground, slightly tapered, with a rounded paw.

    Returns (fill, paw, outline): the outline is open at the top so it blends into the body.
    """
    b = 88.0
    x0, x1 = x - flare, x + w + flare          # wider at the top
    fill = (f"M{x0},{top} L{x1},{top} C{x+w},{top+5} {x+w+0.2},{b-6} {x+w+0.4},{b-3} "
            f"Q{x+w+0.6},{b} {x+w-2.6},{b} L{x+1.6},{b} Q{x-1.2},{b} {x-0.6},{b-3} "
            f"C{x-0.2},{b-6} {x},{top+5} {x0},{top} Z")
    paw = (f"M{x-0.5},{b-4.6} C{x+1.5},{b-5.6} {x+w-1.5},{b-5.6} {x+w+0.5},{b-4.6} L{x+w+0.4},{b-3} "
           f"Q{x+w+0.6},{b} {x+w-2.6},{b} L{x+1.6},{b} Q{x-1.2},{b} {x-0.6},{b-3} Z")
    outline = (f"M{x0+0.6},{top+3} C{x},{top+6} {x-0.2},{b-6} {x-0.6},{b-3} Q{x-1.2},{b} {x+1.6},{b} "
               f"L{x+w-2.6},{b} Q{x+w+0.6},{b} {x+w+0.4},{b-3} C{x+w+0.2},{b-6} {x+w},{top+6} {x1-0.6},{top+3}")
    return fill, paw, outline


# ---------------------------------------------------------------- face

def face_layers(eye_l=(51.5, 48.5), eye_r=(66.5, 48.5), nose=(60.5, 55.0), cheek_dy=6.5,
                eye_w=4.7, eye_h=5.3, nose_color=OUTLINE, cheek="#F48C9B", mouth_color="#7A2330"):
    L = []
    ink = "#2A1410"
    for (ex, ey) in (eye_l, eye_r):
        # Open: big dark eye, two highlights.
        L.append(layer("face", ellipse(ex, ey, eye_w, eye_h), ink, tag="eyes.open"))
        L.append(layer("face", ellipse(ex + 1.5, ey - 1.8, 1.9, 2.0), "#FFFFFF", tag="eyes.open"))
        L.append(layer("face", ellipse(ex - 1.7, ey + 2.1, 0.9, 0.9), "#FFFFFF", tag="eyes.open"))
        # Happy: ^ ^
        L.append(layer("face", f"M{ex-3.4},{ey+1} Q{ex},{ey-4.2} {ex+3.4},{ey+1}", None, True, 1.8, "eyes.happy"))
        # Closed (asleep): gentle downward arcs.
        L.append(layer("face", f"M{ex-3.4},{ey} Q{ex},{ey+3.4} {ex+3.4},{ey}", None, True, 1.7, "eyes.closed"))
        # Blink.
        L.append(layer("face", f"M{ex-3.2},{ey+0.6} L{ex+3.2},{ey+0.6}", None, True, 1.7, "eyes.blink"))
    # Sad brows.
    (lx, ly), (rx, ry) = eye_l, eye_r
    L.append(layer("face", f"M{lx-3},{ly-7.2} L{lx+2.6},{ly-8.8}", None, True, 1.4, "brows.sad"))
    L.append(layer("face", f"M{rx+3},{ry-7.2} L{rx-2.6},{ry-8.8}", None, True, 1.4, "brows.sad"))
    # Cheeks.
    L.append(layer("face", ellipse(lx - 2.5, ly + cheek_dy, 3.6, 2.1), cheek, opacity=0.75))
    L.append(layer("face", ellipse(rx + 2.5, ry + cheek_dy, 3.6, 2.1), cheek, opacity=0.75))
    # Nose.
    nx, ny = nose
    L.append(layer("face", f"M{nx-2.3},{ny-1} Q{nx},{ny-2.4} {nx+2.3},{ny-1} Q{nx+1.6},{ny+1.6} {nx},{ny+1.7} Q{nx-1.6},{ny+1.6} {nx-2.3},{ny-1} Z", nose_color))
    my = ny + 2.2
    # Mouths.
    L.append(layer("face", f"M{nx-3},{my+0.6} Q{nx-1.5},{my+2.4} {nx},{my} Q{nx+1.5},{my+2.4} {nx+3},{my+0.6}", None, True, 1.4, "mouth.smile"))
    L.append(layer("face", f"M{nx-3.4},{my+0.4} L{nx+3.4},{my+0.4} Q{nx+3.2},{my+6.4} {nx},{my+6.6} Q{nx-3.2},{my+6.4} {nx-3.4},{my+0.4} Z", mouth_color, True, 1.2, "mouth.happy"))
    L.append(layer("face", f"M{nx-2},{my+4.2} Q{nx},{my+2.6} {nx+2},{my+4.2} Q{nx+1.6},{my+6.2} {nx},{my+6.3} Q{nx-1.6},{my+6.2} {nx-2},{my+4.2} Z", "#F57C8A", tag="mouth.happy"))
    L.append(layer("face", f"M{nx-2.6},{my+2.4} Q{nx},{my+0.4} {nx+2.6},{my+2.4}", None, True, 1.4, "mouth.frown"))
    L.append(layer("face", ellipse(nx, my + 2.2, 1.9, 2.0), mouth_color, True, 1.1, "mouth.eat"))
    L.append(layer("face", ellipse(nx, my + 1.4, 1.0, 0.8), None, True, 1.0, "mouth.sleep"))
    return L


# ---------------------------------------------------------------- species

SPECIES = {
    "fox": dict(fur="#EE7230", far="#C9561E", cream="#FCEBD2", ear_in="#F4A0AE", paw="#4A2620",
                nose=OUTLINE, tip="#FCEBD2"),
    "kitsune": dict(fur="#FFF6EA", far="#E8D9C6", cream="#FFFFFF", ear_in="#F6A3B4", paw="#F2C9B2",
                    nose=OUTLINE, tip="#E5483B", accent="#E5483B", glow="#FF7AB0"),
    "bunny": dict(fur="#F3E4D4", far="#DCC8B4", cream="#FFFDF8", ear_in="#F6AFBD", paw="#E4CDB9",
                  nose="#E57789"),
    "cat": dict(fur="#A3AEC2", far="#848FA4", cream="#F6F4F0", ear_in="#F4A6B4", paw="#F6F4F0",
                nose="#E57789", stripe="#6C778D"),
    "dragon": dict(fur="#7DCFA6", far="#5DAF88", cream="#FCEBB0", ear_in="#FCEBB0", paw="#4E9A78",
                   nose=OUTLINE, wing="#B9A0E6", horn="#FFF1D2", spike="#F4B860"),
}

FOX_TAIL = ("M33,71 C25,73 17,69 14,61 C11,53 13,44 18,38 C20,35 22,33 24,32 "
            "C23,37 24,41 27,44 C31,48 35,54 37,60 C38,64 37,69 33,71 Z")
FOX_TIP = ("M14.2,60 C11.6,52 13,44 18,38 C20,35 22,33 24,32 C23.4,35 23.6,38 24.6,40.5 "
           "L21.5,41.5 L23.8,44 L19.6,45.4 L21.4,48.6 L17,49.6 L18.2,53 L14.2,54.5 Z")

HEADS = {
    "tufts": ("M59.5,31 C69.5,31 77,37 78,45.5 L83,51 L77.6,51.6 L80.6,56 L74,57 "
              "C70,61.6 64.8,63.2 59.5,63.2 C54.2,63.2 49,61.6 45,57 L38.4,56 L41.4,51.6 L36,51 "
              "L41,45.5 C42,37 49.5,31 59.5,31 Z",
              "M42.5,51.7 C48,50.4 54,51.4 59.5,54.6 C65,51.4 71,50.4 76.5,51.7 L77.6,51.6 L80.6,56 L74,57 "
              "C70,61.6 64.8,63.2 59.5,63.2 C54.2,63.2 49,61.6 45,57 L38.4,56 L41.4,51.6 Z"),
    "round": ("M59.5,31.5 C70.5,31.5 78,38.5 78,47.5 C78,56.5 70,63.2 59.5,63.2 "
              "C49,63.2 41,56.5 41,47.5 C41,38.5 48.5,31.5 59.5,31.5 Z",
              "M41.6,51.5 C47,50.4 54,51.4 59.5,54.6 C65,51.4 72,50.4 77.4,51.5 "
              "C76,58.6 68.6,63.2 59.5,63.2 C50.4,63.2 43,58.6 41.6,51.5 Z"),
    "cat": ("M59.5,31.5 C70.5,31.5 78,38.5 78,46.5 L81.5,50.5 L77.2,51.6 C75.5,58.6 68.6,63.2 59.5,63.2 "
            "C50.4,63.2 43.5,58.6 41.8,51.6 L37.5,50.5 L41,46.5 C41,38.5 48.5,31.5 59.5,31.5 Z",
            "M41.8,51.6 C47,50.4 54,51.4 59.5,54.6 C65,51.4 72,50.4 77.2,51.6 "
            "C75.5,58.6 68.6,63.2 59.5,63.2 C50.4,63.2 43.5,58.6 41.8,51.6 Z"),
}


def rotate(d, angle, pivot):
    a = math.radians(angle)
    px, py = pivot
    ca, sa = math.cos(a), math.sin(a)
    return transform(d, lambda x, y: (px + (x - px) * ca - (y - py) * sa, py + (x - px) * sa + (y - py) * ca))


def scallop(cx, cy, r, n=9, amp=1.6):
    """A fluffy circle: n bumps around a circle of radius r."""
    pts = []
    for i in range(n + 1):
        a = 2 * math.pi * i / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d = f"M{pts[0][0]:.2f},{pts[0][1]:.2f}"
    for i in range(1, n + 1):
        am = 2 * math.pi * (i - 0.5) / n
        c = (cx + (r + amp * 2) * math.cos(am), cy + (r + amp * 2) * math.sin(am))
        d += f" Q{c[0]:.2f},{c[1]:.2f} {pts[i][0]:.2f},{pts[i][1]:.2f}"
    return d + " Z"


def tail_layers(kind, c):
    if kind == "fox":
        return [layer("tail", FOX_TAIL, c["fur"]), layer("tail", FOX_TIP, c["tip"]), layer("tail", FOX_TAIL, None, True)]
    if kind == "kitsune":
        L = []
        for angle in (-22, -6, 12):
            t, tip = rotate(FOX_TAIL, angle, (33, 70)), rotate(FOX_TIP, angle, (33, 70))
            L += [layer("tail", t, c["fur"]), layer("tail", tip, c["tip"]), layer("tail", t, None, True)]
        return L
    if kind == "puff":
        d = scallop(28.5, 66, 5.6, 9, 1.1)
        return [layer("tail", d, c["cream"]), layer("tail", d, None, True)]
    if kind == "cat":
        t = ("M34,70 C25,72 19.5,66 19.5,57 C19.5,49 23.5,44 21.5,37.5 C20.5,34 22.6,31.6 25.2,33 "
             "C28,35 28.2,41 26.8,47.5 C25.6,53 25.8,60 31,62.6 Z")
        stripes = ["M19.6,54 C21.5,53 23.6,53.2 25.4,54.4 L25.4,57 C23.4,55.8 21.4,55.6 19.6,56.6 Z",
                   "M20.4,46.6 C22.4,45.8 24.6,46.2 26.4,47.6 L26,50.2 C24.2,48.8 22.2,48.4 20.2,49.2 Z",
                   "M21.4,39.2 C23.2,38.6 25.4,39 27.2,40.4 L27.2,43 C25.4,41.6 23.4,41.2 21.6,41.8 Z"]
        return ([layer("tail", t, c["fur"])] + [layer("tail", s, c["stripe"]) for s in stripes]
                + [layer("tail", t, None, True)])
    if kind == "dragon":
        # Lies low behind the body so the wing has room.
        t = "M32,64 C26,65 20,69 15.5,74.6 L13.4,77.4 C19,76.6 25.6,75.4 32,74.4 Z"
        spade = "M14.2,76 C12.4,73 9.6,72.4 7.6,73.8 C8.6,75.6 8.6,77.6 7.4,79.6 C9.8,80.4 12.6,79.6 14.2,78.2 Z"
        spikes = ["M19.4,71.2 L17.6,66.8 L22.6,68.6 Z", "M25.4,67.6 L24.4,63 L28.8,65.8 Z"]
        return ([layer("tail", s, c["spike"]) for s in spikes] + [layer("tail", s, None, True, 1.2) for s in spikes]
                + [layer("tail", spade, c["spike"]), layer("tail", spade, None, True),
                   layer("tail", t, c["fur"]), layer("tail", t, None, True)])
    raise ValueError(kind)


def ear_layers(kind, c):
    L = []
    if kind in ("fox", "kitsune"):
        ear = "M44.5,40 L40.5,21 C44.5,19 54.5,25 56.5,33.5 Z"
        inner = "M46,36.5 L43.4,25 C46.6,24.6 52,28.8 53.4,33 Z"
        tip = "M41.6,26.4 L40.5,21 C42.6,20 46.2,21.4 48.8,23.6 Z"
    elif kind == "bunny":
        ear = "M47.5,38 C45.2,32 44.2,24 46,19 C47.6,14.6 52,15 53,19.8 C54.2,25 54.3,31 53.6,36 Z"
        inner = "M48.7,33.6 C47.3,28.6 46.8,23 47.9,20.4 C48.8,18.2 50.6,18.4 51.1,20.8 C51.7,24.6 51.8,29 51.2,33.6 Z"
        tip = None
    elif kind == "cat":
        ear = "M45,39.5 L43.4,23.6 C47,23.4 53.6,28.6 55.6,33.6 Z"
        inner = "M46.4,36.2 L45.4,27.4 C48,27.8 51.6,30.6 52.8,33.4 Z"
        tip = None
    elif kind == "dragon":
        horn = "M48.6,34.6 C46.6,30 46.4,25 48.2,21.4 C50,24.6 52.6,28.6 53.6,32.6 Z"
        fin = "M42.5,44 C37.6,41.6 35,37.6 35,33.6 C38.6,35.2 41,35.6 43.6,37 C42.4,38.6 42.2,41 42.5,44 Z"
        for part in (horn, mirror(horn, 59.5)):
            L += [layer("head", part, c["horn"]), layer("head", part, None, True)]
        for part in (fin, mirror(fin, 59.5)):
            L += [layer("head", part, c["far"]), layer("head", part, None, True)]
        return L
    for e, i, t in ((ear, inner, tip), (mirror(ear, 59.5), mirror(inner, 59.5), tip and mirror(tip, 59.5))):
        L += [layer("head", e, c["fur"]), layer("head", i, c["ear_in"])]
        if t and kind == "kitsune":
            L.append(layer("head", t, c["accent"]))
        L.append(layer("head", e, None, True))
    return L


def species(name):
    c = SPECIES[name]
    tail_kind = {"fox": "fox", "kitsune": "kitsune", "bunny": "puff", "cat": "cat", "dragon": "dragon"}[name]
    head_kind = {"fox": "tufts", "kitsune": "tufts", "bunny": "round", "cat": "cat", "dragon": "round"}[name]
    L = []

    if name == "dragon":
        wing = ("M44,60.5 C42,50 37,42 26,35 C28.4,40.4 28.2,44.6 25.8,47.8 C30,47.8 32.8,50.8 32.6,55 "
                "C36.4,54 39.6,56.2 41,60.8 Z")
        far_wing = "M50,58.6 C49.6,52.6 51.6,47.6 56,44.6 C55.4,48 56.2,50.6 58,52.6 C55.6,53.4 54.4,55.6 54.6,58.4 Z"
        L += [layer("back", far_wing, c["wing"], opacity=0.85), layer("back", far_wing, None, True, 1.4),
              layer("back", wing, c["wing"]), layer("back", wing, None, True)]

    L += tail_layers(tail_kind, c)

    for f, p, o in (leg(39, 6.5, 72), leg(58, 6.5, 70)):
        L += [layer("legsFar", f, c["far"]), layer("legsFar", p, c["paw"]), layer("legsFar", o, None, True)]

    body = ("M37,60 C45,57 57,57 63,61 C69,65 70,75 65,79.5 C60,83 47,83.5 37,81.5 "
            "C29,80 25.5,74 27.5,68 C29,63.5 32.5,61.5 37,60 Z")
    chest = ("M55,60.5 C61,61.5 66,66 66,72 C65.5,75 64,77.5 62,78.5 L61,74.5 L59,77 L58.2,72.8 "
             "L55.5,74.5 L56.2,70 C55.4,67 54.6,63.5 55,60.5 Z")
    if name == "dragon":
        chest = "M55,60.5 C61,61.5 66,66 66,72 C65.5,75 64,77.5 62,78.5 C59,76 56.4,70 55,60.5 Z"
    L += [layer("body", body, c["fur"]), layer("body", chest, c["cream"])]
    if name == "cat":
        for d in ("M38,60.2 C38.6,62.6 38.4,65 37.4,67 L35.6,66.4 C36.2,64.6 36.2,62.4 35.6,60.8 Z",
                  "M44,58.6 C44.8,61.2 44.6,63.8 43.6,66 L41.6,65.6 C42.4,63.4 42.4,61.2 41.6,59 Z",
                  "M50,58.4 C50.8,61 50.6,63.6 49.6,65.8 L47.6,65.4 C48.4,63.2 48.4,61 47.6,58.8 Z"):
            L.append(layer("body", d, c["stripe"]))
    if name == "dragon":
        for x in (36, 43, 50):
            sp = f"M{x-2.6},{59.6 - (0.6 if x == 43 else 0)} L{x},{54.4} L{x+2.6},{59.2} Z"
            L += [layer("back", sp, c["spike"]), layer("back", sp, None, True, 1.2)]
    L.append(layer("body", body, None, True))

    for f, p, o in (leg(31, 7, 74), leg(52, 7, 76)):
        L += [layer("legsNear", f, c["fur"]), layer("legsNear", p, c["paw"]), layer("legsNear", o, None, True)]

    L += ear_layers({"fox": "fox", "kitsune": "kitsune", "bunny": "bunny", "cat": "cat", "dragon": "dragon"}[name], c)
    head, muzzle = HEADS[head_kind]
    L += [layer("head", head, c["fur"]), layer("head", muzzle, c["cream"])]
    if name == "kitsune":
        flame = "M59.5,34.2 C61.6,36.6 62.2,39 60.8,41.4 C60.2,42.4 58.8,42.4 58.2,41.4 C56.8,39 57.4,36.6 59.5,34.2 Z"
        L.append(layer("head", flame, c["accent"]))
        for d in ("M40.6,47.2 L46.4,48.6 L40.8,49.6 Z", "M78.4,47.2 L72.6,48.6 L78.2,49.6 Z"):
            L.append(layer("head", d, c["accent"]))
    if name == "cat":
        for d in ("M59.5,32 L60.6,32.2 L60.2,38 L58.8,38 L58.4,32.2 Z",
                  "M54.4,33.2 L55.6,32.8 L56.2,37 L55,37.4 Z", "M64.6,33.2 L63.4,32.8 L62.8,37 L64,37.4 Z"):
            L.append(layer("head", d, c["stripe"]))
    L.append(layer("head", head, None, True))

    face = face_layers(nose_color=c["nose"])
    if name == "cat":
        for d in ("M44.6,55.6 L37.4,54.4", "M44.8,57.6 L38,58.4", "M74.4,55.6 L81.6,54.4", "M74.2,57.6 L81,58.4"):
            face.append(layer("face", d, None, True, 0.9))
    if name == "bunny":
        # Little buck teeth peeking out of the open mouth.
        face.append(layer("face", "M59.2,58.2 L61.8,58.2 L61.8,60.2 L59.2,60.2 Z", "#FFFFFF", True, 0.7, "mouth.happy"))
    L += face

    scale_parts(L, ("head", "face"), 1.12, (59.5, 62.0))
    # Lift everything above the legs so it stands a little taller.
    return shift_parts(L, ("back", "tail", "body", "head", "face"), 0, -3.5)


def fox():
    return species("fox")


def shift_parts(layers, parts, dx, dy):
    for l in layers:
        if l["part"] in parts:
            l["d"] = transform(l["d"], lambda x, y: (x + dx, y + dy))
    return layers


def scale_parts(layers, parts, k, pivot):
    px, py = pivot
    for l in layers:
        if l["part"] in parts:
            l["d"] = transform(l["d"], lambda x, y: (px + (x - px) * k, py + (y - py) * k))
    return layers


def preview_svg(layers, tags, transforms=None, size=300, bg=None):
    """Render chosen tags to SVG. transforms: part -> SVG transform string."""
    transforms = transforms or {}
    groups = []
    for part in PART_ORDER:
        items = []
        for l in layers:
            if l["part"] != part: continue
            if l["tag"] and l["tag"] not in tags: continue
            fill = l["fill"] or "none"
            stroke = f'stroke="{OUTLINE}" stroke-width="{l["width"]}" stroke-linejoin="round" stroke-linecap="round"' if l["stroke"] else ""
            items.append(f'<path d="{l["d"]}" fill="{fill}" {stroke} opacity="{l["opacity"]}"/>')
        groups.append(f'<g transform="{transforms.get(part, "")}">{"".join(items)}</g>')
    shadow = '<ellipse cx="48" cy="88.5" rx="26" ry="2.6" fill="rgba(0,0,0,.14)"/>'
    return f'<svg viewBox="0 0 100 100" width="{size}" height="{size}">{shadow}{"".join(groups)}</svg>'


# ---------------------------------------------------------------- stage proportions

NECK_AT = (57.0, 59.5)      # after the lift above
TAIL_AT = (31.0, 64.5)

# part -> (tx, ty, sx, sy, pivot); plus a whole-figure scale around GROUND.
STAGE_RIG = {
    "baby": dict(figure=0.8, parts={
        "head": (0, 5.5, 1.28, 1.28, NECK_AT), "face": (0, 5.5, 1.28, 1.28, NECK_AT),
        "body": (0, 4, 0.95, 0.9, (46, 80)),
        "tail": (2.5, 5, 0.8, 0.8, TAIL_AT),
        "legsNear": (0, 0, 1, 0.62, (46, 88)), "legsFar": (0, 0, 1, 0.62, (46, 88)),
    }),
    "child": dict(figure=0.9, parts={
        "head": (0, 2.5, 1.12, 1.12, NECK_AT), "face": (0, 2.5, 1.12, 1.12, NECK_AT),
        "body": (0, 2, 0.98, 0.95, (46, 80)),
        "tail": (1, 2.5, 0.9, 0.9, TAIL_AT),
        "legsNear": (0, 0, 1, 0.82, (46, 88)), "legsFar": (0, 0, 1, 0.82, (46, 88)),
    }),
    "adult": dict(figure=1.0, parts={}),
}


def rig_svg_transforms(stage):
    rig = STAGE_RIG[stage]
    out = {}
    for part in PART_ORDER:
        t = rig["parts"].get(part)
        inner = ""
        if t:
            tx, ty, sx, sy, (px, py) = t
            inner = f"translate({tx} {ty}) translate({px} {py}) scale({sx} {sy}) translate({-px} {-py})"
        k = rig["figure"]
        gx, gy = GROUND
        out[part] = f"translate({gx} {gy}) scale({k}) translate({-gx} {-gy}) {inner}"
    return out


# ---------------------------------------------------------------- sleeping (curled up) and the den

def place(layers, k, src, dst, angle=0.0):
    """Scales layers by k around src, moves src to dst, then rotates around dst."""
    (sx, sy), (dx, dy) = src, dst
    a = math.radians(angle)
    ca, sa = math.cos(a), math.sin(a)

    def fn(x, y):
        x, y = dx + (x - sx) * k, dy + (y - sy) * k
        return dx + (x - dx) * ca - (y - dy) * sa, dy + (x - dx) * sa + (y - dy) * ca
    for l in layers:
        l["d"] = transform(l["d"], fn)
    return layers


def curled(name, cx=50.0, k=1.0):
    """Curled-up sleeping pose, reusing the species' own head and ears."""
    c = SPECIES[name]
    L = []
    tip_color = {"fox": c.get("tip"), "kitsune": c.get("accent"), "cat": c.get("stripe"),
                 "dragon": c.get("spike"), "bunny": None}[name]
    body = ellipse(48, 76.5, 23, 10.5)
    L += [layer("body", body, c["fur"])]
    if name == "dragon":
        wing = "M36,70 C38,63 44,60 51,60.5 C48.6,62.6 48.6,64.6 50,66.4 C46.4,66 44,67.6 43.4,70.4 C41,69 38.4,69.2 36,70 Z"
        L += [layer("body", body, None, True), layer("body", wing, c["wing"]), layer("body", wing, None, True)]
    else:
        L.append(layer("body", body, None, True))
    if name == "bunny":
        puff = scallop(26.6, 76, 4.6, 8, 0.9)
        L = [layer("body", puff, c["cream"]), layer("body", puff, None, True)] + L
    else:
        # Tail wraps around the front of the body; its tip curls up by the nose.
        wrap = ("M24,76 C23,85.6 34,89.6 48,89.6 C58,89.6 66,88.6 70.4,86 C73.6,84 73,80.6 69.4,80.8 "
                "C62,83 52,83.4 44,82.8 C34,82 27.6,80 24,76 Z")
        tip = ("M53,89.4 C59.6,89.2 66,88.4 70.4,86 C73.6,84 73,80.6 69.4,80.8 C64.6,82.4 59,83.2 53.6,83.4 "
               "L56,85.4 L53.2,86.6 L55.6,88 Z")
        L += [layer("body", wrap, c["fur"])]
        if tip_color:
            L.append(layer("body", tip, tip_color))
        L.append(layer("body", wrap, None, True))

    # Head resting on the tail, slightly tilted, eyes closed.
    head = [l for l in species(name) if l["part"] in ("head", "face")]
    place(head, 0.62, (59.5, 50.0), (63.0, 72.5), angle=12)
    for l in head:
        l["part"] = "head" if l["part"] == "head" else "face"
    L += head
    if k != 1.0 or cx != 50.0:
        place(L, k, (48.0, 88.0), (cx, 88.0))
    return L


def den():
    """The newborn's den: an earthy burrow with a tiny kit asleep inside."""
    L = [
        layer("back", "M6,88 C8,58 26,38 50,38 C74,38 92,58 94,88 Z", "#B98A5E"),
        layer("back", "M6,88 C8,58 26,38 50,38 C74,38 92,58 94,88", None, True),
        layer("back", "M18,88 C19,66 32,52 50,52 C68,52 81,66 82,88 Z", "#5A3A2A"),
        layer("back", "M18,88 C19,66 32,52 50,52 C68,52 81,66 82,88", None, True, 1.4),
        layer("back", ellipse(30, 47, 2.2, 1.4), "#9C7048"),
        layer("back", ellipse(73, 50, 2.6, 1.6), "#9C7048"),
        layer("back", ellipse(84, 70, 2, 1.3), "#9C7048"),
        layer("back", ellipse(14, 72, 1.8, 1.2), "#9C7048"),
    ]
    kit = curled("fox", cx=50, k=0.72)
    L += kit
    grass = "#6CBF5A"
    for x in (12, 20, 80, 88):
        g = f"M{x-4},88 Q{x-3},82 {x-1.6},79 Q{x-1},84 {x},85 Q{x+0.6},80.6 {x+2},78.6 Q{x+2.6},84 {x+4},88 Z"
        L += [layer("front", g, grass), layer("front", g, None, True, 1.2)]
    leaf = "M64,40.5 C66,36.4 70.6,35.4 73.6,36.6 C72,40 68,42 64,40.5 Z"
    L += [layer("front", leaf, "#E9A23B"), layer("front", leaf, None, True, 1.2)]
    return L
