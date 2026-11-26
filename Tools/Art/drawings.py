"""Original MiniFarm drawings. Every motif is drawn on the same 96-unit artboard."""

INK = "#493b31"
CREAM = "#ffefd1"
WHITE = "#fff9e8"
OAT = "#e6c69c"
WOOD = "#be8153"
BARK = "#875a41"
RUST = "#bd5e45"
RED = "#e77d61"
PINK = "#efb6a6"
GOLD = "#efb649"
HONEY = "#ffdc81"
LEAF = "#76a370"
PINE = "#426e59"
MINT = "#b8cf91"
TEAL = "#5e9b98"
SKY = "#acd6d5"
SLATE = "#87969a"
PLUM = "#865674"
LILAC = "#d4b6cd"


def path(d, fill, stroke=INK, width=3.2):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'


def line(d, color=INK, width=3.2):
    return path(d, "none", color, width)


def ellipse(x, y, rx, ry, fill, stroke=INK, width=3.2):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'


def dot(x, y, r, color):
    return ellipse(x, y, r, r, color, "none")


def rect(x, y, w, h, r, fill):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{INK}" stroke-width="3.2"/>'


def group(drawing, transform):
    return f'<g transform="{transform}">{drawing}</g>'


def place(drawing, x, y, scale):
    return group(drawing, f"translate({x} {y}) scale({scale})")


def turn(drawing, angle, x=48, y=48):
    return group(drawing, f"rotate({angle} {x} {y})")


def svg(drawing):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">'
        '<g stroke-linejoin="round" stroke-linecap="round">'
        f'{drawing}</g></svg>\n'
    )


def eye(x, y, r=3.4):
    return dot(x, y, r, INK) + dot(x-.8, y-1.1, .95, WHITE)


def smile(x=48, y=63):
    return group(line("M-5 0 Q0 6 6 0", INK, 2.5), f"translate({x} {y})")


def leaf(x, y, angle=0, size=1, color=LEAF):
    blade = path("M0 0 Q-18 -3 -15 -21 Q2 -18 0 0Z", color)
    return group(blade, f"translate({x} {y}) rotate({angle}) scale({size})")


def sprig(x, y, size=1):
    return place(line("M0 0 Q3 -12 1 -22", PINE, 4) + leaf(1, -7) + leaf(2, -14, 70, .88, MINT), x, y, size)


def tuft():
    return path("M40 42 Q17 30 20 19 Q23 13 30 20 L41 30 Q30 7 38 6 Q43 5 48 25 Q52 7 59 10 Q66 13 53 36Z", LEAF)


def flower(x=48, y=45, scale=1, petals=CREAM, center=GOLD):
    shape = "".join(turn(ellipse(0, -13, 9, 13, petals), a, 0, 0) for a in range(0, 360, 72))
    return place(shape + ellipse(0, 0, 9, 9, center), x, y, scale)


def wheat(x=48, y=85, size=1, angle=0):
    body = line("M0 0 Q0 -30 0 -59", BARK, 4)
    for y0 in [-16, -31, -46]:
        body += place(path("M0 0 Q-16 -1 -15 -17 Q-1 -16 0 0Z", GOLD), 0, y0, 1)
        body += place(path("M0 -4 Q15 -4 16 -21 Q1 -20 0 -4Z", HONEY), 0, y0, 1)
    body += path("M0 -59 Q-9 -70 0 -81 Q10 -70 0 -59Z", HONEY)
    return group(body, f"translate({x} {y}) rotate({angle}) scale({size})")


