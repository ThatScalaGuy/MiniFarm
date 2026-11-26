"""Verify the sale and its isolation in the two disposable UI-test profiles."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def checked_payload(path):
    envelope = json.loads(path.read_bytes())
    data = base64.b64decode(envelope["payload"], validate=True)
    prefix = f'minifarm:{envelope["container"]}:{envelope["schemaVersion"]}:'.encode()
    if hashlib.sha256(prefix + data).hexdigest() != envelope["checksum"]:
        raise ValueError(f"Prüfsumme von {path.name} stimmt nicht")
    return json.loads(data)


def shop_state(state):
    production = state["production"]
    return {
        "location": state["locationID"],
        "radishesLeft": sum(production[place].get("item.radish", 0) for place in ("inventory", "shelf")),
        "taler": production["coins"],
    }


def verify(device):
    container = subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", device, "de.thatscalaguy.minifarm", "data"],
        text=True,
    ).strip()
    test_profiles = Path(container) / "Library/Application Support/MiniFarm/FamilyUITesting/Profiles"
    slots = list(test_profiles.glob("*/Profile.json"))
    if len(slots) != 2:
        raise ValueError(f"Zwei Testprofile erwartet, gefunden: {len(slots)}")
    farms = {checked_payload(slot)["avatar"]: checked_payload(slot.with_name("Farm.json")) for slot in slots}
    if set(farms) != {"animal.cow", "animal.sheep"}:
        raise ValueError("Kuh- und Schafprofil erwartet")
    state = farms["animal.cow"]
    production = state["production"]
    bed = next((b for b in production["plots"] if b["id"] == "plot.garden.1.1"), {})
    report = {
        "day": state["day"],
        "introduction": state["introduction"],
        "harvestedBedEmpty": bool(bed) and bed.get("cropID") is None,
        "chickensFedOnFirstDay": sum(a["actions"].get("feed") == 1 for a in production["animals"] if a["speciesID"] == "animal.chicken"),
        **shop_state(state),
        "radishInFarmBook": "hofbook.plant.radish" in state["book"],
    }
    expected = dict(day=2, introduction=6, harvestedBedEmpty=True, chickensFedOnFirstDay=1,
                    location="loc.shop", radishesLeft=2, taler=1, radishInFarmBook=True)
    if report != expected:
        raise ValueError(f"Spielstand nach Tildas Bestellung weicht ab: {report}")
    other = shop_state(farms["animal.sheep"])
    if other != dict(location="loc.shop", radishesLeft=0, taler=0):
        raise ValueError(f"Der andere Hof hat Tildas Verkauf übernommen oder den Ort gewechselt: {other}")
    print(json.dumps({"animal.cow": report, "animal.sheep": other}, indent=2, sort_keys=True))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("simulator", help="UDID des eigens benutzten Simulators")
    try:
        verify(parser.parse_args().simulator)
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"Erntebeleg nicht bestätigt: {error}")
