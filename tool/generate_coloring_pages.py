#!/usr/bin/env python3
"""Generates Pastello's coloring pages (F-19) as SVG files.

The pages are drawn here, shape by shape, so they are original works of the
project, dedicated to the public domain (CC0). Run from the repository root:

    python3 tool/generate_coloring_pages.py

Every page is 800 x 800 with black lines 16 units thick. Shapes are filled
with white and drawn from back to front, so a shape hides the lines behind
it; the app only keeps the dark lines (ADR 0022).
"""
import json
import math
import os

ROOT = "app/assets/packs"
SIZE = 800
WIDTH = 16


def f(n):
    return f"{n:.0f}" if abs(n - round(n)) < 0.05 else f"{n:.1f}"


def pts(points):
    return " ".join(f"{f(x)},{f(y)}" for x, y in points)


# --- Shapes -------------------------------------------------------------------
# Closed shapes are white; lines (`fill="none"`) only add details.


def path(d, fill="#fff", extra=""):
    return f'<path d="{d}" fill="{fill}"{extra}/>'


def line(d):
    return path(d, fill="none")


def dot(x, y, r):
    """A small solid black dot (eyes, noses)."""
    return f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="#000"/>'


def circle(x, y, r, fill="#fff"):
    return f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{fill}"/>'


def ellipse(x, y, rx, ry, rotate=0, fill="#fff"):
    t = f' transform="rotate({f(rotate)} {f(x)} {f(y)})"' if rotate else ""
    return (
        f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(rx)}" ry="{f(ry)}" '
        f'fill="{fill}"{t}/>'
    )


def rect(x, y, w, h, r=0, fill="#fff"):
    rr = f' rx="{f(r)}"' if r else ""
    return (
        f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}"{rr} '
        f'fill="{fill}"/>'
    )


def polygon(points, fill="#fff"):
    return f'<polygon points="{pts(points)}" fill="{fill}"/>'


def star_points(cx, cy, r, inner=0.45, n=5, turn=0):
    out = []
    for i in range(2 * n):
        a = -math.pi / 2 + i * math.pi / n + turn
        rr = r if i % 2 == 0 else r * inner
        out.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return out


def star(cx, cy, r, inner=0.45):
    return polygon(star_points(cx, cy, r, inner))


def scallops(cx, cy, rx, ry, n, bump=1.0):
    """A closed outline of n round bumps around an ellipse: clouds, tree
    crowns."""
    points = [
        (cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n))
        for i in range(n)
    ]
    d = f"M {f(points[0][0])} {f(points[0][1])}"
    for i in range(n):
        x0, y0 = points[i]
        x1, y1 = points[(i + 1) % n]
        r = math.hypot(x1 - x0, y1 - y0) / 2 * bump
        d += f" A {f(r)} {f(r)} 0 0 1 {f(x1)} {f(y1)}"
    return d + " Z"


def cloud(cx, cy, s=1.0):
    return path(scallops(cx, cy, 90 * s, 45 * s, 7, 1.15))


def sun(cx, cy, r, rays=8):
    out = []
    for i in range(rays):
        a = 2 * math.pi * i / rays
        x0, y0 = cx + (r + 18) * math.cos(a), cy + (r + 18) * math.sin(a)
        x1, y1 = cx + (r + 50) * math.cos(a), cy + (r + 50) * math.sin(a)
        out.append(line(f"M {f(x0)} {f(y0)} L {f(x1)} {f(y1)}"))
    out.append(circle(cx, cy, r))
    return out


def smile(cx, cy, w, h):
    return line(f"M {f(cx - w)} {f(cy)} Q {f(cx)} {f(cy + h)} {f(cx + w)} {f(cy)}")


def mirror(d):
    """Mirrors the numbers of a simple path (absolute M/L/C/Q/Z commands)
    around the vertical axis of the page."""
    out, xs = [], True
    for token in d.split():
        if token.isalpha():
            out.append(token)
            xs = True
            continue
        n = float(token)
        out.append(f(SIZE - n) if xs else f(n))
        xs = not xs
    return " ".join(out)


