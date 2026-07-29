local log = require("example.log")

local M = {}

local AD_UNIT_PLACEHOLDERS = {
	iOS = {
		Interstitial = "YOUR_IOS_INTERSTITIAL_AD_UNIT_ID",
		Rewarded = "YOUR_IOS_REWARDED_AD_UNIT_ID",
		Banner = "YOUR_IOS_BANNER_AD_UNIT_ID",
		MRec = "YOUR_IOS_MREC_AD_UNIT_ID",
	},
	Android = {
		Interstitial = "YOUR_ANDROID_INTERSTITIAL_AD_UNIT_ID",
		Rewarded = "YOUR_ANDROID_REWARDED_AD_UNIT_ID",
		Banner = "YOUR_ANDROID_BANNER_AD_UNIT_ID",
		MRec = "YOUR_ANDROID_MREC_AD_UNIT_ID",
	},
}

local CONFIG_KEYS = {
	iOS = {
		Interstitial = "applovin.demo_ios_interstitial_ad_unit_id",
		Rewarded = "applovin.demo_ios_rewarded_ad_unit_id",
		Banner = "applovin.demo_ios_banner_ad_unit_id",
		MRec = "applovin.demo_ios_mrec_ad_unit_id",
	},
	Android = {
		Interstitial = "applovin.demo_android_interstitial_ad_unit_id",
		Rewarded = "applovin.demo_android_rewarded_ad_unit_id",
		Banner = "applovin.demo_android_banner_ad_unit_id",
		MRec = "applovin.demo_android_mrec_ad_unit_id",
	},
}

local ui_components = {}
local selected_ad_type
local ad_unit_id
local sdk_ready = false
local showing_ad = false
local created_ad_views = {}

local function is_placeholder(value)
	return not value
		or value == ""
		or value:find("^YOUR_")
		or value:find("^ENTER_")
end

local function platform_name()
	local system_name = sys.get_sys_info().system_name
	if system_name == "Android" then
		return "Android"
	elseif system_name == "iPhone OS" then
		return "iOS"
	end
	return nil
end

local function reset_ui_components()
	ui_components = {
		ad_type_text = gui.get_node("ad_type"),
		load_button = gui.get_node("load/larrybutton"),
		load_button_label = gui.get_node("load/larrylabel"),
		loading_text = gui.get_node("loading"),
	}

	gui.set_text(ui_components.load_button_label, "Load")
	gui.set_enabled(ui_components.load_button, true)
	gui.set_enabled(ui_components.loading_text, false)
	log.clear()
end

local function set_load_enabled(enabled, show_loading)
	gui.set_enabled(ui_components.load_button, enabled)
	gui.set_enabled(ui_components.loading_text, show_loading == true)
end

local function can_request_ad()
	if not applovin then
		print("MAX is available only in Android and iOS bundles.")
		return false
	elseif not sdk_ready or not applovin.is_initialized() then
		print("Wait for OnSdkInitializedEvent before requesting an ad.")
		return false
	elseif is_placeholder(ad_unit_id) then
		print("Configure the " .. tostring(selected_ad_type) .. " ad unit ID for this platform.")
		return false
	end
	return true
end

local function load_ad()
	if selected_ad_type == "Interstitial" then
		applovin.load_interstitial(ad_unit_id)
	elseif selected_ad_type == "Rewarded" then
		applovin.load_rewarded_ad(ad_unit_id)
	elseif selected_ad_type == "Banner" then
		applovin.set_banner_placement(ad_unit_id, "defold_demo_banner")
		applovin.create_banner(ad_unit_id, "top_center")
		applovin.set_banner_background_color(ad_unit_id, "#000000")
		created_ad_views[ad_unit_id] = "Banner"
	elseif selected_ad_type == "MRec" then
		applovin.set_mrec_placement(ad_unit_id, "defold_demo_mrec")
		applovin.create_mrec(ad_unit_id, "centered")
		created_ad_views[ad_unit_id] = "MRec"
	end
end

