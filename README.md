
# AppLovin-MAX-Defold

AppLovin MAX Defold Plugin for Android and iOS

## Documentation

Please check out our [documentation](https://developers.applovin.com/en/defold/overview/integration) to get started on integrating and enabling mediated networks using our guides.

## Demo App

To get started with the demo app, follow the instructions below:

1. Clone this repository and open the `game.project` file in Defold editor.
2. For iOS, update the **Bundle Identifier** with the unique identifier associated with the app you will create or have already created in the MAX dashboard. Also update the extension property `ios_user_tracking_usage_description` for tracking authorization prompt in iOS 14+.
	```
	[ios]  
	bundle_identifier = YOUR_BUNDLE_IDENTIFIER  
	  
	[applovin]  
	ios_user_tracking_usage_description = YOUR_USAGE_DESCRIPTION
	```

3. For Android, Update the  **Package Name**  with the unique identifier associated with the app you will create or have already created in the MAX dashboard. 
	```
	[android]  
	package = YOUR_PACKAGE_NAME
	```

4. Open the `example/main.gui_script` file and update the `SDK_KEY` value with the AppLovin SDK key associated with your account.
	```lua
	local SDK_KEY = "YOUR_SDK_KEY_HERE"
	```

5. Open the `example/ads.lua` file and update the MAX ad unit IDs for the ad formats you would like to test. Each ad format will correspond to a unique MAX ad unit ID you created in the AppLovin dashboard for the bundle ID used before.
	```lua
	local ios_ad_units = { 
		Interstitial = "ENTER_IOS_INTERSTITIAL_AD_UNIT_ID_HERE",
		Rewarded = "ENTER_IOS_REWARDED_AD_UNIT_ID_HERE",
		Banner = "ENTER_IOS_BANNER_AD_UNIT_ID_HERE",
		MRec = "ENTER_IOS_MREC_AD_UNIT_ID_HERE"
	}

	local android_ad_units = {
		Interstitial = "ENTER_ANDROID_INTERSTITIAL_AD_UNIT_ID_HERE",
		Rewarded = "ENTER_ANDROID_REWARDED_AD_UNIT_ID_HERE",
		Banner = "ENTER_ANDROID_BANNER_AD_UNIT_ID_HERE",
		MRec = "ENTER_ANDROID_MREC_AD_UNIT_ID_HERE"
	}
	```
	
6. Deploy the demo app to a platform by selecting **Project > Bundle**.

## License

MIT
