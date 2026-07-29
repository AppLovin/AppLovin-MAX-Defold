from __future__ import annotations

import copy
import contextlib
import hashlib
import importlib.util
import io
import json
import os
import plistlib
import re
import subprocess
import sys
import tempfile
import types
import unittest
import urllib.error
from unittest import mock
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXTENSION = ROOT / "extension-applovin"
CATALOG_PATH = ROOT / "updater/versions.json"


def load_common_module():
    module_path = ROOT / "updater/common.py"
    spec = importlib.util.spec_from_file_location(
        "applovin_updater_common", module_path
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to import {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_ios_updater_module():
    updater_path = str(ROOT / "updater")
    sys.path.insert(0, updater_path)
    try:
        module_path = ROOT / "updater/ios.py"
        spec = importlib.util.spec_from_file_location(
            "applovin_updater_ios", module_path
        )
        if spec is None or spec.loader is None:
            raise RuntimeError(f"Unable to import {module_path}")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        sys.path.remove(updater_path)


class PackagingContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))

    def test_catalog_has_consistent_core_sdk_pins(self) -> None:
        self.assertEqual(1, self.catalog["schema_version"])
        self.assertTrue(self.catalog["scope"]["core_sdk_only"])
        android = self.catalog["android"]
        self.assertGreaterEqual(android["target_sdk"], android["minimum_sdk"])
        for dependency in (android["sdk"], android["consent"]):
            self.assertTrue(
                dependency["coordinate"].endswith(
                    f":{dependency['version']}"
                )
            )
        self.assertEqual("AppLovinSDK", self.catalog["ios"]["pod"])

    def test_catalog_records_immutable_artifact_checksums(self) -> None:
        digests = [
            self.catalog["android"]["sdk"]["artifact_sha256"],
            self.catalog["android"]["sdk"]["consumer_rules_sha256"],
            self.catalog["android"]["consent"]["artifact_sha256"],
            self.catalog["android"]["consent"]["consumer_rules_sha256"],
            self.catalog["ios"]["podspec_sha256"],
            self.catalog["ios"]["archive_sha256"],
            self.catalog["ios"]["framework_info_sha256"],
            self.catalog["ios"]["privacy_manifest_sha256"],
            self.catalog["ios"]["resource_bundle"]["tree_sha256"],
        ]
        for digest in digests:
            with self.subTest(digest=digest):
                self.assertRegex(digest, r"^[0-9a-f]{64}$")

    def test_network_fetch_retries_transient_errors(self) -> None:
        common = load_common_module()
        response = mock.MagicMock()
        response.__enter__.return_value.read.return_value = b"ok"
        with (
            mock.patch.object(
                common.urllib.request,
                "urlopen",
                side_effect=[
                    urllib.error.URLError("temporary"),
                    response,
                ],
            ) as urlopen,
            mock.patch.object(common.time, "sleep") as sleep,
        ):
            self.assertEqual(
                b"ok",
                common.fetch_bytes("https://example.com/artifact", 1),
            )
        self.assertEqual(2, urlopen.call_count)
        sleep.assert_called_once_with(0.5)

    def test_network_fetch_does_not_retry_permanent_http_errors(self) -> None:
        common = load_common_module()
        error = urllib.error.HTTPError(
            "https://example.com/missing",
            404,
            "Not Found",
            {},
            None,
        )
        with mock.patch.object(
            common.urllib.request, "urlopen", side_effect=error
        ) as urlopen:
            with self.assertRaises(common.UpdaterError):
                common.fetch_bytes(
                    "https://example.com/missing", 1
                )
        self.assertEqual(1, urlopen.call_count)
        error.close()

    def test_generated_packaging_is_deterministic(self) -> None:
        for script in ("adapters.py", "android.py", "ios.py"):
            with self.subTest(script=script):
                result = subprocess.run(
                    [sys.executable, "-B", str(ROOT / "updater" / script), "check"],
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

    def test_android_manifest_and_gradle_baselines(self) -> None:
        manifest = (
            EXTENSION / "manifests/android/AndroidManifest.xml"
        ).read_text(encoding="utf-8")
        gradle = (
            EXTENSION / "manifests/android/build.gradle"
        ).read_text(encoding="utf-8")
        android = self.catalog["android"]
        self.assertIn(
            f'android:minSdkVersion="{android["minimum_sdk"]}"',
            manifest,
        )
        self.assertIn(
            f"implementation '{android['sdk']['coordinate']}'", gradle
        )
        self.assertIn(
            f"implementation '{android['consent']['coordinate']}'",
            gradle,
        )
        self.assertIn("google()", gradle)
        self.assertIn("mavenCentral()", gradle)

    def test_android_extension_proguard_rules_match_catalog(self) -> None:
        android = self.catalog["android"]
        proguard_files = sorted(
            (EXTENSION / "manifests/android").glob("*.pro")
        )
        self.assertEqual(
            [EXTENSION / "manifests/android/proguard-rules.pro"],
            proguard_files,
        )
        rules = proguard_files[0].read_text(encoding="utf-8")
        expected = (
            "# Generated by updater/android.py from updater/versions.json.\n"
            f"# AppLovin MAX {android['sdk']['version']} consumer rules.\n\n"
            + "\n".join(android["sdk"]["consumer_rules"])
            + "\n\n"
            f"# Google UMP {android['consent']['version']} consumer rules.\n"
            "# Generated proto fields are accessed reflectively.\n"
            + "\n".join(android["consent"]["consumer_rules"])
            + "\n\n"
            "# Defold resolves this JNI bridge by class and method names.\n"
            "-keep class com.defold.applovin.MaxDefoldPlugin { *; }\n"
        )
        self.assertEqual(expected, rules)

    def test_ios_pod_and_linker_baselines(self) -> None:
        podfile = (
            EXTENSION / "manifests/ios/Podfile"
        ).read_text(encoding="utf-8")
        ext_manifest = (EXTENSION / "ext.manifest").read_text(encoding="utf-8")
        ios = self.catalog["ios"]
        self.assertIn(
            f"platform :ios, '{ios['minimum_version']}'", podfile
        )
        self.assertIn(
            f"pod '{ios['pod']}', '{ios['version']}'", podfile
        )
        for framework in self.catalog["ios"]["frameworks"]:
            with self.subTest(framework=framework):
                self.assertIn(f'"{framework}"', ext_manifest)
        self.assertIn('"CoreHaptics"', ext_manifest)
        self.assertIn('weakFrameworks: ["AppTrackingTransparency"]', ext_manifest)
        self.assertIn('libs: ["z"]', ext_manifest)
        self.assertIn('"-fobjc-arc"', ext_manifest)

    def test_ios_manifest_contains_official_skadnetwork_catalog(self) -> None:
        manifest = (
            EXTENSION / "manifests/ios/Info.plist"
        ).read_text(encoding="utf-8")
        identifiers = re.findall(
            r"<string>([a-z0-9]{10}\.skadnetwork)</string>",
            manifest.split("{{#applovin.", 1)[0],
        )
        self.assertEqual(
            self.catalog["ios"]["skadnetwork_ids"],
            identifiers,
        )
        self.assertEqual(len(identifiers), len(set(identifiers)))
        self.assertIn("<key merge='keep'>SKAdNetworkItems</key>", manifest)

    def test_ios_default_command_runs_full_update(self) -> None:
        ios_updater = load_ios_updater_module()
        calls: list[str] = []

        def sync_skadnetwork(args, generate=True) -> int:
            del args
            self.assertFalse(generate)
            calls.append("skadnetwork")
            return 0

        def sync_resources(args) -> int:
            del args
            calls.append("resources")
            return 0

        def generate(args, check) -> int:
            del args
            self.assertFalse(check)
            calls.append("manifests")
            return 0

        with (
            mock.patch.object(
                ios_updater,
                "sync_skadnetwork",
                side_effect=sync_skadnetwork,
            ),
            mock.patch.object(
                ios_updater,
                "sync_resources",
                side_effect=sync_resources,
            ),
            mock.patch.object(
                ios_updater,
                "generate_or_check",
                side_effect=generate,
            ),
        ):
            result = ios_updater.main([])

        self.assertEqual(0, result)
        self.assertEqual(
            ["skadnetwork", "resources", "manifests"],
            calls,
        )

    def test_extension_version_and_demo_key_contract(self) -> None:
        properties = (EXTENSION / "ext.properties").read_text(encoding="utf-8")
        self.assertRegex(
            properties, r"(?m)^version\.default\s*=\s*2\.0\.0\s*$"
        )
        self.assertNotRegex(
            properties, r"(?m)^demo_sdk_key\.private\s*="
        )
        self.assertRegex(
            properties, r"(?m)^demo_sdk_key\.type\s*=\s*string\s*$"
        )
        self.assertRegex(
            properties, r"(?m)^demo_sdk_key\.default\s*=\s*$"
        )
        self.assertIn("Demo SDK Key (example only)", properties)

    def test_example_project_uses_supported_platform_baselines(self) -> None:
        project = (ROOT / "game.project").read_text(encoding="utf-8")
        self.assertRegex(
            project, r"(?m)^version\s*=\s*2\.0\.0\s*$"
        )
        self.assertRegex(
            project, r"(?m)^demo_sdk_key\s*=\s*\S+\s*$"
        )
        example = (ROOT / "example/main.gui_script").read_text(
            encoding="utf-8"
        )
        self.assertIn("sys.get_engine_info().is_debug", example)
        self.assertRegex(
            example,
            r"(?s)if not IS_DEBUG_BUILD then.*?return.*?"
            r"applovin\.initialize\(SDK_KEY\)",
        )
        self.assertRegex(
            project, r"(?m)^defold_min_version\s*=\s*1\.13\.0\s*$"
        )
        android = self.catalog["android"]
        self.assertRegex(
            project,
            rf"(?m)^minimum_sdk_version\s*=\s*"
            rf"{android['minimum_sdk']}\s*$",
        )
        self.assertRegex(
            project,
            rf"(?m)^target_sdk_version\s*=\s*"
            rf"{android['target_sdk']}\s*$",
        )

    def test_ios_resources_are_platform_neutral_official_payload(self) -> None:
        common = load_common_module()
        bundle = EXTENSION / "res/ios/AppLovinSDKResources.bundle"
        digest, count = common.tree_sha256(bundle)
        expected = self.catalog["ios"]["resource_bundle"]
        self.assertEqual(expected["tree_sha256"], digest)
        self.assertEqual(expected["file_count"], count)
        self.assertTrue(
            (bundle / f"omsdk-v{expected['omid_version']}.js").is_file()
        )
        self.assertFalse((bundle / "omsdk-v1.4.9.js").exists())
        self.assertFalse((bundle / "PrivacyInfo.xcprivacy").exists())
        self.assertFalse((bundle.parent / "PrivacyInfo.xcprivacy").exists())
        self.assertFalse((bundle / "_CodeSignature").exists())

        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        self.assertEqual("com.applovin.sdk.resources", info["CFBundleIdentifier"])
        self.assertEqual(
            self.catalog["ios"]["minimum_version"],
            info["MinimumOSVersion"],
        )
        slice_specific = {
            key
            for key in info
            if key in {
                "CFBundleSupportedPlatforms",
                "UIRequiredDeviceCapabilities",
            }
            or key.startswith(("DTPlatform", "DTSDK"))
        }
        self.assertEqual(set(), slice_specific)

    def test_catalog_loader_accepts_future_release_values(self) -> None:
        future = copy.deepcopy(self.catalog)
        future["android"]["minimum_sdk"] = 26
        future["android"]["target_sdk"] = 38
        future["ios"]["minimum_version"] = "14.0"
        future["ios"]["version"] = "99.0.0"
        future["ios"]["resource_bundle"]["file_count"] = 47
        future["ios"]["compile_flags"].append("-DAPPLOVIN_FUTURE=1")

        loaded = self._load_catalog_value(future)
        self.assertEqual(26, loaded["android"]["minimum_sdk"])
        self.assertEqual("99.0.0", loaded["ios"]["version"])
        self.assertEqual(47, loaded["ios"]["resource_bundle"]["file_count"])

    def test_ios_resource_normalization_is_slice_neutral(self) -> None:
        ios_updater = load_ios_updater_module()
        common = load_common_module()
        with tempfile.TemporaryDirectory(
            prefix="applovin-slice-test-"
        ) as directory:
            bundles = []
            for name, platform, sdk, capability in (
                ("device", "iPhoneOS", "iphoneos18.0", ["arm64"]),
                (
                    "simulator",
                    "iPhoneSimulator",
                    "iphonesimulator18.0",
                    None,
                ),
            ):
                bundle = Path(directory) / name / "Resources.bundle"
                signature = bundle / "_CodeSignature"
                signature.mkdir(parents=True)
                (bundle / "payload.txt").write_text(
                    "same payload\n", encoding="utf-8"
                )
                (signature / "CodeSignature").write_bytes(
                    name.encode("utf-8")
                )
                info = {
                    "CFBundleIdentifier": "com.applovin.sdk.resources",
                    "CFBundleSupportedPlatforms": [platform],
                    "DTPlatformName": platform.lower(),
                    "DTSDKName": sdk,
                    "MinimumOSVersion": self.catalog[
                        "ios"
                    ]["minimum_version"],
                }
                if capability is not None:
                    info["UIRequiredDeviceCapabilities"] = capability
                (bundle / "Info.plist").write_bytes(
                    plistlib.dumps(info, fmt=plistlib.FMT_BINARY)
                )
                ios_updater._normalize_resource_bundle(bundle)
                bundles.append(bundle)

            self.assertEqual(
                common.tree_sha256(bundles[0]),
                common.tree_sha256(bundles[1]),
            )
            self.assertFalse(
                (bundles[0] / "_CodeSignature").exists()
            )
            self.assertFalse(
                (bundles[1] / "_CodeSignature").exists()
            )

    def test_ios_refresh_verifies_podspec_and_exact_sdk_archive(self) -> None:
        ios_updater = load_ios_updater_module()
        catalog = copy.deepcopy(self.catalog)
        ios = catalog["ios"]
        podspec = {
            "name": ios["pod"],
            "version": ios["version"],
            "platforms": {
                "ios": ios["minimum_version"],
                "visionos": "1.0",
            },
            "source": {"http": ios["archive_url"]},
            "frameworks": ios["frameworks"],
            "weak_frameworks": ios["weak_frameworks"][0],
            "libraries": ios["libraries"][0],
        }
        podspec_bytes = json.dumps(
            podspec, separators=(",", ":")
        ).encode("utf-8")
        archive_bytes = b"exact pinned AppLovin archive fixture"
        ios["podspec_sha256"] = hashlib.sha256(podspec_bytes).hexdigest()
        ios["archive_sha256"] = hashlib.sha256(archive_bytes).hexdigest()
        fetched_urls: list[str] = []

        def fetch_bytes(url: str, timeout: float) -> bytes:
            del timeout
            fetched_urls.append(url)
            if url == ios["podspec_url"]:
                return podspec_bytes
            if url == ios["archive_url"]:
                return archive_bytes
            raise AssertionError(url)

        output = io.StringIO()
        errors = io.StringIO()
        adapter_ids = {
            key: network.get("skadnetwork_ids", [])
            for key, network in json.loads(
                (ROOT / "updater/adapters.json").read_text(
                    encoding="utf-8"
                )
            )["ios"]["networks"].items()
        }

        with (
            mock.patch.object(
                ios_updater, "load_catalog", return_value=catalog
            ),
            mock.patch.object(
                ios_updater,
                "fetch_json",
                return_value={"version": ios["version"]},
            ),
            mock.patch.object(
                ios_updater,
                "fetch_all_skadnetwork_ids",
                return_value=(ios["skadnetwork_ids"], adapter_ids),
            ),
            mock.patch.object(
                ios_updater, "fetch_bytes", side_effect=fetch_bytes
            ),
            contextlib.redirect_stdout(output),
            contextlib.redirect_stderr(errors),
        ):
            result = ios_updater.refresh(
                types.SimpleNamespace(timeout=1.0, workers=1)
            )

        self.assertEqual(0, result)
        self.assertEqual(
            [ios["podspec_url"], ios["archive_url"]],
            fetched_urls,
        )
        self.assertIn(
            "verified: pinned AppLovin SDK archive SHA-256",
            output.getvalue(),
        )
        self.assertEqual("", errors.getvalue())

    def test_ios_refresh_fails_on_archive_checksum_mismatch(self) -> None:
        ios_updater = load_ios_updater_module()
        catalog = copy.deepcopy(self.catalog)
        ios = catalog["ios"]
        podspec = {
            "name": ios["pod"],
            "version": ios["version"],
            "platforms": {"ios": ios["minimum_version"]},
            "source": {"http": ios["archive_url"]},
            "frameworks": ios["frameworks"],
            "weak_frameworks": ios["weak_frameworks"],
            "libraries": ios["libraries"],
        }
        podspec_bytes = json.dumps(podspec).encode("utf-8")
        ios["podspec_sha256"] = hashlib.sha256(podspec_bytes).hexdigest()

        output = io.StringIO()
        errors = io.StringIO()
        adapter_ids = {
            key: network.get("skadnetwork_ids", [])
            for key, network in json.loads(
                (ROOT / "updater/adapters.json").read_text(
                    encoding="utf-8"
                )
            )["ios"]["networks"].items()
        }

        with (
            mock.patch.object(
                ios_updater, "load_catalog", return_value=catalog
            ),
            mock.patch.object(
                ios_updater,
                "fetch_json",
                return_value={"version": ios["version"]},
            ),
            mock.patch.object(
                ios_updater,
                "fetch_all_skadnetwork_ids",
                return_value=(ios["skadnetwork_ids"], adapter_ids),
            ),
            mock.patch.object(
                ios_updater,
                "fetch_bytes",
                side_effect=(podspec_bytes, b"wrong archive"),
            ),
            contextlib.redirect_stdout(output),
            contextlib.redirect_stderr(errors),
        ):
            result = ios_updater.refresh(
                types.SimpleNamespace(timeout=1.0, workers=1)
            )

        self.assertEqual(1, result)
        self.assertIn(
            "AppLovin SDK archive checksum mismatch",
            errors.getvalue(),
        )

    def test_catalog_loader_rejects_invalid_types_and_security_values(
        self,
    ) -> None:
        mutations = {
            "boolean schema": lambda value: value.update(
                schema_version=True
            ),
            "boolean SDK": lambda value: value["android"].update(
                minimum_sdk=True
            ),
            "target below minimum": lambda value: value["android"].update(
                minimum_sdk=30, target_sdk=29
            ),
            "insecure archive URL": lambda value: value["ios"].update(
                archive_url="http://example.com/sdk.zip"
            ),
            "unsafe archive path": lambda value: value["ios"].update(
                device_framework_subpath="../AppLovinSDK.framework"
            ),
            "invalid SKAdNetwork identifier": lambda value: value[
                "ios"
            ].update(skadnetwork_ids=["not-an-identifier"]),
            "missing ARC": lambda value: value["ios"].update(
                compile_flags=["-Wall"]
            ),
            "boolean file count": lambda value: value[
                "ios"
            ]["resource_bundle"].update(file_count=True),
            "multiline consumer rule": lambda value: value[
                "android"
            ]["sdk"]["consumer_rules"].append("-keep class A\n-dontwarn B"),
        }
        common = load_common_module()
        for label, mutate in mutations.items():
            with self.subTest(label=label):
                invalid = copy.deepcopy(self.catalog)
                mutate(invalid)
                with self.assertRaises(common.UpdaterError):
                    self._load_catalog_value(invalid, common)

    @staticmethod
    def _load_catalog_value(
        value: dict, common=None
    ) -> dict:
        if common is None:
            common = load_common_module()
        with tempfile.TemporaryDirectory(
            prefix="applovin-catalog-test-"
        ) as directory:
            path = Path(directory) / "versions.json"
            path.write_text(json.dumps(value), encoding="utf-8")
            common.CATALOG_PATH = path
            return common.load_catalog()

    def test_stale_sdk_and_extension_pins_are_gone(self) -> None:
        text_suffixes = {
            ".cpp",
            ".gradle",
            ".h",
            ".java",
            ".json",
            ".lua",
            ".manifest",
            ".md",
            ".mm",
            ".plist",
            ".project",
            ".properties",
            ".py",
            ".script_api",
            ".yaml",
            ".yml",
        }
        stale = re.compile(
            r"12\.2\.0|"
            r"version\.default\s*=\s*1\.1\.0|"
            r"Defold-1\.1\.0|"
            r"https://developers\.applovin\.com"
        )
        findings: list[str] = []
        for path in ROOT.rglob("*"):
            if not path.is_file() or path.suffix not in text_suffixes:
                continue
            if ".git" in path.parts or "build" in path.parts:
                continue
            if path.name.upper().startswith("MIGRATION"):
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            for line_number, line in enumerate(text.splitlines(), start=1):
                if stale.search(line):
                    findings.append(
                        f"{path.relative_to(ROOT)}:{line_number}: {line.strip()}"
                    )
        self.assertEqual([], findings, msg="\n".join(findings))

    def test_bob_workflow_pins_mobile_builds_and_runs_contracts(self) -> None:
        workflow = (ROOT / ".github/workflows/bob.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("updater/adapters.py check", workflow)
        self.assertIn("updater/android.py check", workflow)
        self.assertIn("updater/ios.py check", workflow)
        self.assertIn("unittest discover -s tests -v", workflow)
        self.assertIn("needs: verify", workflow)
        self.assertIn(
            "b3036943f78ec977f3b3fad54ea7117bfe9eb61a59621cd387fe520fa2934282",
            workflow,
        )
        self.assertIn(
            "22e651025834603794ba6873b09924f11412dff66eee0e38aaef8955eb534655",
            workflow,
        )
        self.assertIn("https://build.defold.com", workflow)
        self.assertIn("https://build-stage.defold.com", workflow)
        self.assertIn("sha256sum -c -", workflow)
        self.assertIn("shasum -a 256 -c -", workflow)
        self.assertIn("--platform=armv7-android", workflow)
        self.assertIn(
            "--architectures=armv7-android,arm64-android",
            workflow,
        )
        self.assertIn("--platform=arm64-ios", workflow)
        self.assertIn(
            "test_bob_ipa_preserves_framework_privacy_manifest",
            workflow,
        )
        self.assertNotIn("bob_jar_sha256:", workflow)

    @unittest.skipUnless(
        os.environ.get("APPLOVIN_IPA"),
        "set APPLOVIN_IPA to validate a Bob-generated IPA",
    )
    def test_bob_ipa_preserves_framework_privacy_manifest(self) -> None:
        ipa_path = Path(os.environ["APPLOVIN_IPA"])
        self.assertTrue(ipa_path.is_file(), ipa_path)
        with zipfile.ZipFile(ipa_path) as archive:
            privacy_manifests = [
                name
                for name in archive.namelist()
                if name.endswith(
                    "/Frameworks/AppLovinSDK.framework/PrivacyInfo.xcprivacy"
                )
            ]
            self.assertEqual(1, len(privacy_manifests), archive.namelist())
            privacy = archive.read(privacy_manifests[0])
        self.assertEqual(
            self.catalog["ios"]["privacy_manifest_sha256"],
            __import__("hashlib").sha256(privacy).hexdigest(),
        )
