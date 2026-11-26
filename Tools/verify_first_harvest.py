"""Read the disposable UI-test profile and verify the actual post-sale save."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def verify(device):
    container = subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", device, "de.thatscalaguy.minifarm", "data"],
        text=True,
    ).strip()
    test_profiles = Path(container) / "Library/Application Support/MiniFarm/FamilyUITesting/Profiles"
    slots = list(test_profiles.glob("*/Farm.json"))
    if len(slots) != 1:
        raise ValueError(f"Genau ein Testhof erwartet, gefunden: {len(slots)}")
    envelope = json.loads(slots[0].read_bytes())
    data = base64.b64decode(envelope["payload"], validate=True)
    prefix = f'minifarm:{envelope["container"]}:{envelope["schemaVersion"]}:'.encode()
    if hashlib.sha256(prefix + data).hexdigest() != envelope["checksum"]:
        raise ValueError("Prüfsumme des Spielstands stimmt nicht")
    state = json.loads(data)
    production = state["production"]
    bed = next((b for b in production["plots"] if b["id"] == "plot.garden.1.1"), {})
    report = {
        "day": state["day"],
        "introduction": state["introduction"],
        "harvestedBedEmpty": bool(bed) and bed.get("cropID") is None,
        "chickensFedOnFirstDay": sum(a["actions"].get("feed") == 1 for a in production["animals"] if a["speciesID"] == "animal.chicken"),
        "radishesLeft": sum(production[place].get("item.radish", 0) for place in ("inventory", "shelf")),
        "taler": production["coins"],
        "radishInFarmBook": "hofbook.plant.radish" in state["book"],
    }
    expected = dict(day=2, introduction=6, harvestedBedEmpty=True, chickensFedOnFirstDay=1,
                    radishesLeft=2, taler=1, radishInFarmBook=True)
    if report != expected:
        raise ValueError(f"Spielstand nach Tildas Bestellung weicht ab: {report}")
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("simulator", help="UDID des eigens benutzten Simulators")
    try:
        verify(parser.parse_args().simulator)
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"Erntebeleg nicht bestätigt: {error}")
