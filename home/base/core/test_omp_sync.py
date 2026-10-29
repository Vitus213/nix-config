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
        self.assertEqual(omp_sync.magpie_base_url("athena"), "http://127.0.0.1:3425/v1")
        self.assertEqual(omp_sync.magpie_base_url("athena.example"), "http://127.0.0.1:3425/v1")
        self.assertEqual(omp_sync.magpie_base_url("ATHENA"), "http://127.0.0.1:3425/v1")
        for client in ("apollo", "artemis", "artemis.local", "hestia"):
            with self.subTest(client=client):
                self.assertEqual(omp_sync.magpie_base_url(client), "http://192.168.100.11:3425/v1")

    def test_hostname_chooses_base_url_in_generated_file(self):
        """端到端：同一模板在网关机与客户端上渲染出不同地址，且 key 都来自密钥文件。"""
        omp_sync = load_module()
        template = "magpie:\n  baseUrl: @MAGPIE_BASE_URL@\n  apiKey: @MAGPIE_KEY@\n"
        keys = {"MAGPIE_KEY": "sk-magpie-key-test"}
        on_gateway = omp_sync.render(template, keys, "athena")
        on_client = omp_sync.render(template, keys, "apollo")
        self.assertIn("baseUrl: http://127.0.0.1:3425/v1", on_gateway)
        self.assertIn("baseUrl: http://192.168.100.11:3425/v1", on_client)
        self.assertIn("apiKey: sk-magpie-key-test", on_gateway)
        self.assertIn("apiKey: sk-magpie-key-test", on_client)
        self.assertNotIn("@MAGPIE_BASE_URL@", on_gateway + on_client)


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