def animals():
    a = {}
    # Pelle's crooked ears and white blaze are visible even without his scarf.
    a["dog"] = (
        path("M26 68 Q45 78 69 67 L72 76 L54 90 Q47 92 28 80Z", TEAL)
        + path("M22 45 Q21 28 27 8 Q31 2 46 27 Q56 22 68 30 Q80 38 77 57 Q74 77 53 80 Q30 81 22 65Z", WOOD)
        + path("M27 28 L30 14 L38 29Z", PINK, "none")
        + path("M46 29 Q54 34 52 47 Q49 55 60 57 Q74 55 72 64 Q64 78 48 78 Q32 77 27 63 Q25 54 36 54 Q44 52 43 39Z", CREAM, "none")
        + path("M63 31 Q70 18 81 31 Q93 44 82 53 Q74 61 67 45Z", BARK)
        + eye(36, 46) + eye(60, 46) + path("M43 57 Q48 54 54 57 Q56 61 49 65 Q43 64 43 57Z", INK, "none")
        + line("M49 65 Q49 72 42 69 M49 65 Q52 70 57 66", INK, 2.4)
    )
    a["cat"] = (
        path("M16 55 Q17 44 22 38 L22 14 Q23 8 41 28 Q49 25 58 28 Q73 10 77 13 L78 42 Q88 62 72 74 Q48 93 25 77 Q12 68 16 55Z", OAT)
        + path("M26 24 L27 38 L35 32Z M71 23 L64 32 L73 37Z", PINK, "none")
        + path("M38 30 L43 41 L45 29 M50 28 L54 40 L58 29", BARK, "none")
        + eye(34, 51) + eye(63, 51) + path("M43 62 Q48 59 53 62 L49 67Z", RUST)
        + line("M48 66 Q46 73 40 69 M49 66 Q52 71 57 67 M25 59 L8 56 M26 66 L9 69 M71 59 L87 55 M70 66 L86 69", INK, 2.4)
    )
    a["chicken"] = (
        path("M28 52 Q36 42 39 34 Q41 20 55 20 Q71 20 72 39 Q71 45 73 53 Q78 72 58 79 Q32 89 19 68 Q10 54 10 42 Q17 42 23 47 Q17 31 22 31 Q27 32 32 41Z", CREAM)
        + path("M40 25 Q33 14 40 13 Q44 13 46 18 Q45 7 52 8 Q58 9 55 17 Q63 9 66 16 Q67 23 58 26Z", RED)
        + path("M71 36 L85 42 L71 48Z", GOLD) + path("M73 49 Q81 57 74 60 Q65 60 69 49Z", RED)
        + eye(61, 35) + path("M26 53 Q35 46 50 52 Q46 70 31 67 Q25 64 26 53Z", OAT)
        + line("M41 80 L40 87 L33 88 M54 80 L55 87 L62 87", BARK, 3.2)
    )
    a["cow"] = (
        path("M30 32 Q17 30 23 12 Q30 23 39 21 M57 22 Q67 22 72 12 Q76 28 64 32", HONEY)
        + path("M32 31 Q15 20 7 32 Q12 48 29 47 M62 31 Q79 20 89 32 Q84 48 67 47", OAT)
        + path("M23 41 Q23 21 46 21 Q71 17 74 42 L70 66 Q65 82 47 82 Q27 81 24 65Z", CREAM)
        + path("M23 42 Q25 25 40 25 Q50 27 43 38 Q33 40 40 48 Q39 58 25 55Z", BARK, "none")
        + eye(34, 45) + eye(60, 45) + ellipse(48, 66, 25, 15, PINK)
        + dot(36, 64, 3, BARK) + dot(59, 64, 3, BARK) + smile(49, 70)
    )
    wool = path("M17 54 Q4 47 13 36 Q10 24 23 23 Q29 9 42 16 Q55 5 63 18 Q79 15 81 30 Q94 38 83 48 Q88 62 72 66 Q65 79 52 72 Q38 84 29 69 Q14 71 17 54Z", CREAM)
    a["sheep"] = (wool + path("M32 43 Q19 35 11 47 Q18 61 32 57 M65 43 Q79 36 85 48 Q78 59 65 57", BARK)
                  + path("M29 45 Q48 31 66 45 Q67 76 48 80 Q30 77 29 45Z", OAT)
                  + path("M27 40 Q27 28 38 30 Q47 20 55 29 Q69 25 70 39 Q65 47 57 42 Q50 52 42 44 Q32 49 27 40Z", WHITE)
                  + eye(38, 52) + eye(57, 52) + path("M43 61 Q48 58 53 61 L48 66Z", INK, "none") + smile(48, 69))
    a["pig"] = (path("M19 48 Q13 37 12 19 Q23 13 36 29 Q50 24 61 29 Q74 14 85 20 Q84 39 76 45 Q86 73 65 80 Q44 92 23 77 Q13 67 19 48Z", PINK)
                + path("M18 25 L22 40 L30 31Z M77 26 L67 32 L75 39Z", RUST, "none")
                + eye(34, 49) + eye(61, 49) + ellipse(48, 64, 20, 13, RED)
                + ellipse(40, 64, 2.5, 4, BARK, "none") + ellipse(56, 64, 2.5, 4, BARK, "none"))
    a["duck"] = (path("M13 51 Q22 59 37 53 Q44 47 42 38 Q38 19 53 15 Q72 9 75 28 Q77 40 66 47 Q62 50 73 55 Q82 69 63 79 Q35 91 17 71 Q11 64 13 51Z", HONEY)
                 + path("M73 28 Q80 33 89 31 Q90 42 73 43 Q69 38 73 28Z", GOLD)
                 + path("M24 59 Q42 51 54 59 Q48 74 33 71Z", GOLD) + eye(62, 28))
    a["goat"] = (path("M30 32 Q13 22 22 7 Q26 22 39 19 M56 20 Q70 19 73 7 Q82 24 65 33", OAT)
                 + path("M35 36 Q20 30 9 38 Q9 48 28 51 M62 36 Q77 30 88 39 Q83 50 66 51", WOOD)
                 + path("M38 67 L35 80 L44 77 L46 89 Q55 87 60 72Z", CREAM)
                 + path("M28 36 Q32 23 46 24 Q66 20 70 38 Q68 52 59 67 Q50 79 40 69 Q31 58 28 36Z", CREAM)
                 + path("M35 31 Q47 19 58 29 L49 41Z", OAT, "none")
                 + eye(37, 46) + eye(60, 46) + path("M42 58 Q49 54 55 58 Q51 66 46 64Z", BARK) + smile(49, 67))
    a["horse"] = (path("M36 34 Q31 24 33 9 Q43 9 48 24 Q61 13 67 12 L69 29 Q81 38 81 65 L66 79 L54 62Z", BARK)
                  + path("M39 29 Q33 15 36 10 Q45 13 49 28 Q56 21 63 16 Q67 23 62 34 Q68 47 58 63 L45 80 Q34 90 21 80 Q10 72 19 57 L31 42Z", WOOD)
                  + path("M40 28 Q47 22 60 27 Q57 38 47 42Z", BARK)
                  + path("M31 51 Q36 45 44 49 L33 70 L23 69Z", CREAM, "none")
                  + eye(45, 44) + ellipse(31, 70, 15, 12, OAT) + dot(24, 68, 2.8, INK) + line("M30 77 Q36 79 40 72", INK, 2.4))
    a["rabbit"] = (path("M30 53 Q18 32 22 13 Q26 2 32 10 Q42 21 43 44 M49 45 Q46 19 56 8 Q63 1 66 12 Q68 29 58 49", OAT)
                   + line("M27 16 Q27 26 34 39 M59 13 Q57 24 54 34", PINK, 4)
                   + path("M18 65 Q19 43 41 40 Q63 36 75 55 Q86 78 64 84 Q41 91 24 79 Q17 74 18 65Z", OAT)
                   + eye(34, 58) + eye(59, 58) + ellipse(46, 72, 14, 9, CREAM, "none")
                   + path("M40 66 Q46 63 51 66 L46 71Z", RUST) + smile(46, 73))
    a["bee"] = (ellipse(39, 34, 12, 19, SKY) + turn(ellipse(59, 31, 11, 19, CREAM), 29, 59, 31)
                + ellipse(44, 56, 32, 22, GOLD) + path("M22 41 Q17 55 24 72 L33 76 Q25 56 34 36Z", BARK, "none")
                + path("M45 35 Q35 57 45 77 L54 76 Q46 57 55 37Z", BARK, "none")
                + line("M65 44 Q73 32 76 31 M72 47 Q83 40 86 41", INK) + dot(76, 30, 3.2, INK) + dot(86, 41, 3.2, INK)
                + eye(63, 53) + smile(64, 61))
    a["bird"] = (path("M10 43 L29 49 Q33 46 37 34 Q42 16 58 18 Q76 18 76 37 Q80 57 65 69 Q48 84 27 67 Q17 61 10 43Z", TEAL)
                 + path("M75 33 L88 40 L75 45Z", GOLD) + eye(62, 32)
                 + path("M28 52 Q40 44 56 49 Q50 65 36 63Z", SKY) + line("M46 74 L42 85 M57 73 L57 83"))
    a["frog"] = (ellipse(48, 62, 34, 18, LEAF) + ellipse(31, 40, 15, 18, MINT) + ellipse(65, 40, 15, 18, MINT)
                 + path("M22 51 Q47 38 73 51 Q85 68 57 77 Q33 83 17 66 Q13 59 22 51Z", MINT)
                 + eye(32, 38, 5) + eye(64, 38, 5) + line("M30 59 Q48 74 65 58"))
    a["butterfly"] = (path("M47 46 Q29 10 13 15 Q1 23 15 45 L27 53 Q9 54 18 72 Q31 87 47 58Z", GOLD)
                      + path("M50 46 Q65 12 81 14 Q96 20 81 44 L68 53 Q88 53 79 71 Q65 86 50 58Z", RED)
                      + ellipse(24, 34, 6, 9, CREAM) + ellipse(72, 34, 6, 9, CREAM)
                      + line("M47 41 Q39 26 35 28 M50 41 Q56 26 61 28") + ellipse(48, 53, 4, 18, BARK))
    a["ladybug"] = (line("M58 30 L60 17 M68 35 L81 29") + ellipse(61, 36, 14, 13, BARK)
                    + turn(ellipse(44, 55, 25, 30, RED), 30, 44, 55) + line("M57 31 L31 77")
                    + dot(37, 42, 5, INK) + dot(27, 56, 4, INK) + dot(56, 55, 5, INK) + dot(45, 70, 4, INK))
    a["hedgehog"] = (path("M11 67 Q9 49 19 34 L19 42 L30 22 L31 31 L45 16 L45 26 L60 20 L61 29 L73 29 Q76 45 72 64Z", BARK)
                     + path("M12 65 Q20 77 44 77 Q65 78 85 57 Q69 60 62 43 Q48 37 40 56 Q32 72 12 65Z", OAT)
                     + eye(63, 56) + dot(84, 57, 4, INK) + line("M23 54 L28 43 M39 47 L45 35", WOOD))
    a["squirrel"] = (path("M42 71 Q25 84 15 66 Q0 42 18 22 Q34 4 43 22 Q49 36 33 38 Q23 40 26 49 Q27 57 37 53Z", RUST)
                     + path("M36 78 Q24 65 39 48 L51 40 L51 20 Q58 21 63 33 L73 22 L74 40 Q84 46 85 52 L71 59 Q74 78 61 80Z", WOOD)
                     + eye(69, 45) + dot(84, 52, 3, INK) + ellipse(53, 66, 8, 10, OAT))
    a["fox"] = (path("M18 45 L15 15 Q25 13 40 32 Q49 28 57 32 Q72 14 80 14 L77 46 Q83 53 85 57 Q67 62 51 82 Q48 87 44 81 Q29 65 10 57Z", RUST)
                + path("M21 22 L25 40 L33 32Z M74 22 L63 33 L72 40Z", BARK, "none")
                + path("M15 56 Q36 48 48 69 Q59 49 81 56 L50 80 L45 80Z", CREAM, "none")
                + eye(34, 49) + eye(61, 49) + ellipse(48, 72, 7, 5, INK))
    return a


