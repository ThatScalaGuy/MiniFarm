#!/usr/bin/env python3
"""Make labeled proofs from compiled assets, not from the source SVGs.

macOS, Xcode and Pillow: python3 -B Tools/Art/proof.py <output-directory>
"""

import argparse
import plistlib
import subprocess
import tempfile
from itertools import combinations
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageOps

import build_pictograms as catalog


PAPER = "#faf5e9"
CARD = "#fffdf6"
INK = "#493b31"
MUTED = "#655e51"
RULE = "#d6c7ae"
TEAL = "#365f56"
GREEN = "#dfebd8"


def run(*args):
    subprocess.run(args, check=True)


def render(work):
    catalog.generate(check=True)
    out = work / "pictures"
    out.mkdir()
    contents = work / "Proof.app/Contents"
    resources = contents / "Resources"
    resources.mkdir(parents=True)
    executable = contents / "MacOS/RenderProof"
    executable.parent.mkdir()
    with (contents/"Info.plist").open("wb") as file:
        plistlib.dump({"CFBundleExecutable":"RenderProof", "CFBundleIdentifier":"org.minifarm.artproof",
                       "CFBundlePackageType":"APPL","CFBundleName":"Farm Art Proof"},file)
    run("xcrun", "actool", "--compile", resources, "--platform", "macosx", "--minimum-deployment-target", "14.0",
        "--target-device", "mac", "--output-format", "human-readable-text", catalog.CATALOG)
    run("xcrun", "swiftc", "-parse-as-library", catalog.APP/"FarmPictogram.swift", catalog.APP/"FarmPictogramIndex.swift",
        Path(__file__).with_name("RenderProof.swift"), "-o", executable)
    run(executable, out)
    ios = work / "iphone"
    ios.mkdir()
    run("xcrun", "actool", "--compile", ios, "--platform", "iphonesimulator", "--minimum-deployment-target", "17.0",
        "--target-device", "iphone", "--target-device", "ipad", catalog.CATALOG)
    if not (ios/"Assets.car").is_file():
        raise ValueError("Missing compiled iOS asset catalog")
    return out


def font(size, bold=False):
    return ImageFont.truetype("Helvetica.ttc",size,index=1 if bold else 0)


def label(draw, xy, text, size=16, color=INK, bold=False, anchor="la"):
    draw.text(xy,text,font=font(size,bold),fill=color,anchor=anchor)


def read_card(renders, key, side, gray=False, silhouette=False):
    with Image.open(renders/f"{key}-{side}.png") as file:
        rgba = file.convert("RGBA")
    if gray or silhouette:
        alpha = rgba.getchannel("A")
        rgba = Image.new("RGBA",rgba.size,INK) if silhouette else ImageOps.grayscale(rgba).convert("RGBA")
        rgba.putalpha(alpha)
    return rgba


def review(renders, cards):
    gray64 = {}
    errors = []
    for key in cards:
        for size in (64,88):
            im = read_card(renders,key,size)
            alpha = im.getchannel("A")
            bounds = alpha.point(lambda a: 255 if a > 64 else 0).getbbox()
            if not bounds:
                raise ValueError(f"Empty raster for {key} ({size})")
            x0,y0,x1,y1 = bounds
            if not(0 < x0 < x1 < size and 0 < y0 < y1 < size):
                errors.append(f"Drawing clips frame: {key} ({size}) {bounds}")
            if size == 64:
                if max(x1-x0,y1-y0) < 38:
                    errors.append(f"Small silhouette for {key}: {bounds}")
                sheet = Image.new("RGBA",im.size,CARD)
                sheet.alpha_composite(im)
                gray64[key] = ImageOps.grayscale(sheet)
    if errors:
        raise ValueError("\n".join(errors))
    for group in ("act.", "loc.", "animal.", "tool.", "item.seed."):
        for a,b in combinations([k for k in cards if k.startswith(group)],2):
            if ImageChops.difference(gray64[a],gray64[b]).getbbox() is None:
                raise ValueError(f"Indistinguishable grayscale render: {a}, {b}")