def svg(shapes, defs=""):
    body = "\n".join(shapes)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SIZE} {SIZE}" '
        f'width="{SIZE}" height="{SIZE}">\n'
        + (f"<defs>{defs}</defs>\n" if defs else "")
        + f'<g stroke="#000" stroke-width="{WIDTH}" stroke-linejoin="round" '
        f'stroke-linecap="round">\n{body}\n</g>\n</svg>\n'
    )


# --- Animals ------------------------------------------------------------------


def cat():
    s = [
        # Tail, behind the body.
        path("M 500 660 C 690 670 720 480 660 400 C 640 375 600 390 615 420 "
             "C 660 500 640 610 500 615 Z"),
        path("M 260 710 C 220 560 280 420 400 420 C 520 420 580 560 540 710 Z"),
        ellipse(400, 600, 80, 95),
        ellipse(320, 712, 62, 32),
        ellipse(480, 712, 62, 32),
        polygon([(268, 260), (255, 115), (370, 200)]),
        polygon([(532, 260), (545, 115), (430, 200)]),
        line("M 283 215 L 278 160 L 328 196"),
        line("M 517 215 L 522 160 L 472 196"),
        ellipse(400, 290, 165, 135),
        ellipse(340, 278, 18, 26, fill="#000"),
        ellipse(460, 278, 18, 26, fill="#000"),
        polygon([(384, 318), (416, 318), (400, 336)], fill="#000"),
        line("M 400 336 Q 400 362 372 364"),
        line("M 400 336 Q 400 362 428 364"),
        line("M 300 325 L 218 310"),
        line("M 302 345 L 222 358"),
        line("M 500 325 L 582 310"),
        line("M 498 345 L 578 358"),
    ]
    return svg(s)


def dog():
    s = [
        # Wagging tail, behind the body.
        path("M 520 650 C 620 640 660 560 660 470 C 680 455 705 470 700 495 "
             "C 692 600 625 690 525 695 Z"),
        path("M 270 720 C 250 560 300 430 400 430 C 500 430 550 560 530 720 Z"),
        line("M 350 570 L 350 712"),
        line("M 450 570 L 450 712"),
        ellipse(335, 722, 60, 28),
        ellipse(465, 722, 60, 28),
        # Collar and tag.
        path("M 300 418 Q 400 468 500 418 L 504 452 Q 400 505 296 452 Z"),
        circle(400, 498, 24),
        ellipse(400, 295, 155, 140),
        # Floppy ears, over the head.
        path("M 275 200 C 190 205 165 380 228 432 C 272 460 300 380 300 290 Z"),
        path(mirror("M 275 200 C 190 205 165 380 228 432 C 272 460 300 380 300 290 Z")),
        ellipse(458, 280, 52, 48),
        dot(345, 282, 17),
        dot(455, 282, 17),
        ellipse(400, 368, 72, 52),
        ellipse(400, 343, 27, 18, fill="#000"),
        line("M 400 361 L 400 386"),
        line("M 400 386 Q 378 408 356 392"),
        line("M 400 386 Q 422 408 444 392"),
    ]
    return svg(s)


def bunny():
    s = [
        ellipse(335, 175, 52, 140, rotate=-10),
        ellipse(465, 175, 52, 140, rotate=10),
        ellipse(335, 190, 22, 100, rotate=-10, fill="none"),
        ellipse(465, 190, 22, 100, rotate=10, fill="none"),
        ellipse(400, 585, 170, 160),
        ellipse(400, 615, 100, 105, fill="none"),
        ellipse(318, 738, 72, 34),
        ellipse(482, 738, 72, 34),
        circle(400, 335, 130),
        dot(352, 320, 15),
        dot(448, 320, 15),
        polygon([(386, 358), (414, 358), (400, 374)], fill="#000"),
        line("M 400 374 Q 400 396 378 398"),
        line("M 400 374 Q 400 396 422 398"),
        line("M 340 375 L 270 365"),
        line("M 342 392 L 275 400"),
        line("M 460 375 L 530 365"),
        line("M 458 392 L 525 400"),
        # A carrot, standing next to the bunny.
        line("M 640 480 Q 615 420 645 395"),
        line("M 660 480 Q 662 405 685 385"),
        line("M 680 480 Q 715 430 735 425"),
        path("M 610 485 Q 660 460 710 485 L 668 735 Q 660 750 652 735 Z"),
        line("M 625 545 L 660 540"),
        line("M 670 600 L 693 597"),
        line("M 640 650 L 668 648"),
    ]
    return svg(s)