def crops():
    c = {}
    c["carrot"] = (turn(tuft(), 22) + path("M49 31 Q63 24 70 38 Q78 53 23 84 Q18 87 20 79 Q30 42 49 31Z", "#eaa05a")
                   + line("M42 42 L50 46 M54 54 L61 56 M29 64 L35 67", BARK, 2.6))
    c["radish"] = (sprig(51, 43, 1.15) + path("M24 50 Q23 33 47 35 Q67 32 73 48 Q77 68 52 74 Q44 76 44 84 Q36 82 38 74 Q20 67 24 50Z", RED)
                   + path("M25 59 Q36 69 48 67 Q58 67 68 62 Q62 71 51 73 Q43 75 43 81 Q39 79 40 73 Q28 69 25 59Z", CREAM, "none")
                   + line("M32 49 Q33 43 40 42", CREAM))
    c["lettuce"] = (path("M21 68 Q6 58 15 46 Q6 30 24 27 Q29 12 42 21 Q54 10 65 24 Q84 21 81 39 Q94 47 80 61 Q83 78 62 78 Q44 89 21 68Z", LEAF)
                    + path("M22 47 Q33 50 36 61 Q32 38 43 32 Q59 34 57 54 Q66 39 77 44 Q75 69 51 77 Q35 75 22 47Z", MINT)
                    + line("M50 71 L45 48", PINE))
    c["pea"] = (path("M16 68 Q23 31 66 26 Q81 24 82 15 Q91 37 75 57 Q50 85 17 78 Q10 75 16 68Z", LEAF)
                + path("M18 69 Q37 42 75 32 Q67 65 23 75Z", PINE)
                + "".join(ellipse(x, y, r, r, MINT) for x, y, r in [(30,65,7),(45,55,8),(61,44,7)]))
    c["potato"] = (path("M15 60 Q12 44 33 32 Q48 17 66 23 Q88 28 81 51 Q79 64 60 69 Q39 86 24 77 Q16 72 15 60Z", OAT)
                   + line("M26 53 Q28 49 32 51 M56 34 Q60 32 61 36 M50 63 Q53 60 56 61", BARK)
                   + dot(69, 48, 2.4, BARK))
    c["strawberry"] = (path("M17 45 Q18 27 42 30 Q69 20 77 41 Q81 61 52 84 Q48 88 42 83 Q19 66 17 45Z", RED)
                       + path("M47 35 L32 38 L36 29 L25 25 L42 24 L48 13 L53 24 L69 24 L60 31 L63 39Z", LEAF)
                       + line("M29 46 l1 3 M45 45 l1 3 M64 44 l-1 3 M37 58 l1 3 M55 57 l-1 3 M47 70 l1 2", CREAM, 3))
    c["tomato"] = (path("M16 52 Q13 30 36 28 Q47 26 52 29 Q75 23 81 45 Q89 71 61 80 Q44 86 28 75 Q17 67 16 52Z", RED)
                   + path("M49 30 Q44 20 49 13 L54 14 L52 26 L68 21 L60 31 L70 38 L54 35 L44 45 L43 33 L28 34 L39 27Z", LEAF)
                   + line("M25 54 Q23 44 31 40", CREAM))
    c["corn"] = (turn(ellipse(49, 45, 18, 32, HONEY), 15) + line("M51 20 L36 64 M61 26 L48 68 M41 31 L65 38 M36 44 L60 50 M34 55 L55 61", WOOD, 2.2)
                 + path("M36 79 Q14 63 18 37 Q27 41 37 56 L44 68 Q53 48 78 39 Q72 74 42 83Z", LEAF)
                 + line("M41 77 Q55 62 65 54", PINE, 2.2))
    c["sunflower"] = (line("M48 42 L49 86", PINE, 5) + leaf(47, 77, -12, .95) + leaf(50, 66, 86, .75)
                      + "".join(turn(ellipse(48, 20, 8, 13, GOLD), n, 48, 38) for n in range(0,360,45))
                      + ellipse(48, 38, 17, 17, BARK) + dot(43, 35, 2, OAT) + dot(53, 40, 2, OAT))
    c["apple"] = (leaf(49,31,83,.85) + line("M46 35 Q43 21 48 12", BARK, 5)
                  + path("M47 36 Q31 22 19 37 Q5 56 27 78 Q37 87 47 81 Q62 88 76 71 Q90 49 75 35 Q64 25 47 36Z", RED)
                  + line("M24 51 Q24 44 31 40", CREAM, 4))
    c["wheat"] = wheat(39, 86, .78, -15) + wheat(50, 88, 1, 14)
    c["pumpkin"] = (path("M44 35 Q43 22 52 14 L61 17 Q50 24 53 36Z", PINE)
                    + ellipse(47, 56, 35, 25, "#dfa063") + ellipse(48, 56, 22, 27, "#efac68") + ellipse(48, 56, 9, 26, "#f7bb76"))
    c["kale"] = (path("M28 75 Q12 73 20 62 Q6 54 18 45 Q11 32 25 31 Q21 19 36 22 Q40 10 49 20 Q61 8 65 21 Q81 19 76 32 Q89 33 79 47 Q88 59 70 64 Q74 78 56 74 L41 87Z", PINE)
                 + line("M40 81 Q51 57 55 27 M46 65 L32 53 M50 55 L66 43 M53 41 L42 33", MINT, 3.6))
    c["chives"] = (path("M38 83 Q30 50 14 29 Q37 36 44 62 Q41 30 36 14 Q51 21 53 59 Q56 22 68 10 Q62 37 61 61 Q70 35 83 29 Q68 57 59 84Z", LEAF)
                   + path("M36 70 L62 67 L62 74 L38 79Z", HONEY))
    return c


def tools():
    return {
        "can": (ellipse(72, 43, 14, 16, TEAL) + ellipse(73, 43, 8, 9, WHITE)
                + path("M33 56 L15 42 L12 45 L28 72 Q31 79 42 81Z", TEAL)
                + path("M34 39 Q47 33 65 39 L72 72 Q70 84 42 81 Q28 80 29 70Z", TEAL)
                + ellipse(49, 39, 16, 5, SKY) + turn(ellipse(14, 43, 5, 10, SKY), 38, 14, 43)
                + path("M42 56 Q51 53 58 55 L60 68 Q50 72 41 67Z", SKY, "none")),
        "bucket": (line("M20 43 C17 -1 77 -1 77 43", INK, 5) + path("M17 40 L26 75 Q46 89 69 76 L80 40Z", TEAL)
                   + ellipse(48, 41, 32, 9, SKY) + line("M31 56 L34 69", SKY, 4) + dot(73, 46, 3, INK)),
        "brush": (turn(path("M15 51 L16 66 Q20 71 24 64 Q28 73 32 65 Q37 74 41 65 Q46 73 50 63 L51 51Z", OAT)
                       + path("M13 42 Q14 35 24 35 L47 36 Q54 36 59 41 L79 39 Q89 39 88 46 Q88 52 81 53 L53 52 Q40 60 16 54 Q12 52 13 42Z", WOOD)
                       + line("M20 45 Q32 40 43 44", OAT, 3) + dot(80, 46, 2.5, INK), -22)),
        "shears": (path("M44 52 L28 13 Q26 9 23 16 Q22 38 38 61Z", SKY)
                   + path("M39 53 L69 17 Q75 10 72 21 Q65 44 48 60Z", SLATE)
                   + line("M43 54 L56 68 M43 56 L31 68", INK, 6)
                   + turn(ellipse(28,72,10,13,RED), 24,28,72) + ellipse(28,72,4,6,CREAM)
                   + turn(ellipse(58,72,10,13,TEAL), -24,58,72) + ellipse(58,72,4,6,CREAM) + dot(43,54,3,GOLD)),
        "basket": basket(),
    }


