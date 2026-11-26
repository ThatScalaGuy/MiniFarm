import unittest
from pathlib import Path

from generate_audio import ROOT, resolve_asset_path


class ResolveAssetPathTests(unittest.TestCase):
    def test_rejects_absolute_and_traversal_paths(self):
        for invalid_path in (
            str(ROOT / "README.md"),
            "C:\\outside.wav",
            "../README.md",
            "subdir/../../README.md",
            r"..\README.md",
        ):
            with self.subTest(path=invalid_path), self.assertRaises(ValueError):
                resolve_asset_path(invalid_path)

    def test_rejects_symlink_escaping_audio_root(self):
        test_root = Path(__file__).resolve().parent
        outside_target = ROOT / "README.md"
        link = test_root / ".path-validation-escape"
        self.assertFalse(link.exists() or link.is_symlink())
        try:
            link.symlink_to(outside_target)
            with self.assertRaises(ValueError):
                resolve_asset_path(link.name, test_root)
        finally:
            link.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