def draw_card(canvas, renders, key, x, y, size, gray=False, silhouette=False):
    im = read_card(renders,key,size,gray,silhouette)
    canvas.paste(im, (int(x),int(y)), im)


def sheet(renders, cards, heading, subtitle, sections, page, gray=False):
    canvas = Image.new("RGB",(1040,1080),PAPER)
    d = ImageDraw.Draw(canvas)
    label(d,(36,28),"MINIFARM  /  BILDATELIER",14,TEAL,True)
    label(d,(1004,28),f"TAFEL  {page:02d}",14,TEAL,True,"ra")
    label(d,(34,55),heading,38,bold=True)
    label(d,(36,110),subtitle,17,MUTED)
    d.line((36,144,1004,144),fill=RULE,width=2)
    y = 156
    for title, keys in sections:
        label(d,(38,y),title,14,TEAL,True)
        y += 27
        for i,key in enumerate(keys):
            col,row = i%8,i//8
            x = 36+col*121
            top = y+row*110
            d.rounded_rectangle((x,top,x+114,top+101),radius=13,fill=CARD)
            draw_card(canvas,renders,key,x+25,top+3,64,gray)
            words = cards[key][0].replace("Saatgut: ","").split()
            if len(words) == 1:
                lines = [words[0]]
            elif d.textlength(" ".join(words),font=font(12)) <= 108:
                lines = [" ".join(words)]
            else:
                cut = min(range(1,len(words)), key=lambda j: max(len(" ".join(words[:j])), len(" ".join(words[j:]))))
                lines = [" ".join(words[:cut])," ".join(words[cut:])]
            for j,text in enumerate(lines):
                label(d,(x+57,top+68+j*14),text,12,INK,False,"ma")
        y += ((len(keys)+7)//8)*110+9
    if y > 1035:
        raise ValueError(f"Proof layout overflows: {heading} ({y})")
    label(d,(36,1043),"Originale Vektorbilder  •  64 pt  •  SwiftUI / kompilierter Assetkatalog",13,MUTED)
    return canvas


def cover(renders, cards):
    canvas = Image.new("RGB",(1040,870),PAPER)
    d=ImageDraw.Draw(canvas)
    d.rounded_rectangle((28,24,1012,191),radius=24,fill=GREEN)
    d.ellipse((53,48,171,166),fill=CARD)
    draw_card(canvas,renders,"animal.dog",68,62,88)
    label(d,(197,48),"MINIFARM  /  BILDATELIER",16,TEAL,True)
    label(d,(194,80),"Pelle zeigt, was zu tun ist",42,bold=True)
    label(d,(198,143),"Bildkarten für Wunschblasen, Werkzeugwahl und Hofbuch",18,MUTED)
    label(d,(38,219),"WER  +  WAS",15,TEAL,True)
    label(d,(38,248),"Drei Wünsche, ohne ein Wort",28,bold=True)
    for i,(actor, action, caption) in enumerate([
            ("animal.chicken","act.animal.eggs","Eier sammeln"),("npc.tilda","act.kitchen.bake","Mit Tilda backen"),
            ("animal.sheep","act.animal.shear","Wolle scheren")]):
        x=38+i*325
        d.rounded_rectangle((x,297,x+309,430),radius=25,fill=CARD,outline=RULE,width=2)
        d.polygon([(x+33,428),(x+40,445),(x+65,429)],fill=CARD)
        d.line([(x+33,429),(x+40,445),(x+65,429)],fill=RULE,width=2)
        draw_card(canvas,renders,actor,x+48,304,88)
        draw_card(canvas,renders,action,x+165,304,88)
        label(d,(x+154,399),caption,16,INK,False,"ma")
    label(d,(38,473),"KLEIN UND OHNE FARBE",15,TEAL,True)
    label(d,(38,500),"Die Form trägt die Bedeutung",28,bold=True)
    keys=["act.field.sow","act.field.water","act.animal.water","act.animal.feed","tool.brush","tool.shears","item.seed.carrot","crop.carrot"]
    for i,key in enumerate(keys):
        x=38+i*121
        d.rounded_rectangle((x,551,x+113,712),radius=15,fill=CARD)
        draw_card(canvas,renders,key,x+25,553,64)
        draw_card(canvas,renders,key,x+25,621,64,True)
        text = "Möhrensaat" if key == "item.seed.carrot" else cards[key][0]
        label(d,(x+56,689),text,13,INK,False,"ma")
    d.line((38,752,1003,752),fill=RULE,width=2)
    label(d,(38,773),"88 pt in den Wunschblasen  /  64 pt im Vergleich",16,TEAL,True)
    label(d,(38,805),"Die Beschriftungen stehen nur auf der Sichtprobe. Die App-Bilder selbst enthalten keine Schrift.",16,MUTED)
    return canvas


def produce(output):
    cards,_ = catalog.vocabulary()
    with tempfile.TemporaryDirectory(prefix="mini-farm-art-") as temp:
        renders = render(Path(temp))
        review(renders,cards)
        def select(prefix):
            return [key for key in cards if key.startswith(prefix)]
        def grouped(groups):
            return [(title,select("act."+prefix+".")) for title,prefix in groups]
        acts = grouped([("FELD","field"),("TIERE","animal"),("LADEN","shop"),("KÜCHE","kitchen")])
        outdoors = grouped([("NATUR","nature"),("DORF","village"),("HOF","farm")])
        pages = [cover(renders,cards)]
        pages.append(sheet(renders,cards,"Tätigkeiten am Hof","Gerät, Handgriff oder Ergebnis zeigen die Handlung.",acts,2))
        pages.append(sheet(renders,cards,"Draußen und im Dorf","Auch in Graustufen unterscheiden sich die Tätigkeiten durch Motiv und Umriss.",outdoors,3,True))
        pages.append(sheet(renders,cards,"Orte und Werkzeuge","Ein Wahrzeichen für jeden Ort. Die Werkzeuge haben keine farbabhängigen Badges.",[
            ("ORTE",select("loc.")),("WERKZEUGE",select("tool.")),("MASCHINEN",[k for k in cards if k.startswith(("veh.","imp."))])],4))
        pages.append(sheet(renders,cards,"Tiere und Menschen","Pelles ungleiche Ohren und sein Halstuch bleiben bei kleiner Darstellung sichtbar.",[
            ("HOFTIERE UND GÄSTE",["animal."+k for k in catalog.ANIMALS]),("JUNGTIERE",["animal."+k for k in catalog.BABIES]),
            ("DORFBEWOHNER",select("npc.")),("JAHRESZEITEN UND HOFBUCH",select("season.")+["hofbook.cover"])],5))
        pages.append(sheet(renders,cards,"Vom Saatgut zum Ertrag","Auch ohne Farbe bleiben Tüte und Erntegut voneinander getrennt.",[
            ("PFLANZEN UND ERNTE",select("crop.")),("SAATTÜTEN",select("item.seed.")),("TIERPRODUKTE, FUTTER UND WASSER",
                [f"item.{k}" for k in list(catalog.PRODUCTS)[:10]]+["item.water"])],6))
        pages.append(sheet(renders,cards,"Verarbeitet und verpackt","Hofküche und Strickstube. Darunter: die erwachsenen Tiere ohne Farbinformation.",[
            ("PRODUKTE",[f"item.{k}" for k in list(catalog.PRODUCTS)[10:]]),
            ("TONWERT-STUDIE",["animal."+k for k in catalog.ANIMALS])],7,True))
        output.mkdir(parents=True,exist_ok=True)
        pages[0].save(output/"Bildsprache-MiniFarm.png")
        pages[0].save(output/"Bildatlas-MiniFarm.pdf",save_all=True,append_images=pages[1:],resolution=72,quality=95)
    print(f"Verified all small renders; exported {len(pages)} labeled pages.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output",type=Path)
    produce(parser.parse_args().output)