local function show_ad()
	if selected_ad_type == "Interstitial" then
		if not applovin.is_interstitial_ready(ad_unit_id) then
			print("The interstitial is no longer ready; load it again.")
			return false
		end
		applovin.show_interstitial(ad_unit_id, "defold_demo_interstitial")
	elseif selected_ad_type == "Rewarded" then
		if not applovin.is_rewarded_ad_ready(ad_unit_id) then
			print("The rewarded ad is no longer ready; load it again.")
			return false
		end
		applovin.show_rewarded_ad(ad_unit_id, "defold_demo_rewarded")
	elseif selected_ad_type == "Banner" then
		applovin.show_banner(ad_unit_id)
	elseif selected_ad_type == "MRec" then
		applovin.show_mrec(ad_unit_id)
	end
	return true
end

local function reset_after_fullscreen()
	showing_ad = false
	gui.set_text(ui_components.load_button_label, "Load")
	set_load_enabled(true)
end

local function destroy_ad_view(id, ad_type)
	if not applovin then
		return
	elseif ad_type == "Banner" then
		applovin.hide_banner(id)
		applovin.destroy_banner(id)
	elseif ad_type == "MRec" then
		applovin.hide_mrec(id)
		applovin.destroy_mrec(id)
	end
	created_ad_views[id] = nil
end

function M.set_sdk_ready(ready)
	sdk_ready = ready
	if ready
		and selected_ad_type
		and ui_components.load_button
		and not showing_ad
		and not is_placeholder(ad_unit_id)
	then
		gui.set_text(ui_components.load_button_label, "Load")
		set_load_enabled(true)
	end
end

function M.setup(ad_type)
	reset_ui_components()

	selected_ad_type = ad_type
	showing_ad = false

	local platform = platform_name()
	if platform then
		ad_unit_id = sys.get_config_string(
			CONFIG_KEYS[platform][ad_type],
			AD_UNIT_PLACEHOLDERS[platform][ad_type]
		)
	else
		ad_unit_id = nil
	end

	gui.set_text(ui_components.ad_type_text, ad_type)

	if not platform then
		set_load_enabled(false)
		print("The MAX demo can be configured only in Android and iOS bundles.")
	elseif not sdk_ready then
		set_load_enabled(false)
		print("MAX has not initialized. Check the SDK key and wait for its callback.")
	elseif is_placeholder(ad_unit_id) then
		set_load_enabled(false)
		print("Set " .. CONFIG_KEYS[platform][ad_type] .. " to a real MAX ad unit ID.")
	end
end

function M.on_load_button_clicked()
	if not can_request_ad() then
		set_load_enabled(false)
		return
	end

	if gui.get_text(ui_components.load_button_label) == "Load" then
		showing_ad = false
		load_ad()
		set_load_enabled(false, true)
	else
		showing_ad = true
		if show_ad() then
			if selected_ad_type == "Banner" or selected_ad_type == "MRec" then
				gui.set_text(ui_components.load_button_label, "Visible")
				set_load_enabled(false)
			else
				gui.set_text(ui_components.load_button_label, "Load")
				set_load_enabled(false)
			end
		else
			reset_after_fullscreen()
		end
	end
end

function M.on_ad_loaded(params)
	if params.adUnitIdentifier ~= ad_unit_id or showing_ad then
		return
	end

	gui.set_text(ui_components.load_button_label, "Show")
	set_load_enabled(true)
end

function M.on_ad_load_failed(params)
	if params.adUnitIdentifier ~= ad_unit_id then
		return
	end

	gui.set_text(ui_components.load_button_label, "Load")
	set_load_enabled(true)
	print("Ad load failed:", params.code, params.message)
end

function M.on_ad_display_failed(params)
	if params.adUnitIdentifier == ad_unit_id then
		print("Ad display failed:", params.code, params.message)
		reset_after_fullscreen()
	end
end

function M.on_ad_hidden(params)
	if params.adUnitIdentifier == ad_unit_id then
		reset_after_fullscreen()
	end
end

function M.on_back_button_clicked()
	if ad_unit_id and created_ad_views[ad_unit_id] then
		destroy_ad_view(ad_unit_id, created_ad_views[ad_unit_id])
	end
	showing_ad = false
end

function M.final()
	for id, ad_type in pairs(created_ad_views) do
		destroy_ad_view(id, ad_type)
	end
	sdk_ready = false
end

return M
