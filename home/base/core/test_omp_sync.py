import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("omp-sync.py")


def load_module():
    spec = importlib.util.spec_from_file_location("omp_sync", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class MagpieBaseUrlTests(unittest.TestCase):
    def test_gateway_host_uses_loopback_and_clients_use_lan(self):
        omp_sync = load_module()
        for gateway in ("j1900", "j1900.example", "J1900"):
            with self.subTest(gateway=gateway):
                self.assertEqual(omp_sync.magpie_base_url(gateway), "http://127.0.0.1:3425/v1")
        for client in ("apollo", "artemis", "artemis.local", "hestia", "athena", "athena.example", "ATHENA"):
            with self.subTest(client=client):
                self.assertEqual(omp_sync.magpie_base_url(client), "http://192.168.100.3:3425/v1")



class OmpSyncTests(unittest.TestCase):
    def run_sync(self, keys_text, template_text, existing=None):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)
        keys = root / "keys"
        template = root / "models.yml.in"
        output = root / "models.yml"
        keys.write_text(keys_text, encoding="utf-8")
        template.write_text(template_text, encoding="utf-8")
        if existing is not None:
            output.write_text(existing, encoding="utf-8")
        result = subprocess.run(
            [sys.executable, str(SCRIPT), str(keys), str(template), str(output)],
            capture_output=True,
            text=True,
            check=False,
        )
        return result, output

    def test_missing_key_preserves_existing_configuration(self):
        for placeholder in ("@DEEPSEEK_KEY@", "@MAGPIE_KEY@"):
            for existing in (False, True):
                with self.subTest(placeholder=placeholder, existing=existing):
                    previous = "previous configuration\n" if existing else None
                    result, output = self.run_sync("", f"apiKey: {placeholder}\n", previous)

                    self.assertEqual(result.returncode, 1)
                    self.assertIn(placeholder, result.stderr)
                    if existing:
                        self.assertEqual(output.read_text(), "previous configuration\n")
                    else:
                        self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