def basket(content=""):
    return (line("M21 52 C19 7 77 7 75 52", INK, 8) + line("M21 52 C19 7 77 7 75 52", OAT, 3)
            + content + path("M12 47 Q48 52 84 47 L73 76 Q70 84 49 84 Q27 84 23 78Z", WOOD)
            + path("M12 45 Q46 49 83 45 L82 53 Q46 58 14 53Z", HONEY)
            + line("M24 64 Q48 69 74 63 M37 60 L40 76 M58 60 L55 77", OAT, 2.8))


def egg(x=48, y=48, size=1, shell=CREAM):
    return place(path("M-22 7 C-22 -9 -10 -32 0 -32 C12 -32 23 -7 23 8 C23 36 -21 38 -22 7Z", shell)
                 + line("M-13 -2 Q-12 -12 -7 -16", WHITE, 3.5), x, y, size)


def bottle(liquid, cap=TEAL, badge=""):
    return (path("M36 14 L59 14 L59 32 Q60 37 66 42 Q71 47 70 58 L70 78 Q69 85 61 85 L34 85 Q25 84 25 77 L25 55 Q25 46 33 38 Q37 34 36 27Z", WHITE)
            + path("M28 53 Q37 48 49 52 Q58 55 67 50 L67 77 Q67 82 60 82 H35 Q28 82 28 77Z", liquid, "none")
            + rect(34, 11, 28, 9, 3, cap) + badge + line("M32 49 L32 62", WHITE, 2.5))


def roll():
    return (path("M18 52 Q17 37 40 25 Q65 14 77 35 Q86 51 73 62 Q56 80 36 80Z", HONEY)
            + ellipse(36, 58, 21, 23, GOLD)
            + line("M24 62 Q20 44 35 43 Q49 43 49 57 Q49 69 37 70 Q27 68 29 58 Q32 51 38 55 Q42 60 37 62", BARK, 2.8)
            + line("M52 32 Q66 35 70 54 M64 27 Q73 31 77 39", WOOD, 3))


def sack(color, badge):
    return (path("M29 17 Q45 20 62 15 L57 29 Q60 35 68 43 Q78 56 76 75 Q74 84 64 84 L29 84 Q17 83 18 69 Q18 52 30 38 L36 30Z", color)
            + line("M33 30 L59 28", BARK, 5) + badge)


def jar(fill, lid, badge=""):
    return (rect(22, 29, 52, 56, 11, fill) + rect(20, 16, 56, 15, 4, lid)
            + line("M30 20 L30 26 M39 20 L39 26 M48 20 L48 26 M57 20 L57 26 M66 20 L66 26", BARK, 2)
            + badge + line("M28 42 L28 52", CREAM, 3))


def drop():
    return path("M47 12 Q45 25 29 47 Q16 67 32 78 Q52 92 68 73 Q77 60 63 40Z", SKY) + line("M33 61 Q31 68 39 71", WHITE)


def products(c, a):
    p = {}
    p["egg"] = egg(48, 49, 1.15)
    p["duckegg"] = egg(46, 49, .99, MINT) + dot(34,56,2.3,BARK) + dot(45,64,2.4,BARK) + dot(51,51,2,BARK)
    p["milk"] = bottle(CREAM, TEAL, ellipse(49,61,11,9,TEAL) + path("M42 62 Q44 55 51 58 Q56 62 49 66Z", CREAM, "none"))
    p["goatmilk"] = bottle(CREAM, LEAF, place(a["goat"], 27,40,.46))
    p["wool"] = (path("M17 53 Q6 40 20 32 Q17 18 35 21 Q44 8 56 20 Q73 15 75 30 Q92 34 82 49 Q93 63 75 67 Q73 84 56 77 Q44 90 32 76 Q15 78 17 64 Q7 61 17 53Z", CREAM)
                 + line("M27 52 Q20 43 30 39 Q44 31 44 45 Q43 52 35 49 M53 63 Q64 69 68 59", WOOD))
    p["compost"] = (path("M10 70 Q13 60 23 58 Q22 47 36 45 Q40 30 55 37 Q69 33 72 47 Q84 52 85 69 Q48 85 10 70Z", BARK)
                    + sprig(49,43,.72) + dot(31,61,3,OAT) + dot(60,54,2.5,OAT) + line("M48 67 l7 -2", WOOD))
    p["feather"] = (path("M26 70 Q20 51 35 33 Q54 8 77 11 Q80 31 64 47 L57 47 L60 51 Q47 69 26 70Z", CREAM)
                    + line("M17 85 Q36 60 66 25", BARK, 4) + line("M36 60 L32 46 M45 50 L58 48 M51 43 L49 32", WOOD, 2.4))
    comb = lambda x,y: place(path("M0 -13 L12 -7 L12 7 L0 14 L-12 7 L-12 -7Z", HONEY),x,y,1)
    p["honeycomb"] = "".join(comb(x,y) for x,y in [(36,28),(60,28),(24,48),(48,48),(72,48),(36,69),(60,69)])
    p["hay"] = roll()
    p["feed"] = sack(OAT, wheat(45,76,.49,12))
    p["flour"] = sack(CREAM, path("M29 68 Q32 61 38 60 Q42 45 48 51 Q54 51 59 63 Q64 62 67 69Z", WHITE))
    p["bread"] = (path("M11 61 Q9 41 37 30 Q64 18 79 31 Q90 42 81 56 Q71 73 42 78 Q17 82 11 61Z", WOOD)
                  + line("M29 38 Q38 38 43 48 M44 31 Q53 32 58 43 M59 29 Q69 31 71 38", HONEY, 6))
    p["cake"] = (path("M15 45 L51 24 L82 46 L80 73 L19 78Z", OAT) + path("M17 59 L79 55 L80 63 L18 68Z", RED)
                 + path("M14 43 L51 24 L82 44 Q83 54 75 54 Q70 60 66 52 L38 55 Q34 68 28 56 L17 57Z", CREAM)
                 + place(c["strawberry"],30,6,.40))
    p["applejuice"] = bottle(GOLD, RUST, place(c["apple"],30,44,.39))
    p["butter"] = (ellipse(48,68,39,13,SKY) + path("M20 47 L39 35 L74 38 L74 62 L55 72 L21 66Z", HONEY)
                   + path("M21 48 L55 52 L73 39 M55 52 L55 68", "none", BARK, 2.7) + line("M36 42 L48 43", CREAM, 3))
    p["cheese"] = (path("M12 47 L61 23 Q76 25 83 38 L83 66 L16 78Z", HONEY) + path("M13 47 L82 37 L82 66 L16 78Z", GOLD)
                   + ellipse(32,61,5,4,HONEY) + ellipse(60,56,7,5,HONEY) + ellipse(67,30,4,2,WOOD,"none"))
    p["goatcheese"] = (ellipse(49,69,37,10,OAT) + path("M17 47 Q17 35 53 34 Q78 33 78 48 L77 61 Q64 74 36 71 Q18 68 17 61Z", CREAM)
                       + ellipse(48,46,30,11,WHITE) + leaf(52,44,-20,.47,LEAF) + leaf(53,44,90,.44,MINT))
    p["jam"] = jar(RED, CREAM, place(c["strawberry"],29,39,.43))
    p["icecream"] = (path("M25 44 L69 44 L52 83 Q49 91 45 84Z", OAT) + line("M32 51 L53 73 M44 48 L60 62 M60 49 L39 69", WOOD,2.5)
                     + path("M19 45 Q17 35 25 31 Q25 16 44 15 Q64 11 70 30 Q82 37 73 48 Q67 54 59 46 Q50 60 40 48 Q26 57 19 45Z", PINK))
    p["honey"] = jar(GOLD, HONEY, comb(48,56))
    p["beanie"] = (ellipse(47,16,9,9,CREAM) + path("M16 65 Q16 26 46 21 Q75 22 80 64Z", TEAL)
                   + line("M31 60 Q31 38 41 29 M63 60 Q62 39 53 29", SKY) + rect(13,60,70,16,6,SKY)
                   + line("M24 65 v6 M35 65 v6 M47 65 v6 M59 65 v6 M70 65 v6", TEAL, 3))
    return p


