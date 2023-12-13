local log = require("example.log")
local ad_test = require("example.ad_test")

local M = {}

local function callback_logger(name, params)
    print(name)
    local msg = log.get_table_as_str(params)
    if msg then
        print(msg)
    end
    print("\n")
end

local function applovin_callback(self, name, params)
    print(name)

    if name == "OnSdkInitializedEvent" then
        gui.set_text(gui.get_node("init_status"), "SDK Initiailized")
    end
    
    if name == "OnInterstitialAdLoadedEvent" or
    name == "OnRewardedAdLoadedEvent" or
    name == "OnMRecAdLoadedEvent" or
    name == "OnBannerAdLoadedEvent" then
        ad_test.on_ad_loaded(params)
    end
end

function M.set()
    applovin.set_callback(applovin_callback)
end

return M