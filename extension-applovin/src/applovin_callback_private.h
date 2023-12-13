#if defined(DM_PLATFORM_ANDROID) || defined(DM_PLATFORM_IOS)
#pragma once

#include "applovin_private.h"
#include <dmsdk/sdk.h>

namespace dmAppLovin {

// The same events and messages are in MaxDefoldPlugin.java
// If you change enums here, pls make sure you update the constants there as well

enum MessageId
{
    MSG_INTERSTITIAL =                    1,
    MSG_REWARDED =                        2,
    MSG_CONSENT =                         3,
    MSG_INIT =                            4,
    MSG_IDFA =                            5
};

enum MessageEvent
{
    EVENT_AD_AVAILABLE =                 1,
    EVENT_AD_UNAVAILABLE =               2,
    EVENT_AD_OPENED =                    3,
    EVENT_AD_CLOSED =                    4,
    EVENT_AD_REWARDED =                  5,
    EVENT_AD_CLICKED =                   6,
    EVENT_AD_SHOW_FAILED =               7,
    EVENT_AD_READY =                     8,
    EVENT_AD_SHOW_SUCCEEDED =            9,
    EVENT_AD_LOAD_FAILED =               10,
    EVENT_JSON_ERROR =                   11,
    EVENT_INIT_COMPLETE =                12,
    EVENT_CONSENT_LOADED =               13,
    EVENT_CONSENT_SHOWN =                14,
    EVENT_CONSENT_LOAD_FAILED =          15,
    EVENT_CONSENT_SHOW_FAILED =          16,
    EVENT_CONSENT_ACCEPTED =             17,
    EVENT_CONSENT_DISMISSED =            18,
    EVENT_STATUS_AUTHORIZED =            19,
    EVENT_STATUS_DENIED =                20,
    EVENT_STATUS_NOT_DETERMINED =        21,
    EVENT_STATUS_RESTRICTED =            22
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