def wheel(x, y, r=12):
    return ellipse(x,y,r,r,INK) + ellipse(x,y,r*.53,r*.53,OAT,BARK,2) + dot(x,y,r*.18,BARK)


def machines():
    m = {}
    m["tractor"] = (path("M13 56 L20 45 L23 22 L49 22 L54 44 L75 46 Q83 47 82 62 L76 67 L20 67Z", LEAF)
                    + path("M28 26 L44 26 L47 43 L25 43Z", SKY) + rect(20,16,32,8,3,PINE)
                    + line("M68 45 L68 29 L73 27", INK, 5) + wheel(28,66,18) + wheel(72,68,12)
                    + line("M59 51 L59 59 M65 52 L65 57", CREAM,2.4))
    m["combine"] = (path("M10 33 L42 32 L47 18 L63 18 L69 47 L69 58 L81 62 L74 72 L19 69 Q12 61 10 33Z", GOLD)
                    + path("M47 24 L59 24 L63 44 L43 44Z", SKY) + line("M15 35 L13 21 L33 18", BARK, 5)
                    + wheel(25,70,10) + wheel(52,66,14) + path("M64 65 L78 51 L87 61 L82 73 L65 76Z", RED)
                    + line("M75 56 L82 69 M68 61 L75 74", BARK, 2.8))
    m["trailer"] = (path("M13 32 L86 32 L77 59 L26 62Z", WOOD) + rect(12,27,75,8,3,OAT)
                    + line("M22 43 L78 43 M32 38 L37 55 M61 38 L60 54", BARK)
                    + line("M8 68 L32 62 L77 62", INK, 5) + wheel(43,70,11) + wheel(69,70,11))
    m["plow"] = (line("M10 39 L77 39 M30 41 L37 61 M57 41 L62 61", BARK, 7)
                 + path("M41 49 Q42 66 19 65 Q26 79 45 72 Q54 67 55 57Z", SKY)
                 + path("M68 48 Q69 65 48 65 Q55 78 73 70 Q80 65 83 54Z", SLATE) + wheel(74,37,9))
    m["seeder"] = (path("M13 26 L80 26 L69 51 L27 52Z", RED) + rect(12,21,69,8,3,OAT)
                   + line("M25 54 L22 66 M42 53 L42 69 M57 52 L57 64 M73 48 L75 65", BARK, 6)
                   + wheel(24,67,9) + wheel(73,67,9) + dot(42,78,3.5,GOLD) + dot(56,75,3.5,GOLD))
    m["watertank"] = (line("M10 65 L78 65", BARK, 6) + rect(18,29,60,32,15,TEAL) + rect(44,21,17,8,3,OAT)
                      + ellipse(70,45,11,16,SKY) + place(drop(),27,34,.30) + wheel(35,71,10) + wheel(68,71,10))
    m["mower"] = (line("M13 31 L38 47 L66 53", BARK,7) + path("M21 54 L71 44 L84 57 L27 69Z", LEAF)
                  + path("M27 69 L84 57 L81 69 L72 66 L66 75 L58 71 L50 78 L42 75 L35 82Z", SKY)
                  + wheel(31,50,9))
    m["baler"] = (path("M12 35 L47 26 Q64 25 68 42 L68 59 L52 67 L22 63Z", RED)
                  + path("M10 58 L24 51 L30 66 L13 71Z", OAT) + wheel(47,68,13) + place(roll(),51,45,.47))
    m["loader"] = (wheel(25,72,11) + path("M15 61 L30 36 L42 35 L65 56 L73 40 L82 42 L77 67 L61 70 L36 47 L28 66Z", GOLD)
                   + path("M61 63 Q71 68 88 56 Q89 78 66 80 L56 73Z", SLATE) + dot(35,43,4,BARK))
    m["potatodigger"] = (line("M11 46 L34 48 L62 32", BARK,6)
                         + path("M14 63 L58 36 L79 42 L33 73Z", OAT) + line("M25 64 l40 -24 M32 68 l41 -25", BARK,2.8)
                         + wheel(69,51,10) + ellipse(53,72,8,6,WOOD) + ellipse(73,77,7,5,WOOD))
    m["snowplow"] = (path("M12 51 L46 50 L62 34 L69 39 L54 62 L15 64Z", GOLD)
                     + path("M52 36 L80 23 Q72 44 86 65 L58 78 Q40 62 52 36Z", SKY)
                     + line("M58 69 L78 60", SLATE,3))
    m["carriage"] = (path("M12 40 L18 63 L52 69 L74 58 L85 39 L78 36 L65 50 L44 54 L39 40Z", WOOD)
                     + path("M13 39 Q11 16 33 15 Q54 15 56 38 Q33 33 13 39Z", TEAL)
                     + line("M18 39 L23 53 M48 37 L46 52", BARK,4) + wheel(26,72,12) + wheel(66,70,12))
    return m


def fence():
    return (rect(6,55,83,8,2,OAT) + rect(6,70,82,7,2,OAT)
            + path("M15 83 L15 51 L21 44 L27 51 L27 83Z M70 83 L70 51 L76 44 L82 51 L82 83Z", WOOD))


def tree(apples=False):
    trunk = path("M38 85 Q44 66 42 54 L35 42 L41 39 L48 49 L57 36 L62 39 L54 58 Q53 72 60 85Z", WOOD)
    crown = path("M18 52 Q7 45 16 31 Q13 18 29 19 Q35 5 49 14 Q61 4 71 18 Q89 17 82 33 Q94 50 76 56 Q64 66 51 57 Q33 66 29 56 Q23 57 18 52Z", LEAF)
    fruit = "".join(ellipse(x,y,5,5,RED,BARK,2) for x,y in [(30,34),(56,24),(68,43),(44,49)])
    return trunk + crown + (fruit if apples else line("M24 35 Q24 27 32 27", MINT, 4))


def coop():
    return (line("M24 69 L23 83 M67 68 L69 82", BARK, 6) + path("M15 40 L45 20 L76 39 L74 69 L17 70Z", OAT)
            + path("M11 40 L44 15 Q46 14 48 16 L81 38 L78 44 L45 25 L15 47Z", RUST)
            + path("M33 69 L33 52 Q33 40 43 40 Q54 40 54 52 L54 69Z", BARK)
            + path("M35 65 L52 65 L66 85 L44 85Z", WOOD) + line("M40 72 L54 71 M45 79 L60 78", OAT, 2.4))


def awning():
    return (line("M18 38 L18 79 M79 38 L79 79", BARK, 5) + path("M19 19 H75 L86 35 Q84 46 73 41 Q65 49 57 41 Q47 48 39 41 Q28 48 23 41 Q14 46 10 38Z", CREAM)
            + path("M20 21 H32 L26 39 Q16 44 12 37Z M45 21 H55 L58 40 Q48 45 40 40Z M68 21 H74 L83 35 Q82 42 74 40Z", RED, "none")
            + rect(13,56,71,24,4,WOOD) + rect(10,54,77,7,3,OAT))


def oven():
    return (path("M12 74 V52 Q13 26 36 23 L36 13 L55 13 L55 23 Q78 26 82 49 V75Z", RUST)
            + path("M23 73 V57 Q24 38 47 36 Q69 39 69 56 V73Z", OAT)
            + path("M32 70 V57 Q32 46 47 44 Q60 45 61 57 V71Z", BARK) + rect(10,72,75,9,3,WOOD))