def fish():
    s = [
        polygon([(580, 400), (750, 265), (750, 535)]),
        path("M 300 240 Q 380 130 480 255 Z"),
        path("M 300 560 Q 365 660 440 550 Z"),
        ellipse(350, 400, 260, 170),
        line("M 470 285 Q 525 400 470 515"),
        circle(210, 360, 30),
        dot(215, 362, 12),
        smile(140, 440, 30, 20),
        # Bubbles.
        circle(110, 230, 26),
        circle(150, 150, 18),
        circle(100, 90, 12),
    ]
    return svg(s)


def butterfly():
    upper = "M 390 380 C 300 150 110 110 105 265 C 100 390 250 430 390 410 Z"
    lower = "M 390 425 C 255 430 150 525 195 625 C 240 705 365 630 395 470 Z"
    s = [
        path(upper),
        path(mirror(upper)),
        path(lower),
        path(mirror(lower)),
        circle(225, 275, 48),
        circle(575, 275, 48),
        circle(268, 560, 36),
        circle(532, 560, 36),
        line("M 390 398 Q 270 340 160 355"),
        line(mirror("M 390 398 Q 270 340 160 355")),
        line("M 388 228 Q 350 140 305 128"),
        line(mirror("M 388 228 Q 350 140 305 128")),
        dot(303, 128, 13),
        dot(497, 128, 13),
        ellipse(400, 455, 30, 175),
        circle(400, 262, 44),
        dot(386, 258, 7),
        dot(414, 258, 7),
    ]
    return svg(s)


def turtle():
    shell = "M 150 560 C 160 290 640 290 650 560 Z"
    hexagon = [
        (400 + 72 * math.cos(math.pi / 3 * i), 455 + 72 * math.sin(math.pi / 3 * i))
        for i in range(6)
    ]
    rays = [((0, 140), (130, 0)), ((3, 140), (-130, 0)), ((1, 0), (-40, 120)),
            ((2, 0), (40, 120)), ((4, 0), (-70, -130)), ((5, 0), (70, -130))]
    s = [
        polygon([(160, 545), (80, 585), (165, 590)]),
        ellipse(712, 495, 72, 58),
        dot(735, 480, 11),
        smile(722, 515, 26, 14),
        rect(190, 560, 80, 140, 34),
        rect(530, 560, 80, 140, 34),
        path(shell),
        polygon(hexagon),
    ]
    for (i, _), (dx, dy) in rays:
        x, y = hexagon[i]
        s.append(line(f"M {f(x)} {f(y)} L {f(x + dx * 2)} {f(y + dy * 2)}")
                 .replace("/>", ' clip-path="url(#shell)"/>'))
    s.append(path(shell, fill="none"))
    s.append(path("M 130 560 L 670 560 Q 670 602 630 602 L 170 602 Q 130 602 130 560 Z"))
    return svg(s, defs=f'<clipPath id="shell"><path d="{shell}"/></clipPath>')


def unicorn():
    head = ("M 400 175 C 520 175 562 262 548 360 C 540 425 522 470 522 525 "
            "C 522 600 472 645 400 645 C 328 645 278 600 278 525 "
            "C 278 470 260 425 252 360 C 238 262 280 175 400 175 Z")
    mane = ("M 335 190 C 225 195 170 295 198 380 C 150 445 168 525 218 565 "
            "C 196 615 226 668 282 668 C 270 600 270 520 266 440 "
            "C 252 340 262 252 335 190 Z")
    ear = "M 312 238 L 282 112 L 372 186 Z"
    lash = "M {x0} 352 L {x1} 334"
    s = [
        star(130, 150, 36),
        star(680, 170, 28),
        star(670, 560, 34),
        path("M 322 600 L 300 770 L 500 770 L 478 600 Z"),
        path(mane),
        line("M 210 380 C 240 330 270 280 320 220"),
        line("M 222 565 C 238 520 250 470 262 430"),
        path(ear),
        path(mirror(ear)),
        line("M 312 205 L 297 150 L 338 185"),
        line(mirror("M 312 205 L 297 150 L 338 185")),
        path(head),
        polygon([(368, 205), (432, 205), (400, 40)]),
        line("M 378 165 L 422 150"),
        line("M 386 120 L 414 110"),
        path("M 330 215 Q 352 160 400 192 Q 448 160 470 215 "
             "Q 438 250 400 228 Q 362 252 330 215 Z"),
        ellipse(338, 385, 24, 32, fill="#000"),
        ellipse(462, 385, 24, 32, fill="#000"),
        line("M 316 368 L 296 350"),
        line("M 322 356 L 308 334"),
        line("M 484 368 L 504 350"),
        line("M 478 356 L 492 334"),
        circle(318, 455, 24, fill="none"),
        circle(482, 455, 24, fill="none"),
        ellipse(400, 560, 112, 72),
        ellipse(362, 548, 10, 15, fill="#000"),
        ellipse(438, 548, 10, 15, fill="#000"),
        smile(400, 585, 34, 18),
    ]
    return svg(s)


