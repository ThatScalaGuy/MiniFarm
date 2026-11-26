"""Run just the Swift simulation and its real bundled catalogs, without a UI/device."""

from pathlib import Path
import subprocess
import sys
import tempfile


root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="MiniFarm-gameplay-") as work:
    project = Path(work)
    (project / "App").symlink_to(root / "App", target_is_directory=True)
    (project / "Tests").symlink_to(root / "Tests", target_is_directory=True)
    (project / "Package.swift").write_text("""// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "MiniFarm", platforms: [.macOS(.v14)], targets: [
    .target(name: "MiniFarm", path: "App/Gameplay"),
    .testTarget(name: "GameplayTests", dependencies: ["MiniFarm"], path: "Tests/Gameplay",
                exclude: ["run-gameplay-tests.py"])
])
""", encoding="utf-8")
    sys.exit(subprocess.call(["swift", "test", "--package-path", work, *sys.argv[1:]]))