def locations(a, c, m, p):
    l = {}
    l["plaza"] = (place(tree(),34,4,.64) + line("M18 42 L18 68 M52 40 L52 68", BARK, 5)
                  + path("M8 43 L33 23 L61 41 L57 45 L34 33 L13 48Z", RED)
                  + rect(13,63,45,18,5,OAT) + ellipse(35,63,22,6,SLATE) + line("M32 43 V57", BARK,2.5))
    soil = path("M9 70 L28 48 L82 50 L88 59 L68 80 L14 80Z", WOOD)
    l["garden"] = (soil + place(c["carrot"],18,17,.43) + place(c["radish"],42,13,.48)
                   + line("M18 69 L37 69 M51 67 L68 67", OAT))
    l["henhouse"] = coop() + place(a["chicken"],57,45,.39)
    l["shop"] = awning() + place(c["apple"],26,33,.27) + place(p["bread"],49,34,.28)
    l["garage"] = (path("M10 38 L46 17 L85 36 L84 78 L11 78Z", SLATE)
                   + path("M7 37 L46 13 L88 35 L86 40 L46 22 L10 43Z", TEAL)
                   + rect(19,40,56,36,3,BARK) + place(m["tractor"],21,33,.67))
    l["field"] = (path("M9 57 L53 31 L87 47 L43 84 L9 71Z", WOOD)
                  + line("M16 63 L57 37 M25 70 L66 42 M36 74 L76 46", OAT, 3.5)
                  + wheat(70,52,.52,4))
    l["cowbarn"] = (path("M10 44 L21 22 L47 12 L74 23 L85 45 L81 77 L13 77Z", RED)
                    + path("M7 44 L18 20 L47 8 L77 21 L88 43 L82 46 L71 28 L47 18 L25 28 L14 48Z", BARK)
                    + rect(29,36,37,41,3,BARK) + place(a["cow"],22,35,.51))
    l["sheepmeadow"] = (path("M8 66 Q30 46 50 58 Q68 53 87 62 Q79 81 56 83 Q22 87 8 66Z", LEAF)
                        + place(fence(),45,12,.51) + place(a["sheep"],4,8,.72))
    l["pigsty"] = (path("M10 55 L11 39 L37 24 L65 38 L66 61Z", OAT)
                   + path("M6 39 L36 19 L68 35 L66 41 L37 27 L10 46Z", WOOD)
                   + rect(23,42,23,24,4,BARK) + ellipse(53,69,35,12,BARK) + place(a["pig"],31,33,.56))
    l["orchard"] = tree(True)
    l["kitchen"] = oven() + place(p["bread"],40,46,.52)
    l["greenhouse"] = (path("M11 42 L44 14 L83 36 L83 76 L47 85 L11 71Z", SKY)
                       + place(c["chives"],18,36,.49) + path("M11 42 L47 50 L83 36 M47 50 V84 M44 15 L47 50 M26 30 L65 42 V80 M27 46 V76", "none", PINE, 3))
    l["pond"] = (path("M8 65 Q8 48 32 51 Q39 42 56 53 Q78 44 87 61 Q94 78 58 80 Q33 88 15 77 Q7 74 8 65Z", SKY)
                 + place(a["duck"],17,6,.72) + line("M19 69 Q26 73 35 69 M55 74 Q63 75 70 71", TEAL,2.5))
    l["goatpen"] = (path("M6 78 L25 47 L39 43 L57 56 L67 75Z", SLATE)
                    + place(a["goat"],18,4,.64) + place(fence(),43,23,.51))
    l["paddock"] = place(fence(),0,4,1) + place(a["horse"],19,1,.83)
    l["apiary"] = (line("M26 69 L24 83 M69 69 L73 82", BARK,5) + rect(20,35,56,36,4,GOLD)
                   + path("M15 36 L47 17 L81 34 L78 40 H19Z", WOOD) + line("M21 47 H74 M21 58 H74", BARK,2.6)
                   + rect(39,57,19,10,4,BARK) + rect(33,68,29,6,2,OAT) + place(a["bee"],60,0,.32))
    l["village"] = (path("M12 76 L47 48 L84 64 L64 84Z", OAT) + place(awning(),38,6,.56)
                    + place(awning(),3,20,.70) + line("M59 75 l7 -4 M73 68 l5 -3", BARK,2))
    return l


def people():
    def person(skin, shirt, hair, hair_color, hat="", extra=""):
        return (path("M14 84 Q17 66 37 63 L59 63 Q80 66 83 84 Q52 94 14 84Z", shirt)
                + ellipse(48,47,24,26,skin) + hair.replace("HAIR",hair_color)
                + eye(37,46) + eye(57,46) + smile(48,58) + extra + hat)
    curls = path("M25 46 Q15 40 22 33 Q17 22 29 21 Q27 12 39 16 Q47 5 54 15 Q64 10 69 19 Q82 19 74 31 Q79 38 68 44 Q66 29 60 28 Q51 36 43 30 Q36 35 30 34Z","HAIR")
    fringe = path("M23 46 Q17 20 38 17 Q64 6 73 33 L68 42 L62 30 Q53 36 49 28 Q41 35 32 32 L29 45Z","HAIR")
    baker = path("M23 30 Q12 27 16 17 Q19 8 31 11 Q40 1 49 9 Q61 2 67 11 Q83 10 81 23 Q79 31 70 30 L69 38 Q46 33 25 38Z",CREAM)
    cap = path("M21 34 Q23 14 45 13 Q61 11 68 24 Q79 21 83 27 Q73 38 60 34 Q38 30 21 38Z",TEAL)
    glasses = ellipse(36,46,8,7,"none",BARK,2.6)+ellipse(59,46,8,7,"none",BARK,2.6)+line("M44 46 Q47 43 51 46",BARK,2.6)
    return {
        "tilda": person(OAT,RUST,fringe,BARK,baker),
        "hanno": person("#dfab85",PINE,fringe,SLATE,extra=glasses+path("M37 56 Q42 49 47 54 Q53 48 60 55 Q55 60 48 57 Q43 61 37 56Z",CREAM)),
        "mo": person("#b87e5b",GOLD,curls,BARK,extra=rect(31,73,35,12,4,TEAL)),
        "lale": person("#c5916b",TEAL,fringe,INK,cap,extra=line("M65 69 L38 87",OAT,6)),
        "yusuf": person("#bc865f",SLATE,curls,INK,extra=path("M28 53 Q35 63 45 64 Q61 65 67 51 Q68 71 49 75 Q31 75 28 53Z",BARK)),
    }


def seed_packet(crop):
    return (path("M21 11 Q47 14 74 10 L76 81 Q48 89 20 82Z", OAT)
            + path("M21 11 Q48 15 74 10 L74 23 Q46 27 21 23Z", HONEY)
            + rect(26,30,43,44,9,CREAM) + place(crop,25,29,.48)
            + line("M30 78 Q47 81 65 77",BARK,2))


def seed(x, y, angle=-30, size=1):
    return group(path("M0 -6 Q7 -3 4 3 Q1 8 -4 5 Q-8 0 0 -6Z", GOLD, BARK, 2.7), f"translate({x} {y}) rotate({angle}) scale({size})")


def heart():
    return path("M49 77 Q6 48 16 29 Q25 13 47 31 Q65 9 80 26 Q97 44 49 77Z", RED)


def paw():
    return (path("M24 63 Q25 54 34 50 Q40 36 48 38 Q57 38 62 50 Q76 56 73 67 Q71 75 58 72 Q49 68 40 73 Q24 80 24 63Z", BARK)
            + ellipse(21,45,7,10,WOOD) + ellipse(37,30,7,11,WOOD) + ellipse(56,28,7,11,WOOD) + ellipse(73,42,7,10,WOOD))


def hand():
    return (path("M21 51 Q17 46 20 42 Q24 37 29 42 L37 50 L32 24 Q31 18 36 17 Q42 16 43 23 L47 38 L44 18 Q44 11 49 11 Q54 10 55 17 L57 36 L57 22 Q57 16 62 17 Q67 17 66 24 L67 39 L69 30 Q70 25 74 27 Q78 28 77 34 L75 57 Q75 68 65 74 L64 83 L38 84 L36 72Z", OAT)
            + line("M39 52 Q49 50 52 61",BARK,2.7))


