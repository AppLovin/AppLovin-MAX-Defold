#define EXTENSION_NAME AppLovinExt
#define LIB_NAME "AppLovin"
#define MODULE_NAME "applovin"

#define DLIB_LOG_DOMAIN LIB_NAME
#include <dmsdk/sdk.h>

#if defined(DM_PLATFORM_ANDROID) || defined(DM_PLATFORM_IOS)

#include "applovin_private.h"
#include "applovin_callback_private.h"
#include "utils/LuaUtils.h"

namespace dmAppLovin {

static int Lua_Initialize(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* lua_sdkKey = luaL_checkstring(L, 1);
    Initialize(lua_sdkKey);
    return 0;
}

static int Lua_ShowMediationDebugger(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    ShowMediationDebugger();
    return 0;
}

static int Lua_LoadInterstitial(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* lua_adUnitId = luaL_checkstring(L, 1);
    LoadInterstitial(lua_adUnitId);
    return 0;
}

static int Lua_ShowInterstitial(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* lua_adUnitId = luaL_checkstring(L, 1);
    ShowInterstitial(lua_adUnitId);
    return 0;
}

static int Lua_IsInterstitialReady(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 1);
    const char* lua_adUnitId = luaL_checkstring(L, 1);
    bool isReady = IsInterstitialReady(lua_adUnitId);
    lua_pushboolean(L, isReady);
    return 1;
}

static int Lua_IsInitialized(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 1);
    bool isInitialized = IsInitialized();
    lua_pushboolean(L, isInitialized);
    return 1;
}

static int Lua_SetHasUserConsent(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    luaL_checktype(L, 1, LUA_TBOOLEAN);
    bool hasUserConsent = lua_toboolean(L, 1);
    SetHasUserConsent(hasUserConsent);
    return 0;
}

static int Lua_HasUserConsent(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 1);
    bool hasUserConsent = HasUserConsent();
    lua_pushboolean(L, hasUserConsent);
    return 1;
}

static int Lua_SetIsAgeRestrictedUser(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    luaL_checktype(L, 1, LUA_TBOOLEAN);
    bool isAgeRestrictedUser = lua_toboolean(L, 1);
    SetIsAgeRestrictedUser(isAgeRestrictedUser);
    return 0;
}

static int Lua_IsAgeRestrictedUser(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 1);
    bool isAgeRestrictedUser = IsAgeRestrictedUser();
    lua_pushboolean(L, isAgeRestrictedUser);
    return 1;
}

static int Lua_SetDoNotSell(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    luaL_checktype(L, 1, LUA_TBOOLEAN);
    bool doNotSell = lua_toboolean(L, 1);
    SetDoNotSell(doNotSell);
    return 0;
}

static int Lua_IsDoNotSell(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 1);
    bool isDoNotSell = IsDoNotSell();
    lua_pushboolean(L, isDoNotSell);
    return 1;
}

static int Lua_SetTermsAndPrivacyPolicyFlowEnabled(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    luaL_checktype(L, 1, LUA_TBOOLEAN);
    bool enabled = lua_toboolean(L, 1);
    SetTermsAndPrivacyPolicyFlowEnabled(enabled);
    return 0;
}

static int Lua_SetPrivacyPolicyUrl(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* lua_urlString = luaL_checkstring(L, 1);
    SetPrivacyPolicyUrl(lua_urlString);
    return 0;
}

static int Lua_SetTermsOfServiceUrl(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* lua_urlString = luaL_checkstring(L, 1);
    SetTermsOfServiceUrl(lua_urlString);
    return 0;
}

static int Lua_SetConsentFlowDebugUserGeography(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* lua_urlString = luaL_checkstring(L, 1);
    SetConsentFlowDebugUserGeography(lua_urlString);
    return 0;
}

static int Lua_ShowCmpForExistingUser(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    ShowCmpForExistingUser();
    return 0;
}

