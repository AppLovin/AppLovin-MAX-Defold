local ui = require("example.ui")
local log = require("example.log")

local M = {}

local ios_ad_unit_ids = {
	Interstitial = "ENTER_IOS_INTERSTITIAL_AD_UNIT_ID_HERE",
	Rewarded = "ENTER_IOS_REWARDED_AD_UNIT_ID_HERE",
	Banner = "ENTER_IOS_BANNER_AD_UNIT_ID_HERE",
	MRec = "ENTER_IOS_MREC_AD_UNIT_ID_HERE"
}

local android_ad_unit_ids = {
	Interstitial = "ENTER_ANDROID_INTERSTITIAL_AD_UNIT_ID_HERE",
	Rewarded = "ENTER_ANDROID_REWARDED_AD_UNIT_ID_HERE",
	Banner = "ENTER_ANDROID_BANNER_AD_UNIT_ID_HERE",
	MRec = "ENTER_ANDROID_MREC_AD_UNIT_ID_HERE"
}

local ui_components = {}

local selected_ad_type = ""
local ad_unit_id = ""
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
		applovin.load_interstitial(ad_unit_id)
	elseif selected_ad_type == "Rewarded" then
		applovin.load_rewarded_ad(ad_unit_id)
	elseif selected_ad_type == "Banner" then
		applovin.create_banner(ad_unit_id, "top_center")
	elseif selected_ad_type == "MRec" then
		applovin.create_mrec(ad_unit_id, "centered")
	end
end

local function show_ad()
	if selected_ad_type == "Interstitial" then
		applovin.show_interstitial(ad_unit_id)
	elseif selected_ad_type == "Rewarded" then
		applovin.show_rewarded_ad(ad_unit_id)
	elseif selected_ad_type == "Banner" then
		applovin.show_banner(ad_unit_id)
	elseif selected_ad_type == "MRec" then
		applovin.show_mrec(ad_unit_id)
	end
end

function M.setup(ad_type)
	reset_ui_components()
	
	selected_ad_type = ad_type

	local sysinfo = sys.get_sys_info()
	if sysinfo.system_name == "Android" then
		ad_unit_id = android_ad_unit_ids[ad_type]
	elseif sysinfo.system_name == "iPhone OS" then
		ad_unit_id = ios_ad_unit_ids[ad_type]
	end
	
	gui.set_text(ui_components.ad_type_text, ad_type)
end

function M.on_load_button_clicked()
	if gui.get_text(ui_components.load_button_label) == "Load" then
		isShowingAd = false
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
	if not isShowingAd and params.adUnitIdentifier == ad_unit_id then
		gui.set_text(ui_components.load_button_label, "Show")
		gui.set_enabled(ui_components.load_button, true)
		gui.set_enabled(ui_components.loading_text, false)
	end
end

function M.on_back_button_clicked()
	if selected_ad_type == "Banner" then
		applovin.hide_banner(ad_unit_id)
		applovin.destroy_banner(ad_unit_id)
	elseif selected_ad_type == "MRec" then
		applovin.hide_mrec(ad_unit_id)
		applovin.destroy_mrec(ad_unit_id)
	end

	isShowingAd = false
end

return M
