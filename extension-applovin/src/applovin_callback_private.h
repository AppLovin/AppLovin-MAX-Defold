#if defined(DM_PLATFORM_ANDROID) || defined(DM_PLATFORM_IOS)
#pragma once

#include "applovin_private.h"
#include <dmsdk/sdk.h>

namespace dmAppLovin {

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
