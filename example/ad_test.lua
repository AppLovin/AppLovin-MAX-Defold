local ui = require("example.ui")
local log = require("example.log")

local M = {}

local ad_units = { 
	Interstitial = "f5df6799ac75cd34",
	Rewarded = "49cdb15b16042a49",
	Banner = "3c2e14fa5f22c4f6",
	MRec = "6e882d2f921d6d7c"
}

local ui_components = {}

local ad_type = ""
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
	if ad_type == "Interstitial" then
		applovin.load_interstitial(ad_unit)
	elseif ad_type == "Rewarded" then
		applovin.load_rewarded_ad(ad_unit)
	elseif ad_type == "MRec" then
		applovin.create_mrec(ad_unit, "Center")
	elseif ad_type == "Banner" then
		applovin.create_banner(ad_unit, "TopCenter")
	end
end

local function show_ad()
	if ad_type == "Interstitial" then
		applovin.show_interstitial(ad_unit)
	elseif ad_type == "Rewarded" then
		applovin.show_rewarded_ad(ad_unit)
	elseif ad_type == "MRec" then
		applovin.show_mrec(ad_unit)
	elseif ad_type == "Banner" then
		applovin.show_banner(ad_unit)
	end
end

function M.setup(ad_type)
	reset_ui_components()
	this.ad_type = ad_type
	ad_unit = ad_units[ad_type]
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
	if params.adUnitIdentifier == ad_unit then
		gui.set_text(ui_components.load_button_label, "Show")
		gui.set_enabled(ui_components.load_button, true)
		gui.set_enabled(ui_components.loading_text, false)
	end
end

function M.destroy_current_ad()
	if isShowingAd then
		if ad_type == "MRec" then
			applovin.destroy_mrec(ad_unit)
		elseif ad_type == "Banner" then
			applovin.destroy_banner(ad_unit)
		end
	end
end

return M