#if defined(DM_PLATFORM_ANDROID) || defined(DM_PLATFORM_IOS)

#include "applovin_callback_private.h"
#include "utils/LuaUtils.h"
#include <stdlib.h>
#include <string.h>

namespace dmAppLovin {

static dmScript::LuaCallbackInfo* g_LuaCallback = 0;
static dmArray<CallbackData> g_CallbackQueue;
static dmMutex::HMutex g_CallbackMutex = 0;
static bool g_CallbackActive = false;
static uint32_t g_CallbackInvocationDepth = 0;
static dmArray<dmScript::LuaCallbackInfo*> g_DeferredCallbacks;

static void FreeCallbackData(CallbackData& data)
{
    free(data.name);
    free(data.json);
    data.name = 0;
    data.json = 0;
}

static void FreeCallbacks(dmArray<CallbackData>& callbacks)
{
    for (uint32_t i = 0; i < callbacks.Size(); ++i)
    {
        FreeCallbackData(callbacks[i]);
    }
}

// A Lua callback may replace or clear itself. Keep retired callbacks rooted
// until the outermost invocation has restored the script context.
static void FlushDeferredCallbacks()
{
    if (g_CallbackInvocationDepth != 0)
    {
        return;
    }
    for (uint32_t i = 0; i < g_DeferredCallbacks.Size(); ++i)
    {
        dmScript::DestroyCallback(g_DeferredCallbacks[i]);
    }
    g_DeferredCallbacks.SetSize(0);
}

static void RetireCallback(dmScript::LuaCallbackInfo* callback)
{
    if (!callback)
    {
        return;
    }
    if (g_CallbackInvocationDepth == 0)
    {
        dmScript::DestroyCallback(callback);
        return;
    }
    if (g_DeferredCallbacks.Full())
    {
        g_DeferredCallbacks.OffsetCapacity(4);
    }
    g_DeferredCallbacks.Push(callback);
}

static void DestroyCallback()
{
    dmScript::LuaCallbackInfo* callback = g_LuaCallback;
    g_LuaCallback = 0;
    RetireCallback(callback);
}

static void InvokeCallback(const CallbackData& data)
{
    dmScript::LuaCallbackInfo* callback = g_LuaCallback;
    if (!dmScript::IsCallbackValid(callback))
    {
        dmLogError("AppLovin callback is invalid. Set it with applovin.set_callback().");
        if (callback == g_LuaCallback)
        {
            g_LuaCallback = 0;
            RetireCallback(callback);
        }
        return;
    }

    lua_State* L = dmScript::GetCallbackLuaContext(callback);
    int top = lua_gettop(L);

    if (!dmScript::SetupCallback(callback))
    {
        return;
    }

    lua_pushstring(L, data.name ? data.name : "");
    const char* json = data.json ? data.json : "{}";
    const int jsonTop = lua_gettop(L);
    if (dmScript::JsonToLua(L, json, strlen(json)) != 1 || !lua_istable(L, -1))
    {
        lua_settop(L, jsonTop);
        lua_newtable(L);
    }

    ++g_CallbackInvocationDepth;
    dmScript::PCall(L, 3, 0);
    dmScript::TeardownCallback(callback);

    assert(top == lua_gettop(L));
    assert(g_CallbackInvocationDepth > 0);
    --g_CallbackInvocationDepth;
    FlushDeferredCallbacks();
}

void InitializeCallback()
{
    if (!g_CallbackMutex)
    {
        // Keep the mutex alive for the process lifetime. Native callbacks can
        // already be in flight when the extension is finalized.
        g_CallbackMutex = dmMutex::New();
    }
    DM_MUTEX_SCOPED_LOCK(g_CallbackMutex);
    g_CallbackActive = true;
}

void FinalizeCallback()
{
    if (g_CallbackMutex)
    {
        dmArray<CallbackData> pending;
        {
            DM_MUTEX_SCOPED_LOCK(g_CallbackMutex);
            g_CallbackActive = false;
            pending.Swap(g_CallbackQueue);
        }
        FreeCallbacks(pending);
    }
    DestroyCallback();
    FlushDeferredCallbacks();
}

void SetLuaCallback(lua_State* L, int pos)
{
    dmScript::LuaCallbackInfo* replacement = 0;
    if (!lua_isnoneornil(L, pos))
    {
        luaL_checktype(L, pos, LUA_TFUNCTION);
        replacement = dmScript::CreateCallback(L, pos);
    }

    dmScript::LuaCallbackInfo* previous = g_LuaCallback;
    g_LuaCallback = replacement;
    RetireCallback(previous);
}

void AddToQueueCallback(const char* name, const char* json)
{
    CallbackData data;
    data.name = strdup(name ? name : "");
    data.json = strdup(json ? json : "{}");

    if (!g_CallbackMutex)
    {
        FreeCallbackData(data);
        return;
    }
    DM_MUTEX_SCOPED_LOCK(g_CallbackMutex);
    if (!g_CallbackActive)
    {
        FreeCallbackData(data);
        return;
    }
    if (g_CallbackQueue.Full())
    {
        g_CallbackQueue.OffsetCapacity(8);
    }
    g_CallbackQueue.Push(data);
}

void UpdateCallback()
{
    if (!g_CallbackMutex)
    {
        return;
    }

    dmArray<CallbackData> pending;
    {
        DM_MUTEX_SCOPED_LOCK(g_CallbackMutex);
        if (!g_CallbackActive || g_CallbackQueue.Empty())
        {
            return;
        }
        pending.Swap(g_CallbackQueue);
    }

    for (uint32_t i = 0; i < pending.Size(); ++i)
    {
        InvokeCallback(pending[i]);
        FreeCallbackData(pending[i]);
    }
}

} //namespace

#endif
