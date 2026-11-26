"""Export a committed MiniFarm project, without worktree files or signing material."""
import argparse
from pathlib import Path, PurePosixPath
import subprocess
import tempfile
import zipfile


def export(revision, destination):
    project = ["App", "Configuration", "MiniFarm.xcodeproj", "Tests", "UITests", "Tools", "docs",
               "project.yml", "README.md", "PROGRESS.md", "DESSSICION.md"]
    commit = subprocess.check_output(["git", "rev-parse", "--verify", revision + "^{commit}"], text=True).strip()
    destination = destination.resolve()
    with tempfile.TemporaryDirectory(dir=destination.parent) as work:
        output = Path(work) / "MiniFarm.zip"
        subprocess.run(["git", "archive", "--format=zip", "--prefix=MiniFarm/", "-o", str(output),
                        commit, "--", *project], check=True)
        with zipfile.ZipFile(output) as bundle:
            files = set(bundle.namelist())
            required = ["MiniFarm.xcodeproj/project.pbxproj",
                        "MiniFarm.xcodeproj/xcshareddata/xcschemes/MiniFarm.xcscheme",
                        "App/MiniFarmApp.swift", "App/Resources/Models/model.crop.radish.ripe.usdz",
                        "App/Resources/Audio/manifest.json", "App/Resources/Content/crops.json",
                        "App/Art/FarmPictograms.xcassets/Contents.json",
                        "project.yml", "PROGRESS.md", "DESSSICION.md", "README.md"]
            for item in required:
                if "MiniFarm/" + item not in files:
                    raise ValueError(f"Projektdatei fehlt: {item}")
            for name in files:
                path = PurePosixPath(name.lower())
                if (path.is_absolute() or ".." in path.parts
                    or set(path.parts) & {".git", "build", "deriveddata", "xcuserdata", "__pycache__"}
                    or any(part.startswith(".env") for part in path.parts)
                    or path.suffix in {".p12", ".p8", ".pem", ".key", ".mobileprovision", ".xcuserstate"}
                    or bundle.getinfo(name).external_attr >> 28 == 10):
                    raise ValueError(f"Kein Bestandteil der Projektauslieferung: {name}")
            if bundle.testzip():
                raise ValueError("Prüfsumme einer Projektdatei stimmt nicht")
        output.replace(destination)
    print(f"{commit}: {destination} ({destination.stat().st_size:,} Bytes)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--revision", default="HEAD")
    args = parser.parse_args()
    export(args.revision, args.destination)