# --- Vehicles -----------------------------------------------------------------


def car():
    body = ("M 100 560 Q 100 470 170 460 L 250 450 L 320 340 Q 332 320 360 320 "
            "L 520 320 Q 548 320 565 345 L 630 450 L 690 460 Q 720 470 720 520 "
            "L 720 580 Q 720 600 700 600 L 120 600 Q 100 600 100 580 Z")
    s = [
        path(body),
        path("M 340 352 L 400 352 L 400 448 L 278 448 Z"),
        path("M 430 352 L 528 352 Q 545 352 555 368 L 600 448 L 430 448 Z"),
        line("M 415 452 L 415 590"),
        line("M 440 485 L 480 485"),
        ellipse(696, 505, 14, 24),
        rect(100, 500, 34, 34, 8),
        circle(240, 600, 78),
        circle(240, 600, 30),
        circle(580, 600, 78),
        circle(580, 600, 30),
        line("M 40 690 L 760 690"),
    ]
    return svg(s)


def train():
    s = [
        path(scallops(190, 175, 50, 35, 6, 1.1)),
        path(scallops(270, 110, 62, 42, 7, 1.1)),
        path(scallops(375, 70, 48, 30, 6, 1.1)),
        polygon([(150, 365), (200, 365), (220, 235), (130, 235)]),
        path("M 120 365 L 330 365 L 330 530 L 120 530 Q 70 530 70 447 Q 70 365 120 365 Z"),
        line("M 160 365 L 160 530"),
        line("M 240 365 L 240 530"),
        rect(330, 250, 160, 280),
        rect(310, 225, 200, 35, 8),
        rect(362, 290, 96, 90, 8),
        polygon([(70, 500), (22, 585), (90, 585)]),
        rect(60, 528, 450, 40, 8),
        circle(150, 610, 50),
        circle(275, 610, 50),
        circle(420, 600, 66),
        circle(420, 600, 22),
        line("M 510 548 L 540 548"),
        rect(540, 380, 220, 168, 10),
        line("M 560 420 L 740 420"),
        rect(535, 540, 230, 30, 8),
        circle(600, 612, 44),
        circle(700, 612, 44),
        line("M 20 680 L 780 680"),
    ]
    return svg(s)


def sailboat():
    s = sun(140, 150, 55)
    s += [
        line("M 400 520 L 400 80"),
        polygon([(400, 80), (470, 105), (400, 130)]),
        polygon([(415, 145), (415, 490), (650, 490)]),
        polygon([(385, 175), (385, 490), (195, 490)]),
        path("M 130 520 L 670 520 L 585 645 L 215 645 Z"),
        circle(300, 580, 24),
        circle(400, 580, 24),
        circle(500, 580, 24),
        line("M 30 700 Q 90 655 150 700 Q 210 745 270 700 Q 330 655 390 700 "
             "Q 450 745 510 700 Q 570 655 630 700 Q 690 745 750 700"),
        line("M 90 765 Q 150 725 210 765 M 330 765 Q 390 725 450 765 "
             "M 570 765 Q 630 725 690 765"),
    ]
    return svg(s)


