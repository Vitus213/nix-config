import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class OmpSyncTests(unittest.TestCase):
    def test_missing_deepseek_key_does_not_write_unresolved_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            keys = root / "keys"
            template = root / "models.yml.in"
            output = root / "models.yml"
            keys.write_text("", encoding="utf-8")
            template.write_text("apiKey: @DEEPSEEK_KEY@\n", encoding="utf-8")

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
            self.assertIn("@DEEPSEEK_KEY@", result.stderr)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