def activities(a,c,m,p,t,l,n):
    s = {}
    s["field.plow"] = place(m["plow"],2,0,.95) + line("M16 80 Q29 85 40 81 M49 78 Q61 81 74 77", WOOD, 3.5)
    s["field.sow"] = (turn(place(seed_packet(sprig(46,68,1.6)),41,2,.59), 112, 65,29)
                      + seed(44,47) + seed(32,58,25,.9) + seed(23,69,12,.75)
                      + path("M9 77 Q18 68 29 75 Q39 67 49 75 Q61 68 72 74 L75 83 L12 85Z",WOOD))
    s["field.water"] = (turn(place(t["can"],19,1,.80),-25,54,37)
                        + place(drop(),6,43,.24) + place(drop(),19,49,.19) + sprig(34,82,.82)
                        + path("M13 84 Q34 74 60 83 L60 87 L13 88Z",WOOD))
    s["field.harvest"] = basket(place(c["carrot"],7,5,.67) + place(c["lettuce"],42,15,.51))
    s["field.combine"] = m["combine"]
    s["field.hay"] = place(roll(),18,6,.87) + line("M11 75 L28 70 M18 80 L35 76 M9 66 L25 64", WOOD)
    s["field.scarecrow"] = (line("M48 43 V86 M15 48 L81 45",BARK,6)
                            + path("M37 43 L58 42 L73 47 L69 57 L58 54 L60 73 L34 73 L37 54 L25 58 L21 50Z", TEAL)
                            + ellipse(47,34,13,13,OAT) + path("M24 29 L34 24 L38 12 L53 13 L60 23 L72 26 Q52 34 24 29Z",HONEY)
                            + eye(41,33,2) + eye(52,33,2) + smile(47,38) + rect(46,58,8,8,1,HONEY))
    s["field.snowplow"] = place(m["snowplow"],-2,-1,.99) + path("M58 81 Q57 73 66 72 Q65 62 76 63 Q84 59 86 71 Q92 73 89 79Z",WHITE)
    trough = path("M10 57 L85 57 L76 76 L19 76Z", WOOD) + line("M23 76 L21 84 M74 76 L76 83",BARK,5)
    s["animal.feed"] = (turn(place(p["feed"],41,0,.55),-50,66,26) + seed(39,42) + seed(30,50,40,.8)
                        + trough + path("M13 58 Q20 48 29 52 Q34 44 45 53 Q62 46 75 57Z",HONEY))
    s["animal.water"] = (turn(place(t["bucket"],42,3,.58),-36,65,33) + place(drop(),24,32,.32) + trough + ellipse(47,56,36,6,SKY))
    s["animal.pet"] = place(a["cat"],2,23,.73) + turn(place(hand(),44,-1,.57),-42,66,24) + place(heart(),13,3,.32)
    s["animal.milk"] = (place(a["cow"],-1,0,.74) + place(t["bucket"],40,43,.57)
                        + ellipse(68,67,16,3.2,WHITE,BARK,1.8) + place(drop(),50,37,.20))
    s["animal.eggs"] = (ellipse(48,63,35,16,WOOD) + egg(31,49,.55) + egg(51,44,.66) + egg(68,52,.48)
                        + path("M11 57 Q44 75 84 55 Q78 82 50 84 Q21 84 11 57Z",OAT)
                        + line("M20 64 Q47 79 74 65 M28 76 L62 71",BARK,2.7))
    s["animal.shear"] = place(p["wool"],2,14,.73) + turn(place(t["shears"],36,9,.65),25,62,40)
    moon = path("M60 9 Q44 26 52 42 Q58 51 71 51 Q50 62 36 46 Q24 27 45 13 Q51 9 60 9Z",HONEY)
    s["animal.bed"] = (place(moon,44,0,.60) + ellipse(46,68,37,15,OAT) + place(a["cat"],8,26,.56)
                       + path("M28 66 Q46 44 69 54 Q81 58 80 70 Q57 84 27 74Z",TEAL) + line("M37 65 Q51 56 63 58",SKY))
    s["animal.find"] = (line("M56 57 L80 80", INK, 12) + line("M57 58 L80 80", WOOD,6)
                        + ellipse(41,39,27,27,SKY) + ellipse(41,39,21,21,WHITE) + place(paw(),20,17,.44))
    s["animal.baby"] = (path("M23 39 Q46 18 69 35 Q90 53 67 76 Q43 96 23 75 Q8 60 23 39Z", SKY)
                        + place(a["rabbit"],18,5,.60) + path("M18 53 Q47 58 69 76 Q43 92 28 79 Q16 70 18 53Z",TEAL)
                        + path("M67 45 Q80 52 71 70 L57 78 L43 68Z",SKY))
    s["shop.stock"] = (rect(11,18,8,66,2,WOOD) + rect(77,18,8,66,2,WOOD)
                       + rect(15,43,65,6,2,OAT) + rect(15,73,65,6,2,OAT)
                       + place(p["milk"],22,10,.40) + place(p["milk"],43,10,.40)
                       + place(p["bread"],17,45,.36) + place(c["apple"],46,46,.33))
    bell = ellipse(48,72,26,5,OAT) + path("M27 67 Q28 49 44 47 V43 H52 V47 Q68 48 70 67Z",GOLD) + rect(24,65,49,7,3,BARK)
    s["shop.order"] = (place(basket(place(c["apple"],24,9,.48)),0,0,.79) + place(bell,39,31,.62))
    s["shop.sign"] = (line("M21 42 L46 15 L76 42", BARK, 3.5) + dot(46,16,4,INK) + rect(10,37,76,40,7,WOOD)
                      + rect(16,42,64,29,5,OAT) + place(c["carrot"],22,34,.43) + place(c["apple"],46,39,.33))
    s["shop.market"] = place(awning(),44,0,.49) + place(m["trailer"],1,16,.86) + place(c["pumpkin"],30,19,.30)
    s["kitchen.bake"] = place(oven(),-2,3,.84) + line("M47 68 L84 81", BARK,6) + place(p["bread"],37,38,.52)
    s["kitchen.press"] = (rect(15,69,66,10,3,WOOD) + rect(20,26,7,45,2,WOOD) + rect(68,26,7,45,2,WOOD)
                          + rect(16,21,64,8,3,OAT) + line("M47 11 V45 M36 12 L59 10",BARK,5)
                          + rect(32,43,31,7,2,SLATE) + place(c["apple"],31,41,.35)
                          + path("M28 56 H68 L62 69 H34Z",OAT) + place(drop(),65,58,.29))
    s["kitchen.churn"] = (line("M49 14 L47 47", BARK,7) + rect(33,10,31,7,3,OAT)
                          + path("M30 40 Q47 34 63 40 L70 77 Q50 88 25 78Z", WOOD) + ellipse(47,40,17,5,OAT)
                          + line("M29 52 Q48 58 65 51 M28 70 Q47 77 68 69", SLATE,5))
    s["kitchen.jam"] = (line("M52 51 L73 18",BARK,5) + ellipse(47,50,30,8,RED)
                        + path("M17 51 Q47 61 78 50 L73 72 Q68 82 46 81 Q23 80 20 69Z",RUST)
                        + line("M18 55 L10 53 M77 55 L87 51",BARK,6)
                        + place(c["strawberry"],20,13,.36) + line("M45 38 Q40 32 44 27",WOOD,2.7))
    s["nature.flowers"] = (line("M32 33 L55 85 M62 25 L47 84 M74 48 L45 82",PINE,4)
                           + flower(29,34,.76,CREAM) + flower(62,24,.66,RED) + flower(72,48,.54,HONEY)
                           + path("M40 65 L61 70 L57 78 L44 73Z",SKY))
    s["nature.pond"] = ellipse(46,72,36,10,SKY) + path("M13 68 Q28 57 60 65 L45 68 L65 72 Q40 83 13 73Z",LEAF) + place(a["frog"],17,15,.68)
    s["nature.birdhouse"] = (line("M47 62 V85",BARK,6) + path("M21 39 L46 19 L73 38 L71 68 L22 68Z",OAT)
                             + path("M15 39 L44 13 L50 13 L81 38 L76 43 L47 23 L21 45Z",TEAL)
                             + ellipse(46,46,10,10,BARK) + rect(38,59,19,5,2,WOOD) + place(a["bird"],55,37,.40))
    s["nature.compost"] = (place(p["compost"],-2,12,.94) + line("M43 67 Q51 78 61 63 Q72 45 81 57 Q86 67 82 71",INK,9)
                           + line("M43 67 Q51 78 61 63 Q72 45 81 57 Q86 67 82 71",PINK,5))
    s["nature.kite"] = (line("M49 57 Q62 78 42 76 Q22 71 17 85",BARK,2.8)
                        + path("M26 29 L56 10 L77 33 L49 63Z",GOLD) + path("M27 29 L76 33 L49 63Z",RED)
                        + line("M56 11 L49 62 M26 29 L76 33",BARK,2.4)
                        + path("M40 70 L50 75 L42 81 L40 77 L34 79 L35 71Z",TEAL))
    s["nature.snowman"] = (line("M30 61 L13 46 M14 47 L13 40 M62 60 L82 44 M80 48 L87 48",BARK,3.5)
                           + ellipse(47,67,22,17,WHITE) + ellipse(47,44,16,15,WHITE)
                           + path("M27 33 L31 28 L32 16 L55 16 L58 29 L66 30 L64 35Z",TEAL)
                           + path("M32 54 Q47 61 61 53 L61 61 L55 62 L62 73 L55 75 L47 62 L32 61Z",RED)
                           + eye(42,41,2.3) + eye(52,41,2.3) + path("M46 45 L62 47 L46 50Z",GOLD))
    s["nature.lantern"] = (line("M28 34 C24 5 69 3 68 34",INK,4) + path("M24 36 H73 L67 72 L30 72Z",HONEY)
                           + path("M45 66 Q36 58 47 47 Q45 55 51 53 Q59 63 51 66Z",RUST)
                           + path("M18 36 L30 25 H66 L79 36Z",TEAL) + rect(26,71,45,9,3,TEAL)
                           + line("M32 39 L36 67 M65 38 L61 68",WOOD,3))
    s["village.mail"] = (line("M52 48 V84",BARK,7) + path("M28 54 V33 Q29 18 42 18 H70 Q83 18 83 32 V54Z",TEAL)
                         + path("M25 54 V34 Q25 21 38 21 Q50 21 50 34 V54Z",SKY) + path("M31 50 V36 Q31 28 38 28 Q44 28 44 36 V50Z",BARK)
                         + turn(rect(10,45,42,27,3,CREAM) + line("M11 47 L31 61 L50 47",BARK,2.5),-12,31,56))
    s["village.helpmo"] = place(n["mo"],0,0,.85) + path("M51 58 L68 49 L84 58 V77 L68 85 L51 77Z",GOLD) + line("M51 58 L68 66 L84 58 M68 66 V84",BARK,2.5)
    s["farm.decorate"] = (place(fence(),0,3,.94) + line("M55 74 V43 M55 62 L69 53",PINE,4)
                          + flower(54,39,.70,RED) + leaf(55,65,78,.64) + path("M38 66 H73 L68 84 H44Z",RUST) + rect(36,62,39,7,2,OAT))
    s["farm.photo"] = (path("M12 33 H28 L34 22 H55 L62 32 H78 Q85 32 85 40 V68 Q85 75 77 75 H19 Q11 75 11 68Z",TEAL)
                       + rect(67,38,12,7,2,CREAM) + ellipse(45,53,17,17,OAT) + ellipse(45,53,11,11,SLATE) + dot(41,49,3.5,CREAM))
    s["farm.clean"] = (turn(place(t["brush"],6,-5,.67),-18,38,29) + ellipse(69,45,9,9,GOLD)
                       + path("M13 55 L43 46 L82 54 L81 77 L50 85 L16 76Z",WOOD)
                       + path("M13 55 L48 63 L82 54 L77 51 L45 47Z",BARK) + line("M49 64 L50 81",OAT,2.7))
    s["farm.memory"] = (turn(rect(13,18,42,54,6,OAT) + place(c["apple"],17,27,.36),-12,34,45)
                        + turn(rect(41,27,42,54,6,CREAM) + place(c["apple"],45,35,.36),10,62,54))
    notes = line("M57 41 V18 L77 13 V35 M58 23 L75 19",BARK,4) + ellipse(53,42,6,4,BARK) + ellipse(73,36,6,4,BARK)
    s["farm.sing"] = place(a["dog"],1,18,.79) + notes
    return s