static int Lua_HasSupportedCmp(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 1);
    bool hasSupportedCmp = HasSupportedCmp();
    lua_pushboolean(L, hasSupportedCmp);
    return 1;
}

static int Lua_IsTablet(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 1);
    bool isTablet = IsTablet();
    lua_pushboolean(L, isTablet);
    return 1;
}

static int Lua_SetUserId(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    if (lua_type(L, 1) != LUA_TSTRING)
    {
        return DM_LUA_ERROR("Expected string, got %s. Wrong type for user_id variable '%s'.", luaL_typename(L, 1), lua_tostring(L, 1));
    }
    const char* lua_userId = luaL_checkstring(L, 1);
    SetUserId(lua_userId);
    return 0;
}

static int Lua_SetMuted(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    luaL_checktype(L, 1, LUA_TBOOLEAN);
    bool muted = lua_toboolean(L, 1);
    SetMuted(muted);
    return 0;
}

static int Lua_SetCallback(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    SetLuaCallback(L, 1);
    return 0;
}

static int Lua_IsMuted(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 1);
    bool isMuted = IsMuted();
    lua_pushboolean(L, isMuted);
    return 1;
}

static int Lua_SetVerboseLoggingEnabled(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    luaL_checktype(L, 1, LUA_TBOOLEAN);
    bool enabled = lua_toboolean(L, 1);
    SetVerboseLoggingEnabled(enabled);
    return 0;
}

static int Lua_IsVerboseLoggingEnabled(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 1);
    bool isEnabled = IsVerboseLoggingEnabled();
    lua_pushboolean(L, isEnabled);
    return 1;
}

static int Lua_SetCreativeDebuggerEnabled(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    luaL_checktype(L, 1, LUA_TBOOLEAN);
    bool enabled = lua_toboolean(L, 1);
    SetCreativeDebuggerEnabled(enabled);
    return 0;
}

static int Lua_SetTestDeviceAdvertisingIds(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    luaL_checktype(L, 1, LUA_TTABLE);
    int count = lua_objlen(L, 1);
    const char* advertisingIds[count];
    for (int i = 0; i < count; ++i)
    {
        lua_rawgeti(L, 1, i + 1);
        advertisingIds[i] = lua_tostring(L, -1);
        lua_pop(L, 1);
    }
    SetTestDeviceAdvertisingIds(advertisingIds, count);
    return 0;
}

static int Lua_TrackEvent(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* event = luaL_checkstring(L, 1);
    const char* parameters = luaL_checkstring(L, 2);
    TrackEvent(event, parameters);
    return 0;
}

static int Lua_CreateBanner(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    const char* bannerPosition = luaL_checkstring(L, 2);
    CreateBanner(adUnitId, bannerPosition);
    return 0;
}

static int Lua_SetBannerBackgroundColor(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    const char* hexColorCode = luaL_checkstring(L, 2);
    SetBannerBackgroundColor(adUnitId, hexColorCode);
    return 0;
}

static int Lua_SetBannerPlacement(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    const char* placement = luaL_checkstring(L, 2);
    SetBannerPlacement(adUnitId, placement);
    return 0;
}

static int Lua_SetBannerExtraParameter(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    const char* key = luaL_checkstring(L, 2);
    const char* value = luaL_checkstring(L, 3);
    SetBannerExtraParameter(adUnitId, key, value);
    return 0;
}

static int Lua_UpdateBannerPosition(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    const char* bannerPosition = luaL_checkstring(L, 2);
    UpdateBannerPosition(adUnitId, bannerPosition);
    return 0;
}

static int Lua_ShowBanner(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    ShowBanner(adUnitId);
    return 0;
}

static int Lua_HideBanner(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    HideBanner(adUnitId);
    return 0;
}

static int Lua_DestroyBanner(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    DestroyBanner(adUnitId);
    return 0;
}

static int Lua_CreateMRec(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    const char* mrecPosition = luaL_checkstring(L, 2);
    CreateMRec(adUnitId, mrecPosition);
    return 0;
}

