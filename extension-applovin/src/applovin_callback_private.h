#if defined(DM_PLATFORM_ANDROID) || defined(DM_PLATFORM_IOS)
#pragma once

#include "applovin_private.h"
#include <dmsdk/sdk.h>

namespace dmAppLovin {

enum ConsentFlowUserGeography
{
    CONSENT_FLOW_USER_GEOGRAPHY_UNKNOWN,
    CONSENT_FLOW_USER_GEOGRAPHY_GDPR,
    CONSENT_FLOW_USER_GEOGRAPHY_OTHER
};

enum AppTrackingTransparencyStatus
{
    APP_TRACKING_TRANSPARENCY_STATUS_UNAVAILABLE = -1,
    APP_TRACKING_TRANSPARENCY_STATUS_NOT_DETERMINED,
    APP_TRACKING_TRANSPARENCY_STATUS_RESTRICTED,
    APP_TRACKING_TRANSPARENCY_STATUS_DENIED,
    APP_TRACKING_TRANSPARENCY_STATUS_AUTHORIZED
};

struct CallbackData
{
    char* name;
    char* json;
};

void SetLuaCallback(lua_State* L, int pos);
void UpdateCallback();
void InitializeCallback();
void FinalizeCallback();

void AddToQueueCallback(const char* name, const char* json);

} //namespace

#endif
