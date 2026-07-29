local log = require("example.log")
local ads = require("example.ads")

local M = {}

local LOADED_EVENTS = {
	OnInterstitialAdLoadedEvent = true,
	OnRewardedAdLoadedEvent = true,
	OnBannerAdLoadedEvent = true,
	OnMRecAdLoadedEvent = true,
}

local LOAD_FAILED_EVENTS = {
	OnInterstitialAdLoadFailedEvent = true,
	OnRewardedAdLoadFailedEvent = true,
	OnBannerAdLoadFailedEvent = true,
	OnMRecAdLoadFailedEvent = true,
}

local DISPLAY_FAILED_EVENTS = {
	OnInterstitialAdDisplayFailedEvent = true,
	OnRewardedAdDisplayFailedEvent = true,
}

local HIDDEN_EVENTS = {
	OnInterstitialAdHiddenEvent = true,
	OnRewardedAdHiddenEvent = true,
}

local function applovin_callback(self, name, params)
	print(name, log.get_table_as_str(params))

	if name == "OnSdkInitializedEvent" then
		ads.set_sdk_ready(true)
		local country_code = params.countryCode
		if not country_code or country_code == "" then
			country_code = "unknown country"
		end
		gui.set_text(gui.get_node("init_status"), "SDK initialized (" .. country_code .. ")")
	elseif LOADED_EVENTS[name] then
		ads.on_ad_loaded(params)
	elseif LOAD_FAILED_EVENTS[name] then
		ads.on_ad_load_failed(params)
	elseif DISPLAY_FAILED_EVENTS[name] then
		ads.on_ad_display_failed(params)
	elseif HIDDEN_EVENTS[name] then
		ads.on_ad_hidden(params)
	elseif name == "OnRewardedAdReceivedRewardEvent" then
		print("Reward earned:", params.amount, params.label)
	elseif name == "OnCmpCompletedEvent" and params.code then
		print("CMP failed:", params.code, params.message, params.cmpCode, params.cmpMessage)
	end
end

function M.set()
	if applovin then
		applovin.set_callback(applovin_callback)
	end
end

function M.clear()
	if applovin then
		applovin.set_callback(nil)
	end
end

return M