static int Lua_SetMRecPlacement(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    const char* placement = luaL_checkstring(L, 2);
    SetMRecPlacement(adUnitId, placement);
    return 0;
}

static int Lua_SetMRecExtraParameter(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    const char* key = luaL_checkstring(L, 2);
    const char* value = luaL_checkstring(L, 3);
    SetMRecExtraParameter(adUnitId, key, value);
    return 0;
}

static int Lua_UpdateMRecPosition(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    const char* mrecPosition = luaL_checkstring(L, 2);
    UpdateMRecPosition(adUnitId, mrecPosition);
    return 0;
}

static int Lua_ShowMRec(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    ShowMRec(adUnitId);
    return 0;
}

static int Lua_HideMRec(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    HideMRec(adUnitId);
    return 0;
}

static int Lua_DestroyMRec(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    DestroyMRec(adUnitId);
    return 0;
}

static int Lua_LoadRewardedAd(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    LoadRewardedAd(adUnitId);
    return 0;
}

static int Lua_IsRewardedAdReady(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 1);
    const char* adUnitId = luaL_checkstring(L, 1);
    bool isReady = IsRewardedAdReady(adUnitId);
    lua_pushboolean(L, isReady);
    return 1;
}

static int Lua_ShowRewardedAd(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    ShowRewardedAd(adUnitId);
    return 0;
}

static int Lua_SetRewardedAdExtraParameter(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    const char* adUnitId = luaL_checkstring(L, 1);
    const char* key = luaL_checkstring(L, 2);
    const char* value = luaL_checkstring(L, 3);
    SetRewardedAdExtraParameter(adUnitId, key, value);
    return 0;
}

static const luaL_reg Module_methods[] =
{
    {"initialize", Lua_Initialize},
    {"show_mediation_debugger", Lua_ShowMediationDebugger},
    {"load_interstitial", Lua_LoadInterstitial},
    {"show_interstitial", Lua_ShowInterstitial},
    {"is_interstitial_ready", Lua_IsInterstitialReady},
    {"is_initialized", Lua_IsInitialized},
    {"set_has_user_consent", Lua_SetHasUserConsent},
    {"has_user_consent", Lua_HasUserConsent},
    {"set_is_age_restricted_user", Lua_SetIsAgeRestrictedUser},
    {"is_age_restricted_user", Lua_IsAgeRestrictedUser},
    {"set_do_not_sell", Lua_SetDoNotSell},
    {"is_do_not_sell", Lua_IsDoNotSell},
    {"set_terms_and_privacy_policy_flow_enabled", Lua_SetTermsAndPrivacyPolicyFlowEnabled},
    {"set_privacy_policy_url", Lua_SetPrivacyPolicyUrl},
    {"set_terms_of_service_url", Lua_SetTermsOfServiceUrl},
    {"set_consent_flow_debug_user_geography", Lua_SetConsentFlowDebugUserGeography},
    {"show_cmp_for_existing_user", Lua_ShowCmpForExistingUser},
    {"has_supported_cmp", Lua_HasSupportedCmp},
    {"is_tablet", Lua_IsTablet},
    {"set_user_id", Lua_SetUserId},
    {"set_muted", Lua_SetMuted},
    {"is_muted", Lua_IsMuted},
    {"set_verbose_logging_enabled", Lua_SetVerboseLoggingEnabled},
    {"is_verbose_logging_enabled", Lua_IsVerboseLoggingEnabled},
    {"set_creative_debugger_enabled", Lua_SetCreativeDebuggerEnabled},
    {"set_test_device_advertising_ids", Lua_SetTestDeviceAdvertisingIds},
    {"track_event", Lua_TrackEvent},
    {"create_banner", Lua_CreateBanner},
    {"set_banner_background_color", Lua_SetBannerBackgroundColor},
    {"set_banner_placement", Lua_SetBannerPlacement},
    {"set_banner_extra_parameter", Lua_SetBannerExtraParameter},
    {"update_banner_position", Lua_UpdateBannerPosition},
    {"show_banner", Lua_ShowBanner},
    {"hide_banner", Lua_HideBanner},
    {"destroy_banner", Lua_DestroyBanner},
    {"create_mrec", Lua_CreateMRec},
    {"set_mrec_placement", Lua_SetMRecPlacement},
    {"set_mrec_extra_parameter", Lua_SetMRecExtraParameter},
    {"update_mrec_position", Lua_UpdateMRecPosition},
    {"show_mrec", Lua_ShowMRec},
    {"hide_mrec", Lua_HideMRec},
    {"destroy_mrec", Lua_DestroyMRec},
    {"load_rewarded_ad", Lua_LoadRewardedAd},
    {"is_rewarded_ad_ready", Lua_IsRewardedAdReady},
    {"show_rewarded_ad", Lua_ShowRewardedAd},
    {"set_rewarded_ad_extra_parameter", Lua_SetRewardedAdExtraParameter},
    {"set_callback", Lua_SetCallback},
    {0, 0}
};

