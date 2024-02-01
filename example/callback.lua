local log = require("example.log")
local ads = require("example.ads")

local M = {}

local function applovin_callback(self, name, params)
    print(name)

    -- Uncomment the following line to also print the params table.
    -- print(log.get_table_as_str(params))

    if name == "OnSdkInitializedEvent" then
        gui.set_text(gui.get_node("init_status"), "SDK initialized in " .. params["countryCode"])
    end
    
    if name == "OnInterstitialAdLoadedEvent" or
    name == "OnRewardedAdLoadedEvent" or
    name == "OnBannerAdLoadedEvent" or
    name == "OnMRecAdLoadedEvent" then
        ads.on_ad_loaded(params)
    end

    if name == "OnInterstitialAdLoadFailedEvent" or
    name == "OnRewardedAdLoadFailedEvent" or
    name == "OnBannerAdLoadFailedEvent" or
    name == "OnMRecAdLoadFailedEvent" then
        ads.on_ad_load_failed(params)
    end

    -- For the full list of events and respective params, please see the main.gui_script file or the MAX documentations at https://dash.applovin.com/documentation/mediation/defold/getting-started/integration
end

function M.set()
    applovin.set_callback(applovin_callback)
end

return M