def airplane():
    s = [
        cloud(170, 640, 1.1),
        cloud(640, 160, 0.9),
        polygon([(135, 362), (100, 215), (185, 215), (262, 355)]),
        path("M 100 420 Q 100 362 180 352 L 600 352 Q 700 352 725 405 "
             "Q 700 458 600 460 L 180 460 Q 100 460 100 420 Z"),
        path("M 630 368 Q 690 372 708 400 L 630 400 Z"),
    ]
    s += [circle(250 + 60 * i, 395, 18) for i in range(6)]
    s += [
        path("M 330 432 L 480 432 L 395 610 L 318 610 Z"),
    ]
    return svg(s)


def rocket():
    body = "M 400 100 C 500 180 522 300 510 520 L 290 520 C 278 300 300 180 400 100 Z"
    s = [
        star(140, 170, 40),
        star(660, 240, 30),
        star(650, 620, 38),
        star(160, 470, 28),
        path("M 340 555 Q 325 655 400 730 Q 475 655 460 555 Z"),
        line("M 372 570 Q 372 640 400 675 Q 428 640 428 570"),
        polygon([(298, 400), (200, 565), (300, 540)]),
        polygon([(502, 400), (600, 565), (500, 540)]),
        polygon([(330, 515), (470, 515), (450, 570), (350, 570)]),
        path(body),
        line("M 335 225 Q 400 205 465 225"),
        circle(400, 345, 58),
        circle(400, 345, 34),
        line("M 340 460 L 460 460"),
    ]
    return svg(s)


def balloon():
    shape = ("M 400 100 C 600 100 660 300 560 450 L 480 540 L 320 540 L 240 450 "
             "C 140 300 200 100 400 100 Z")
    s = [
        cloud(130, 220, 0.8),
        cloud(680, 400, 0.9),
        path(shape),
    ]
    for d in ["M 400 100 C 300 200 290 380 360 540", "M 400 100 L 400 540",
              "M 400 100 C 500 200 510 380 440 540",
              "M 150 400 Q 400 450 650 400"]:
        s.append(line(d).replace("/>", ' clip-path="url(#balloon)"/>'))
    s += [
        path(shape, fill="none"),
        line("M 330 540 L 348 625"),
        line("M 470 540 L 452 625"),
        path("M 330 625 L 470 625 L 455 725 L 345 725 Z"),
        line("M 336 668 L 464 668"),
    ]
    return svg(s, defs=f'<clipPath id="balloon"><path d="{shape}"/></clipPath>')


# --- Nature -------------------------------------------------------------------


def house():
    s = sun(670, 120, 50)
    s += [
        path("M 500 240 L 500 170 L 560 170 L 560 300 Z"),
        rect(190, 400, 420, 310),
        polygon([(140, 400), (400, 140), (660, 400)]),
        rect(350, 520, 100, 190),
        circle(430, 615, 9, fill="#000"),
        rect(230, 450, 90, 90),
        line("M 275 450 L 275 540"),
        line("M 230 495 L 320 495"),
        rect(480, 450, 90, 90),
        line("M 525 450 L 525 540"),
        line("M 480 495 L 570 495"),
        circle(400, 300, 38),
        line("M 40 710 L 760 710"),
        line("M 80 710 L 95 670 L 110 710 L 125 680 L 140 710"),
        line("M 650 710 L 665 675 L 680 710 L 695 665 L 710 710"),
    ]
    return svg(s)


def daisy():
    leaf = "M 397 640 Q 300 560 255 615 Q 315 685 397 662 Z"
    s = [
        line("M 400 480 Q 388 620 400 760"),
        path(leaf),
        path(mirror(leaf).replace("640", "590", 1).replace("662", "612")),
    ]
    for i in range(10):
        a = 360 / 10 * i
        r = math.radians(a)
        s.append(ellipse(400 + 120 * math.sin(r), 330 - 120 * math.cos(r), 42, 92,
                         rotate=a))
    s += [
        circle(400, 330, 72),
        dot(375, 318, 9),
        dot(425, 318, 9),
        smile(400, 348, 26, 18),
        line("M 40 760 L 760 760"),
    ]
    return svg(s)


def tree():
    s = [
        path("M 355 760 C 378 650 372 560 338 480 L 462 480 C 428 560 422 650 445 760 Z"),
        path(scallops(400, 320, 290, 210, 11, 1.12)),
        line("M 400 560 Q 440 520 470 470"),
    ]
    for x, y in [(270, 280), (400, 230), (530, 290), (330, 400), (480, 400),
                 (200, 380), (600, 380)]:
        s += [circle(x, y, 32), line(f"M {x} {y - 32} Q {x + 5} {y - 50} {x + 18} {y - 56}")]
    s += [
        line("M 40 760 L 760 760"),
        circle(620, 735, 24),
    ]
    return svg(s)