static void LuaInit(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 0);
    luaL_register(L, MODULE_NAME, Module_methods);
    lua_pop(L, 1);
}

static dmExtension::Result AppInitializeAppLovin(dmExtension::AppParams* params)
{
    return dmExtension::RESULT_OK;
}

static dmExtension::Result InitializeAppLovin(dmExtension::Params* params)
{
    LuaInit(params->m_L);

    const char *defoldEngineVersion = NULL;

    lua_getglobal(params->m_L, "sys");                       // push 'sys' onto stack
    lua_getfield(params->m_L, -1, "get_engine_info");        // push desired function
    lua_call(params->m_L, 0, 1);                             // call function with 0 arg, 1 return value
    lua_getfield(params->m_L, -1, "version");                // push desired property
    defoldEngineVersion = lua_tostring(params->m_L, -1);     // get return value
    lua_pop(params->m_L, 3);                                 // pop result, function, 'sys'

    const char* extensionVersion = dmConfigFile::GetString(params->m_ConfigFile, "project.version", "0.0");
    
    Initialize_Ext(defoldEngineVersion, extensionVersion);
    InitializeCallback();
    return dmExtension::RESULT_OK;
}

static dmExtension::Result AppFinalizeAppLovin(dmExtension::AppParams* params)
{
    return dmExtension::RESULT_OK;
}

static dmExtension::Result FinalizeAppLovin(dmExtension::Params* params)
{
    FinalizeCallback();
    return dmExtension::RESULT_OK;
}

static dmExtension::Result UpdateAppLovin(dmExtension::Params* params)
{
    UpdateCallback();
    return dmExtension::RESULT_OK;
}

static void OnEventAppLovin(dmExtension::Params* params, const dmExtension::Event* event)
{
    switch(event->m_Event)
    {
        case dmExtension::EVENT_ID_ACTIVATEAPP:
            OnResume();
            break;
        case dmExtension::EVENT_ID_DEACTIVATEAPP:
            OnPause();
            break;
    }
}

} //namespace dmAppLovin

DM_DECLARE_EXTENSION(EXTENSION_NAME, LIB_NAME, dmAppLovin::AppInitializeAppLovin, dmAppLovin::AppFinalizeAppLovin, dmAppLovin::InitializeAppLovin, dmAppLovin::UpdateAppLovin, dmAppLovin::OnEventAppLovin, dmAppLovin::FinalizeAppLovin)

#else

static dmExtension::Result InitializeAppLovin(dmExtension::Params* params)
{
    dmLogInfo("Registered extension AppLovin");
    return dmExtension::RESULT_OK;
}

static dmExtension::Result FinalizeAppLovin(dmExtension::Params* params)
{
    return dmExtension::RESULT_OK;
}

DM_DECLARE_EXTENSION(EXTENSION_NAME, LIB_NAME, 0, 0, InitializeAppLovin, 0, 0, FinalizeAppLovin)

#endif // DM_PLATFORM_ANDROID || DM_PLATFORM_IOS
