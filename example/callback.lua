local log = require("example.log")
local ads = require("example.ads")

local M = {}

local function applovin_callback(self, name, params)
    print(name)

    if name == "OnSdkInitializedEvent" then
        gui.set_text(gui.get_node("init_status"), "SDK Initiailized")
    end
    
    if name == "OnInterstitialAdLoadedEvent" or
    name == "OnRewardedAdLoadedEvent" or
    name == "OnMRecAdLoadedEvent" or
    name == "OnBannerAdLoadedEvent" then
        ads.on_ad_loaded(params)
    end

    if name == "OnInterstitialAdLoadFailedEvent" or
    name == "OnRewardedAdLoadFailedEvent" or
    name == "OnMRecAdLoadFailedEvent" or
    name == "OnBannerAdLoadFailedEvent" then
        ads.on_ad_load_failed(params)
    end
end

function M.set()
    applovin.set_callback(applovin_callback)
end

return M