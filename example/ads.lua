local ui = require("example.ui")
local log = require("example.log")

local M = {}

local ios_ad_units = { 
	Interstitial_ = "ENTER_IOS_INTERSTITIAL_AD_UNIT_ID_HERE",
	Rewarded = "ENTER_IOS_REWARDED_AD_UNIT_ID_HERE",
	Banner = "ENTER_IOS_BANNER_AD_UNIT_ID_HERE",
	MRec = "ENTER_ANDROID_MREC_AD_UNIT_ID_HERE"
}

local android_ad_units = {
	Interstitial = "ENTER_ANDROID_INTERSTITIAL_AD_UNIT_ID_HERE",
	Rewarded = "ENTER_ANDROID_REWARDED_AD_UNIT_ID_HERE",
	Banner = "ENTER_ANDROID_BANNER_AD_UNIT_ID_HERE",
	MRec = "ENTER_ANDROID_MREC_AD_UNIT_ID_HERE"
}

local ui_components = {}

local selected_ad_type = ""
local ad_unit = ""
local isShowingAd = false;

local function reset_ui_components()
	ui_components = { 
		ad_type_text = gui.get_node("ad_type"),
		load_button = gui.get_node("load/larrybutton"),
		load_button_label = gui.get_node("load/larrylabel"),
		loading_text = gui.get_node("loading")
	}
	
	gui.set_text(ui_components.load_button_label, "Load")
	gui.set_enabled(ui_components.load_button, true)
	gui.set_enabled(ui_components.loading_text, false)
	
	log.clear()
end

local function load_ad()
	if selected_ad_type == "Interstitial" then
		applovin.load_interstitial(ad_unit)
	elseif selected_ad_type == "Rewarded" then
		applovin.load_rewarded_ad(ad_unit)
	elseif selected_ad_type == "MRec" then
		applovin.create_mrec(ad_unit, "center")
	elseif selected_ad_type == "Banner" then
		applovin.create_banner(ad_unit, "top_center")
	end
end

local function show_ad()
	if selected_ad_type == "Interstitial" then
		applovin.show_interstitial(ad_unit)
	elseif selected_ad_type == "Rewarded" then
		applovin.show_rewarded_ad(ad_unit)
	elseif selected_ad_type == "MRec" then
		applovin.show_mrec(ad_unit)
	elseif selected_ad_type == "Banner" then
		applovin.show_banner(ad_unit)
	end
end

function M.setup(ad_type)
	reset_ui_components()
	
	selected_ad_type = ad_type

	local sysinfo = sys.get_sys_info()
	if sysinfo.system_name == "Android" then
		ad_unit = android_ad_units[ad_type]
	elseif sysinfo.system_name == "iPhone OS" then
		ad_unit = ios_ad_units[ad_type]
	end
	
	gui.set_text(ui_components.ad_type_text, ad_type)
end

function M.load_button_clicked()
	if gui.get_text(ui_components.load_button_label) == "Load" then
		load_ad()
		gui.set_enabled(ui_components.loading_text, true)
		gui.set_enabled(ui_components.load_button, false)
	else
		isShowingAd = true
		show_ad()
		gui.set_text(ui_components.load_button_label, "Load")
	end
end

function M.on_ad_loaded(params)
	if not isShowingAd and params.adUnitIdentifier == ad_unit then
		gui.set_text(ui_components.load_button_label, "Show")
		gui.set_enabled(ui_components.load_button, true)
		gui.set_enabled(ui_components.loading_text, false)
	end
end

function M.destroy_current_ad()
	if selected_ad_type == "MRec" then
		applovin.destroy_mrec(ad_unit)
	elseif selected_ad_type == "Banner" then
		applovin.destroy_banner(ad_unit)
	end

	isShowingAd = false
end

return M
