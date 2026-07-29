# AppLovin MAX for Defold

This guide covers installation, initialization, ad formats, privacy, testing,
and mediated networks. The complete Lua API is documented in
[`applovin.script_api`](../extension-applovin/api/applovin.script_api).

If you are upgrading from 1.x, start with the
[migration guide](../MIGRATION.md).

## Requirements

| Component | Minimum |
| --- | --- |
| Defold | 1.13.0 |
| Android | API 24 |
| iOS | iOS 15 |
| AppLovin MAX | 13.6.3 |

## Install

Open `game.project` in the Defold editor and select **Project** in the left
sidebar. Under **Dependencies**, click **+** and paste:

```text
https://github.com/defold/AppLovin-MAX-Defold/archive/refs/tags/2.0.0.zip
```

Then select **Project > Fetch Libraries** from the main menu.

In the `game.project` editor, also configure:

- **Android > Minimum SDK Version**: `24`
- **AppLovin > iOS User Tracking Usage Description**: a message explaining
  why your app requests permission to use device information for advertising

Register your Android package and iOS bundle identifier in MAX. Use the SDK key
from **Account > General > Keys**, and create separate ad units for each
platform and format.

The extension is not available on desktop or HTML5. Guard shared code:

```lua
if applovin then
    -- Android or iOS
end
```

## Initialize MAX

MAX initializes asynchronously:

1. Collect any required privacy choice.
2. Register the callback.
3. Apply privacy, test-device, and SDK settings.
4. Call `initialize()` once.
5. Wait for `OnSdkInitializedEvent`.
6. Load ads.

```lua
local interstitial_id = "YOUR_INTERSTITIAL_AD_UNIT_ID"

local function max_callback(self, event, data)
    if event == "OnSdkInitializedEvent" then
        applovin.load_interstitial(interstitial_id)
    elseif event == "OnInterstitialAdLoadFailedEvent" then
        print("MAX load failed", data.code, data.message)
    elseif event == "OnInterstitialAdRevenuePaidEvent" then
        print("MAX revenue", data.revenue, data.revenuePrecision)
    end
end

function init(self)
    applovin.set_callback(max_callback)

    -- Values supplied by your consent UI or CMP:
    applovin.set_has_user_consent(user_has_consented)
    applovin.set_do_not_sell(user_opted_out)

    applovin.initialize("YOUR_APPLOVIN_SDK_KEY")
end

function final(self)
    applovin.set_callback(nil)
end
```

`is_initialized()` becomes `true` after initialization completes. Handle
`OnSdkInitializedEvent` when loading the first ads instead of polling it.

## Privacy and consent

Your application is responsible for choosing the correct disclosures and
consent flow. Apply `set_has_user_consent()` and `set_do_not_sell()` before
initialization and persist the user's choice in your own system. Their getters
return booleans and cannot distinguish “unset” from `false`.

