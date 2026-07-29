from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXTENSION = ROOT / "extension-applovin"
CPP_PATH = EXTENSION / "src/applovin.cpp"
API_PATH = EXTENSION / "api/applovin.script_api"
JAVA_PATH = EXTENSION / "src/java/com/defold/applovin/MaxDefoldPlugin.java"
IOS_PATH = EXTENSION / "src/MADefoldPlugin.mm"


def documented_members() -> list[tuple[str, str]]:
    lines = API_PATH.read_text(encoding="utf-8").splitlines()
    members: list[tuple[str, str]] = []
    for index, line in enumerate(lines):
        match = re.match(r"^  - name: ([A-Za-z_][A-Za-z0-9_]*)\s*$", line)
        if not match:
            continue
        member_type = ""
        for following in lines[index + 1 : index + 5]:
            type_match = re.match(r"^    type: ([A-Za-z]+)\s*$", following)
            if type_match:
                member_type = type_match.group(1)
                break
            if following.startswith("  - name: "):
                break
        members.append((match.group(1), member_type))
    return members


class PublicApiContractTests(unittest.TestCase):
    def test_documented_member_names_are_unique(self) -> None:
        names = [name for name, _ in documented_members()]
        duplicates = sorted(
            name for name in set(names) if names.count(name) > 1
        )
        self.assertEqual([], duplicates)

    def test_lua_bindings_and_documented_functions_match(self) -> None:
        cpp = CPP_PATH.read_text(encoding="utf-8")
        bound = set(
            re.findall(
                r'\{\s*"([a-z][a-z0-9_]*)"\s*,\s*Lua_[A-Za-z0-9_]+\s*\}',
                cpp,
            )
        )
        documented = {
            name
            for name, member_type in documented_members()
            if member_type == "function"
        }
        self.assertEqual(documented, bound)

    def test_lua_constants_and_documented_constants_match(self) -> None:
        cpp = CPP_PATH.read_text(encoding="utf-8")
        bound = set(re.findall(r"SETCONSTANT\(([A-Z][A-Z0-9_]+)\)", cpp))
        documented = {
            name
            for name, member_type in documented_members()
            if member_type == "number"
        }
        self.assertEqual(documented, bound)

    def test_interstitial_parameter_is_bound_to_interstitial_handler(self) -> None:
        cpp = CPP_PATH.read_text(encoding="utf-8")
        match = re.search(
            r'\{\s*"set_interstitial_extra_parameter"\s*,\s*'
            r"(Lua_[A-Za-z0-9_]+)\s*\}",
            cpp,
        )
        self.assertIsNotNone(match)
        self.assertEqual("Lua_SetInterstitialExtraParameter", match.group(1))

    def test_android_initialization_waits_for_the_official_listener(self) -> None:
        java = JAVA_PATH.read_text(encoding="utf-8")
        self.assertNotIn("sdk.isInitialized()", java)
        self.assertNotIn("scheduleSdkInitializationPoll", java)
        self.assertIn("AppLovinSdk.SdkInitializationListener", java)
        self.assertLess(
            java.index("sharedSdkConfiguration = configuration"),
            java.index(
                '"complete SDK initialization"',
                java.index("sharedSdkConfiguration = configuration"),
            ),
        )

    def test_track_event_rejects_an_empty_name_before_platform_dispatch(self) -> None:
        cpp = CPP_PATH.read_text(encoding="utf-8")
        track_event = re.search(
            r"static int Lua_TrackEvent\(lua_State\* L\)\s*\{(?P<body>.*?)\n\}",
            cpp,
            re.DOTALL,
        )
        self.assertIsNotNone(track_event)
        body = track_event.group("body")
        self.assertIn("event[0] == '\\0'", body)
        self.assertLess(body.index("event[0]"), body.index("TrackEvent(event"))

    def test_ios_contains_track_event_sdk_exceptions(self) -> None:
        ios = IOS_PATH.read_text(encoding="utf-8")
        track_event = re.search(
            r"- \(void\)trackEvent:.*?\{(?P<body>.*?)\n\}",
            ios,
            re.DOTALL,
        )
        self.assertIsNotNone(track_event)
        body = track_event.group("body")
        sdk_call = "[self.sdk.eventService trackEvent: event parameters: parameters];"
        self.assertIn("event.length == 0", body)
        self.assertIn("@try", body)
        self.assertIn("@catch ( NSException *exception )", body)
        self.assertLess(body.index("@try"), body.index(sdk_call))
        self.assertLess(body.index(sdk_call), body.index("@catch"))

    def test_android_and_ios_emit_identical_public_event_names(self) -> None:
        android = set(
            re.findall(
                r'"(On[A-Za-z0-9]+Event)"',
                JAVA_PATH.read_text(encoding="utf-8"),
            )
        )
        ios = set(
            re.findall(
                r'@"(On[A-Za-z0-9]+Event)"',
                IOS_PATH.read_text(encoding="utf-8"),
            )
        )
        self.assertTrue(android)
        self.assertEqual(ios, android)
        self.assertIn("OnMRecAdExpandedEvent", android)
        self.assertNotIn("OnMrecAdExpandedEvent", android)

    def test_example_only_calls_documented_members(self) -> None:
        documented = {name for name, _ in documented_members()}
        calls: set[str] = set()
        scanned_gui_scripts = 0
        for pattern in ("*.lua", "*.gui_script"):
            for path in (ROOT / "example").rglob(pattern):
                scanned_gui_scripts += path.suffix == ".gui_script"
                calls.update(
                    re.findall(
                        r"\bapplovin\.([A-Za-z_][A-Za-z0-9_]*)\s*\(",
                        path.read_text(encoding="utf-8"),
                    )
                )
        self.assertGreater(scanned_gui_scripts, 0)
        self.assertEqual(set(), calls - documented)
