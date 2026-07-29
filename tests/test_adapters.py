from __future__ import annotations

import json
import re
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXTENSION = ROOT / "extension-applovin"
CATALOG_PATH = ROOT / "updater/adapters.json"


def render_boolean_sections(
    template: str, enabled: set[str]
) -> str:
    pattern = re.compile(
        r"{{#(?P<key>applovin\.[a-z0-9_]+)}}\n"
        r"(?P<body>.*?)"
        r"{{/(?P=key)}}",
        re.DOTALL,
    )
    while True:
        match = pattern.search(template)
        if match is None:
            return template
        replacement = (
            match.group("body") if match.group("key") in enabled else ""
        )
        template = template[: match.start()] + replacement + template[match.end() :]


class OptionalAdapterContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
        cls.gradle = (
            EXTENSION / "manifests/android/build.gradle"
        ).read_text(encoding="utf-8")
        cls.podfile = (
            EXTENSION / "manifests/ios/Podfile"
        ).read_text(encoding="utf-8")
        cls.info_plist = (
            EXTENSION / "manifests/ios/Info.plist"
        ).read_text(encoding="utf-8")
        cls.properties = (
            EXTENSION / "ext.properties"
        ).read_text(encoding="utf-8")

    def test_adapter_catalog_is_exact_and_platform_complete(self) -> None:
        self.assertEqual(1, self.catalog["schema_version"])
        android = self.catalog["android"]["networks"]
        ios = self.catalog["ios"]["networks"]
        self.assertGreaterEqual(len(android), 26)
        self.assertGreaterEqual(len(ios), 28)
        for key, network in android.items():
            with self.subTest(platform="android", network=key):
                self.assertRegex(
                    network["coordinate"],
                    r"^com\.applovin\.mediation:[a-z0-9-]+:[0-9][0-9.]*$",
                )
                self.assertNotIn("+", network["coordinate"])
        for key, network in ios.items():
            with self.subTest(platform="ios", network=key):
                self.assertRegex(network["pod"], r"^AppLovin[A-Za-z0-9]+$")
                self.assertRegex(network["version"], r"^[0-9][0-9.]*$")
                self.assertNotIn("+", network["version"])
                self.assertIn("skadnetwork_key", network)
                self.assertIn("skadnetwork_ids", network)
                self.assertEqual(
                    sorted(network["skadnetwork_ids"]),
                    network["skadnetwork_ids"],
                )
                for identifier in network["skadnetwork_ids"]:
                    self.assertRegex(
                        identifier,
                        r"^[a-z0-9]{10}\.skadnetwork$",
                    )

    def test_every_adapter_has_a_game_project_property(self) -> None:
        for platform in ("android", "ios"):
            networks = self.catalog[platform]["networks"]
            for key in networks:
                property_name = f"{key}_{platform}"
                with self.subTest(property=property_name):
                    self.assertRegex(
                        self.properties,
                        rf"(?m)^{re.escape(property_name)}\.type = bool$",
                    )
                    self.assertRegex(
                        self.properties,
                        rf"(?m)^{re.escape(property_name)}\.default = 0$",
                    )

    def test_android_mustache_switches_control_dependencies(self) -> None:
        android = self.catalog["android"]["networks"]
        disabled = render_boolean_sections(self.gradle, set())
        for network in android.values():
            self.assertNotIn(network["coordinate"], disabled)

        unity_key = "applovin.unity_ads_android"
        enabled = render_boolean_sections(self.gradle, {unity_key})
        self.assertIn(android["unity_ads"]["coordinate"], enabled)
        self.assertNotIn(android["meta"]["coordinate"], enabled)

        bidmachine_key = "applovin.bidmachine_android"
        bidmachine = render_boolean_sections(
            self.gradle, {bidmachine_key}
        )
        self.assertIn(
            android["bidmachine"]["repositories"][0], bidmachine
        )
        self.assertNotIn(
            android["bidmachine"]["repositories"][0], disabled
        )

    def test_ios_mustache_switches_control_pods(self) -> None:
        ios = self.catalog["ios"]["networks"]
        disabled = render_boolean_sections(self.podfile, set())
        for network in ios.values():
            self.assertNotIn(
                f"pod '{network['pod']}', '{network['version']}'",
                disabled,
            )

        unity_key = "applovin.unity_ads_ios"
        enabled = render_boolean_sections(self.podfile, {unity_key})
        unity = ios["unity_ads"]
        self.assertIn(
            f"pod '{unity['pod']}', '{unity['version']}'", enabled
        )
        self.assertNotIn(ios["meta"]["pod"], enabled)

    def test_ios_mustache_switches_control_skadnetwork_ids(self) -> None:
        ios = self.catalog["ios"]["networks"]
        identifier_pattern = re.compile(
            r"<string>([a-z0-9]{10}\.skadnetwork)</string>"
        )
        disabled = render_boolean_sections(self.info_plist, set())
        disabled_ids = set(identifier_pattern.findall(disabled))

        unity = ios["unity_ads"]
        self.assertEqual(
            [
                "5f5u5tfb26.skadnetwork",
                "6yxyv74ff7.skadnetwork",
                "77y3x8wds4.skadnetwork",
                "k6y4y55b64.skadnetwork",
            ],
            unity["skadnetwork_ids"],
        )
        self.assertTrue(
            set(unity["skadnetwork_ids"]).isdisjoint(disabled_ids)
        )

        enabled = render_boolean_sections(
            self.info_plist, {"applovin.unity_ads_ios"}
        )
        enabled_ids = set(identifier_pattern.findall(enabled))
        self.assertEqual(
            disabled_ids | set(unity["skadnetwork_ids"]),
            enabled_ids,
        )

        bidmachine = ios["bidmachine"]
        self.assertGreater(len(bidmachine["skadnetwork_ids"]), 0)
        self.assertTrue(
            set(bidmachine["skadnetwork_ids"]).isdisjoint(disabled_ids)
        )
        bidmachine_enabled = render_boolean_sections(
            self.info_plist, {"applovin.bidmachine_ios"}
        )
        self.assertEqual(
            disabled_ids | set(bidmachine["skadnetwork_ids"]),
            set(identifier_pattern.findall(bidmachine_enabled)),
        )

    def test_google_app_ids_are_conditional_manifest_values(self) -> None:
        android_manifest = (
            EXTENSION / "manifests/android/AndroidManifest.xml"
        ).read_text(encoding="utf-8")
        ios_plist = (
            EXTENSION / "manifests/ios/Info.plist"
        ).read_text(encoding="utf-8")
        self.assertIn(
            "{{#applovin.google_android_app_id}}", android_manifest
        )
        self.assertIn(
            "{{applovin.google_android_app_id}}", android_manifest
        )
        self.assertIn("{{#applovin.google_ios_app_id}}", ios_plist)
        self.assertIn("{{applovin.google_ios_app_id}}", ios_plist)

    def test_adapter_generator_is_deterministic(self) -> None:
        result = subprocess.run(
            [
                sys.executable,
                "-B",
                str(ROOT / "updater/adapters.py"),
                "check",
            ],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            0,
            result.returncode,
            msg=f"{result.stdout}\n{result.stderr}",
        )


if __name__ == "__main__":
    unittest.main()
