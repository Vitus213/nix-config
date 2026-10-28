import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class OmpSyncTests(unittest.TestCase):
    def test_missing_key_preserves_existing_configuration(self):
        for placeholder in ("@DEEPSEEK_KEY@", "@MAGPIE_KEY@"):
            for existing in (False, True):
                with self.subTest(placeholder=placeholder, existing=existing):
                    with tempfile.TemporaryDirectory() as directory:
                        root = Path(directory)
                        keys = root / "keys"
                        template = root / "models.yml.in"
                        output = root / "models.yml"
                        keys.write_text("", encoding="utf-8")
                        template.write_text(f"apiKey: {placeholder}\n", encoding="utf-8")
                        if existing:
                            output.write_text("previous configuration\n", encoding="utf-8")

                        result = subprocess.run(
                            [
                                sys.executable,
                                str(Path(__file__).with_name("omp-sync.py")),
                                str(keys),
                                str(template),
                                str(output),
                            ],
                            capture_output=True,
                            text=True,
                            check=False,
                        )

                        self.assertEqual(result.returncode, 1)
                        self.assertIn(placeholder, result.stderr)
                        if existing:
                            self.assertEqual(output.read_text(), "previous configuration\n")
                        else:
                            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