def seasons():
    return {
        "spring": (line("M20 81 Q36 54 70 25 M39 55 L33 36", BARK, 5)
                   + leaf(55,40,92,.86,MINT) + flower(33,33,.71,PINK) + flower(66,25,.49,CREAM)),
        "summer": ("".join(turn(line("M47 10 L47 19",BARK,4),deg,47,42) for deg in range(0,360,45))
                   + ellipse(47,42,19,19,HONEY) + place(wheat(48,85,1,12),32,36,.63)),
        "autumn": (path("M21 71 Q9 56 17 34 L30 42 L37 15 L50 31 L71 11 L69 37 L83 35 L71 56 L78 59 Q63 77 39 73Z",RED)
                   + line("M15 85 L62 33 M41 60 L39 41 M48 52 L64 50",BARK,3)),
        "winter": ("".join(turn(line("M48 48 V12 M48 29 L39 20 M48 29 L57 20",TEAL,4.5),deg,48,48) for deg in range(0,360,60))
                   + ellipse(48,48,6,6,SKY)),
    }


def babies(a):
    chick = (path("M22 60 Q16 51 21 43 Q25 36 30 35 Q30 18 46 18 Q51 11 57 12 L55 18 Q71 22 71 40 Q81 53 74 66 Q65 81 46 80 Q30 80 22 68Z",HONEY)
             + eye(56,33) + path("M70 35 L82 41 L69 45Z",GOLD)
             + path("M26 52 Q38 47 48 55 Q42 68 31 63Z",GOLD) + line("M39 79 L36 85 M56 80 L59 85",BARK))
    # Little feet, a disproportionately large face and a straw bed distinguish
    # the young animal from the adult portrait. The same cue works in grayscale.
    def little(face, coat):
        return (ellipse(48,75,31,8,OAT) + ellipse(48,60,15,17,coat)
                + ellipse(39,76,6,5,coat) + ellipse(57,76,6,5,coat)
                + place(a[face],10,-1,.80))
    return {
        "chick": chick, "calf": little("cow",CREAM), "lamb": little("sheep",CREAM),
        "piglet": little("pig",PINK),
        "duckling": (place(a["duck"],6,4,.87) + path("M74 53 Q84 55 82 63 Q77 70 65 68Z",HONEY)
                     + line("M23 77 Q34 82 48 78",TEAL,3)),
        "kid": little("goat",CREAM), "foal": little("horse",WOOD), "kit": little("rabbit",OAT),
    }


def field_book():
    return (path("M9 25 Q27 18 47 30 Q66 17 86 24 V73 Q66 70 49 81 Q30 73 9 75Z",TEAL)
            + path("M13 20 Q31 17 48 29 Q64 17 81 19 V67 Q64 65 48 76 Q32 65 13 69Z",CREAM)
            + line("M48 31 V73",WOOD,2.5) + leaf(38,54,-13,.67) + line("M55 48 Q64 42 71 43 M55 55 Q64 50 70 50",WOOD,2.5))
