# Migrating from 1.x

Version 2.0.0 updates AppLovin MAX from 12.2.0 to 13.6.3.

## 1. Update project requirements

Use Defold 1.13.0 or newer, Android API 24 or newer, and iOS 15 or newer.
Open `game.project` in the Defold editor and configure:

- **Android > Minimum SDK Version**: `24`

Under **Project > Dependencies**, replace the existing AppLovin MAX dependency
with:

```text
https://github.com/defold/AppLovin-MAX-Defold/archive/refs/tags/2.0.0.zip
```

Then select **Project > Fetch Libraries** from the main menu.

## 2. Move setup before initialization

Set the callback, privacy values, and test-device IDs before `initialize()`.
Load ads only after `OnSdkInitializedEvent`:

```lua
applovin.set_callback(max_callback)
applovin.set_has_user_consent(user_has_consented)
applovin.set_do_not_sell(user_opted_out)
applovin.set_test_device_advertising_ids(test_device_ids)
applovin.initialize(sdk_key)
```

`set_test_device_advertising_ids()` accepts one Lua array. Remove the `count`
argument shown in the old documentation.

## 3. Rename the Android MREC event

```text
OnMrecAdExpandedEvent   ->   OnMRecAdExpandedEvent
```

Callback tables also contain new optional fields. If your code validates an
exact set of keys, update it using the
[callback documentation](docs/index.md#callbacks).

## 4. Remove old workarounds

Version 2 fixes these 1.x behaviors:

- `set_interstitial_extra_parameter()` now applies to the interstitial, not the
  rewarded ad.
- iOS `track_event()` sends the supplied JSON parameters.
- Banner and MREC placement can be set before creating the view and is then
  included in the first load.

## 5. Configure adapters

Optional adapters are disabled by default. Remove manually added adapter
dependencies and enable the matching properties instead:

```ini
[applovin]
meta_android = 1
meta_ios = 1
```

See [Mediated networks](docs/index.md#mediated-networks) for available
properties and network-specific requirements.

The Android extension includes Google UMP 4.0.0. Update any dependency
constraint from another extension that forces an older UMP version.
