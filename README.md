# AppLovin MAX for Defold

Native AppLovin MAX extension for Defold on Android and iOS. It supports
interstitial, rewarded, banner, and MREC ads, along with MAX debugging,
consent, test-device, custom-event, and revenue APIs.

Version 2.0.0 uses AppLovin MAX 13.6.3 and requires:

- Defold 1.13.0 or newer
- Android API 24 or newer
- iOS 15.0 or newer

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

## Initialize

Register the callback and apply privacy settings before initialization. Wait
for `OnSdkInitializedEvent` before loading ads:

```lua
local function max_callback(self, event, data)
    if event == "OnSdkInitializedEvent" then
        applovin.load_interstitial("YOUR_INTERSTITIAL_AD_UNIT_ID")
    end
end

function init(self)
    applovin.set_callback(max_callback)
    applovin.set_has_user_consent(user_has_consented)
    applovin.set_do_not_sell(user_opted_out)
    applovin.initialize("YOUR_APPLOVIN_SDK_KEY")
end

function final(self)
    applovin.set_callback(nil)
end
```

Use an SDK key and platform-specific ad-unit IDs from the MAX dashboard for
your Android package and iOS bundle identifier.

## Mediated networks

Third-party adapters are disabled by default. Enable only the networks used by
your MAX account:

```ini
[applovin]
unity_ads_android = 1
unity_ads_ios = 1
```

Android and iOS are configured independently. Google adapters also require
`google_android_app_id` or `google_ios_app_id`. See the
[integration guide](docs/index.md#mediated-networks) for details.
On iOS, each enabled adapter also adds its official SKAdNetwork identifiers.

## Example project

The repository example contains a demo SDK key. Debug builds initialize MAX
and can open the Mediation Debugger; release builds do not pass the demo key to
MAX. Add your own ad-unit IDs to test ad formats.

## Documentation

- [Integration guide](docs/index.md)
- [Migration from 1.x](MIGRATION.md)
- [Development and release workflow](DEVELOPMENT.md)
- [Official AppLovin Defold documentation](https://support.applovin.com/en/max/defold/overview/integration)

Before shipping, review AppLovin's
[privacy guidance](https://support.applovin.com/en/max/defold/overview/privacy)
and the requirements of every enabled mediated network.

## License

MIT