def rainbow():
    s = sun(150, 140, 62)
    for r in [330, 285, 240, 195, 150]:
        s.append(line(f"M {400 - r} 600 A {r} {r} 0 0 1 {400 + r} 600"))
    s += [
        cloud(165, 600, 1.25),
        cloud(635, 600, 1.25),
        line("M 30 740 Q 120 700 220 730 Q 330 765 420 730 Q 520 695 620 730 "
             "Q 700 755 770 735"),
    ]
    return svg(s)


def mushroom():
    s = [
        path("M 322 440 Q 300 620 290 700 L 510 700 Q 500 620 478 440 Z"),
        dot(365, 560, 12),
        dot(435, 560, 12),
        smile(400, 600, 30, 20),
        path("M 160 430 C 160 195 640 195 640 430 Q 400 475 160 430 Z"),
        circle(290, 340, 42),
        circle(430, 300, 44),
        circle(545, 370, 36),
        circle(390, 395, 26),
        line("M 60 700 L 740 700"),
        line("M 180 700 L 205 650 L 230 700 L 255 640 L 280 700"),
        line("M 520 700 L 545 645 L 570 700 L 595 655 L 620 700"),
    ]
    return svg(s)


# --- Parties ------------------------------------------------------------------


def cake():
    icing = ("M 250 330 L 550 330 L 550 385 Q 520 420 495 385 Q 470 420 445 385 "
             "Q 420 420 395 385 Q 370 420 345 385 Q 320 420 295 385 Q 270 420 250 385 Z")
    icing2 = ("M 170 470 L 630 470 L 630 525 Q 597 565 565 525 Q 532 565 500 525 "
              "Q 467 565 435 525 Q 402 565 370 525 Q 337 565 305 525 Q 272 565 240 525 "
              "Q 205 565 170 525 Z")
    s = [ellipse(400, 690, 300, 40)]
    for x in [300, 385, 470]:
        s += [
            path(f"M {x + 15} 160 Q {x - 12} 205 {x + 15} 225 Q {x + 42} 205 {x + 15} 160 Z"),
            rect(x, 230, 30, 100, 6),
            line(f"M {x} 270 L {x + 30} 255"),
            line(f"M {x} 305 L {x + 30} 290"),
        ]
    s += [
        rect(170, 470, 460, 210, 16),
        path(icing2),
        rect(250, 330, 300, 140, 14),
        path(icing),
    ]
    s += [circle(x, 610, 18) for x in [240, 330, 420, 510]]
    return svg(s)


def balloons():
    s = [
        line("M 270 425 Q 300 560 395 690"),
        line("M 530 405 Q 500 560 405 690"),
        line("M 400 545 Q 380 620 400 690"),
        path("M 400 690 C 330 640 300 720 400 700 C 500 720 470 640 400 690 Z"),
    ]
    for x, y, rx, ry in [(270, 280, 120, 145), (530, 260, 120, 145), (400, 400, 125, 148)]:
        s += [
            polygon([(x, y + ry - 5), (x - 18, y + ry + 22), (x + 18, y + ry + 22)]),
            ellipse(x, y, rx, ry),
            line(f"M {x - rx * 0.55} {y - ry * 0.35} Q {x - rx * 0.45} {y - ry * 0.7} "
                 f"{x - rx * 0.1} {y - ry * 0.75}"),
        ]
    return svg(s)


def gift():
    loop = "M 400 300 C 320 185 215 225 258 285 C 290 318 360 306 400 300 Z"
    s = [
        path(loop),
        path(mirror(loop)),
        rect(180, 380, 440, 340, 10),
        rect(370, 380, 60, 340),
        rect(150, 300, 500, 90, 12),
        rect(370, 300, 60, 90),
        circle(400, 298, 30),
    ]
    s += [star(x, y, 30) for x, y in [(270, 470), (520, 470), (270, 630), (520, 630)]]
    s += [line("M 60 720 L 740 720")]
    return svg(s)