Follow AppLovin's current
[privacy guide](https://support.applovin.com/en/max/defold/overview/privacy).
Do not initialize AppLovin for users or apps prohibited by that policy.

### MAX consent flow

The MAX Terms and Privacy Policy Flow is optional. Before enabling it:

- publish the required message in the AdMob dashboard;
- include every mediated partner;
- configure the required Google app IDs and dependencies;
- use real public privacy-policy and terms URLs;
- follow the
  [official consent-flow guide](https://support.applovin.com/en/max/defold/overview/terms-and-privacy-policy-flow).

Configure the flow before initialization:

```lua
applovin.set_terms_and_privacy_policy_flow_enabled(true)
applovin.set_privacy_policy_url("https://example.com/privacy")
applovin.set_terms_of_service_url("https://example.com/terms") -- optional
applovin.initialize("YOUR_APPLOVIN_SDK_KEY")
```

Android builds include Google UMP 4.0.0. If another extension also declares
UMP, do not force an older version. On iOS, enable the appropriate Google
adapter and app ID when required by your consent setup.

After initialization, `has_supported_cmp()` tells you whether
`show_cmp_for_existing_user()` can present a **Manage privacy settings**
screen. Completion is reported through `OnCmpCompletedEvent`.

### Store requirements

Review the final application—not only the base extension—for permissions,
privacy declarations, and mediated SDK data collection:

- [Apple privacy manifests](https://support.applovin.com/en/max/defold/overview/privacy-manifests)
- [SKAdNetwork IDs](https://support.applovin.com/en/max/defold/overview/skadnetwork)
- Google Play Data safety
- App Store privacy disclosures

The extension includes AppLovin's current list automatically. Enabling an iOS
adapter also includes that network's current identifiers. App-specific entries
from another manifest are merged with these lists.

## Test devices and debuggers

Set test-device IDs before initialization:

```lua
applovin.set_test_device_advertising_ids({
    "YOUR_IDFA_OR_GAID",
})
```

Use only identifiers from your QA devices and remove them from production
configuration.

After initialization, call `show_mediation_debugger()` from a visible QA
button. Use it to verify the SDK key, adapters, privacy state, test mode, CMP,
and ad units. Enable verbose logging and the Creative Debugger only in
development builds.

## Ad formats

All ad calls require an ad-unit ID for the current package or bundle
identifier.

### Interstitial

```lua
applovin.load_interstitial(ad_unit_id)

-- After OnInterstitialAdLoadedEvent:
if applovin.is_interstitial_ready(ad_unit_id) then
    applovin.show_interstitial(ad_unit_id, "level_complete")
end
```

Load the next ad after the previous one is hidden or fails.

### Rewarded

```lua
applovin.load_rewarded_ad(ad_unit_id)

-- After OnRewardedAdLoadedEvent:
if applovin.is_rewarded_ad_ready(ad_unit_id) then
    applovin.show_rewarded_ad(ad_unit_id, "daily_reward")
end
```

Grant rewards only from `OnRewardedAdReceivedRewardEvent`, using its `label`
and `amount`.

### Banner

```lua
applovin.set_banner_placement(ad_unit_id, "main_menu")
applovin.create_banner(ad_unit_id, "bottom_center")
applovin.set_banner_background_color(ad_unit_id, "#000000")

applovin.hide_banner(ad_unit_id)
applovin.show_banner(ad_unit_id)
applovin.update_banner_position(ad_unit_id, "top_center")
applovin.stop_banner_auto_refresh(ad_unit_id)
applovin.start_banner_auto_refresh(ad_unit_id)
applovin.destroy_banner(ad_unit_id)
```

Set placement before creation so it is included in the first load. Destroy the
view when its screen no longer needs it.

### MREC

```lua
applovin.set_mrec_placement(ad_unit_id, "store")
applovin.create_mrec(ad_unit_id, "centered")

applovin.hide_mrec(ad_unit_id)
applovin.show_mrec(ad_unit_id)
applovin.update_mrec_position(ad_unit_id, "bottom_center")
applovin.stop_mrec_auto_refresh(ad_unit_id)
applovin.start_mrec_auto_refresh(ad_unit_id)
applovin.destroy_mrec(ad_unit_id)
```

MREC event names use `MRec`, including `OnMRecAdExpandedEvent`.

### Extra parameters

Each format has its own extra-parameter function:

```lua
applovin.set_interstitial_extra_parameter(ad_unit_id, key, value)
applovin.set_rewarded_ad_extra_parameter(ad_unit_id, key, value)
applovin.set_banner_extra_parameter(ad_unit_id, key, value)
applovin.set_mrec_extra_parameter(ad_unit_id, key, value)
```

Only use keys documented by AppLovin or the mediated network.

## Callbacks

The callback signature is:

```lua
function(self, event_name, params)
```

Callbacks run from the Defold update thread. Keep them short. The complete
event and constant list is in
[`applovin.script_api`](../extension-applovin/api/applovin.script_api).

Ad payloads can include:

- `adUnitIdentifier`, `format`, `placement`
- `networkName`, `networkPlacement`, `creativeIdentifier`
- `revenue`, `revenuePrecision`
- `requestLatencyMillis`
- `dspName`, `dspIdentifier`

Some mediated networks omit fields they cannot provide. Load failures contain
`code`, `message`, and request latency. Display failures can also contain
`mediatedNetworkErrorCode` and `mediatedNetworkErrorMessage`. See the official
[error reference](https://support.applovin.com/en/max/defold/overview/error-handling).

## Mediated networks

The base extension includes MAX but no optional third-party adapters. Enable
only the networks used by your MAX account:

```ini
[applovin]
meta_android = 1
meta_ios = 1
```

Android and iOS switches are independent. Available property names and pinned
versions are listed in
[`updater/adapters.json`](../updater/adapters.json).

Google also requires an application ID:

```ini
[applovin]
google_android = 1
google_android_app_id = ca-app-pub-0000000000000000~0000000000

google_ios = 1
google_ios_app_id = ca-app-pub-0000000000000000~0000000000
```

Follow the
[official mediated-network guide](https://support.applovin.com/en/max/defold/preparing-mediated-networks)
for account setup, permissions, manifests, privacy disclosures, and any extra
initialization. Re-run the Mediation Debugger after changing adapters.

## Custom events

`track_event()` takes a non-empty event name and a JSON object:

```lua
applovin.track_event("level_complete", json.encode({
    level = 12,
    difficulty = "hard",
}))
```

Invalid JSON is logged and sent as an empty parameter map.

## Example project

The repository example includes a demo SDK key:

- debug builds initialize MAX and can open the Mediation Debugger;
- release builds do not pass the demo key to MAX;
- ad formats remain disabled until you add matching Android or iOS ad-unit IDs
  through **Project Settings > AppLovin**.

## Troubleshooting

- **The example does not initialize:** release builds intentionally skip the
  demo key. In debug builds, verify `applovin.demo_sdk_key` in the bundled
  `game.projectc`.
- **No fill / error 204:** check the app identity, ad unit, test device,
  dashboard setup, and installed adapters in the Mediation Debugger.
- **An ad does not show:** wait for its loaded event and check `is_*_ready()`
  immediately before showing.
- **A banner or MREC remains visible:** destroy it when leaving its screen.
- **The CMP is unavailable:** check the Google dependency, app ID, published
  message, and the debugger's CMP section.

For repository builds and releases, see
[DEVELOPMENT.md](../DEVELOPMENT.md).