def christmas_tree():
    def tier(top, bottom, half):
        return path(f"M 400 {top} L {400 + half} {bottom} Q 400 {bottom + 40} "
                    f"{400 - half} {bottom} Z")

    s = [
        rect(355, 660, 90, 100, 6),
        tier(400, 670, 260),
        tier(260, 500, 200),
        tier(150, 335, 140),
        line("M 220 590 Q 400 640 585 580"),
        line("M 265 445 Q 400 480 540 435"),
    ]
    s += [circle(x, y, 22) for x, y in
          [(300, 560), (420, 620), (520, 540), (340, 410), (460, 440), (390, 300)]]
    s.append(polygon(star_points(400, 135, 62)))
    s += [rect(560, 680, 120, 80, 6), line("M 620 680 L 620 760"),
          line("M 560 720 L 680 720")]
    return svg(s)


def pumpkin():
    s = [
        path("M 382 280 Q 372 205 400 175 Q 432 178 428 195 Q 410 215 420 280 Z"),
        line("M 420 200 Q 480 160 520 200 Q 470 215 430 210"),
        ellipse(285, 490, 175, 210),
        ellipse(515, 490, 175, 210),
        ellipse(400, 490, 160, 220),
        polygon([(305, 420), (365, 420), (335, 370)]),
        polygon([(435, 420), (495, 420), (465, 370)]),
        polygon([(385, 470), (415, 470), (400, 448)], fill="none"),
        path("M 280 540 Q 400 630 520 540 Q 400 580 280 540 Z"),
    ]
    return svg(s)


def star_page():
    s = [
        star(150, 150, 40),
        star(660, 660, 34),
        star(670, 130, 26),
        polygon(star_points(400, 420, 330, 0.45)),
        dot(355, 420, 16),
        dot(445, 420, 16),
        smile(400, 465, 40, 26),
        circle(320, 480, 22, fill="none"),
        circle(480, 480, 22, fill="none"),
    ]
    return svg(s)


PACKS = [
    ("pastello-animals", {"it": "Animali", "en": "Animals"}, "cat", [
        ("cat", "Cat", cat), ("dog", "Dog", dog), ("bunny", "Bunny", bunny),
        ("fish", "Fish", fish), ("butterfly", "Butterfly", butterfly),
        ("turtle", "Turtle", turtle), ("unicorn", "Unicorn", unicorn),
    ]),
    ("pastello-vehicles", {"it": "Veicoli", "en": "Vehicles"}, "car", [
        ("car", "Car", car), ("train", "Train", train),
        ("sailboat", "Sailboat", sailboat), ("airplane", "Airplane", airplane),
        ("rocket", "Rocket", rocket), ("balloon", "Hot air balloon", balloon),
    ]),
    ("pastello-nature", {"it": "Natura", "en": "Nature"}, "daisy", [
        ("house", "House", house), ("daisy", "Daisy", daisy),
        ("tree", "Apple tree", tree), ("rainbow", "Rainbow", rainbow),
        ("mushroom", "Mushroom", mushroom),
    ]),
    ("pastello-party", {"it": "Feste", "en": "Parties"}, "cake", [
        ("cake", "Birthday cake", cake), ("balloons", "Balloons", balloons),
        ("gift", "Gift", gift), ("christmas_tree", "Christmas tree", christmas_tree),
        ("pumpkin", "Pumpkin", pumpkin), ("star", "Star", star_page),
    ]),
]


def main():
    for pack_id, title, icon, items in PACKS:
        folder = f"{ROOT}/{pack_id}"
        os.makedirs(f"{folder}/coloring", exist_ok=True)
        for item_id, _, draw in items:
            with open(f"{folder}/coloring/{item_id}.svg", "w") as out:
                out.write(draw())
        manifest = {
            "id": pack_id,
            "version": 1,
            "kind": "coloring",
            "title": title,
            "icon": icon,
            "author": "Pastello project",
            "license": "CC0-1.0",
            "source": "https://github.com/pegperego/pastello-app",
            "items": [
                {"id": item_id, "file": f"coloring/{item_id}.svg", "name": name}
                for item_id, name, _ in items
            ],
        }
        with open(f"{folder}/pack.json", "w") as out:
            out.write(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
