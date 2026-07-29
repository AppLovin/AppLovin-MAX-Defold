#if defined(DM_PLATFORM_ANDROID)

#include <dmsdk/dlib/android.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "applovin_private.h"
#include "com_defold_applovin_MaxDefoldPlugin.h"
#include "applovin_callback_private.h"

namespace {

static const uint32_t UTF_REPLACEMENT_CHARACTER = 0xFFFD;

static bool IsUtf8ContinuationByte(uint8_t byte)
{
    return (byte & 0xC0) == 0x80;
}

static uint32_t DecodeUtf8CodePoint(const uint8_t* utf8, size_t length, size_t* offset)
{
    const size_t start = *offset;
    const uint8_t first = utf8[start];

    if (first <= 0x7F)
    {
        *offset = start + 1;
        return first;
    }

    if (first >= 0xC2 && first <= 0xDF && start + 1 < length)
    {
        const uint8_t second = utf8[start + 1];
        if (IsUtf8ContinuationByte(second))
        {
            *offset = start + 2;
            return ((uint32_t)(first & 0x1F) << 6)
                | (uint32_t)(second & 0x3F);
        }
    }
    else if (first >= 0xE0 && first <= 0xEF && start + 2 < length)
    {
        const uint8_t second = utf8[start + 1];
        const uint8_t third = utf8[start + 2];
        const bool secondIsValid = IsUtf8ContinuationByte(second)
            && (first != 0xE0 || second >= 0xA0)
            && (first != 0xED || second <= 0x9F);
        if (secondIsValid && IsUtf8ContinuationByte(third))
        {
            *offset = start + 3;
            return ((uint32_t)(first & 0x0F) << 12)
                | ((uint32_t)(second & 0x3F) << 6)
                | (uint32_t)(third & 0x3F);
        }
    }
    else if (first >= 0xF0 && first <= 0xF4 && start + 3 < length)
    {
        const uint8_t second = utf8[start + 1];
        const uint8_t third = utf8[start + 2];
        const uint8_t fourth = utf8[start + 3];
        const bool secondIsValid = IsUtf8ContinuationByte(second)
            && (first != 0xF0 || second >= 0x90)
            && (first != 0xF4 || second <= 0x8F);
        if (secondIsValid && IsUtf8ContinuationByte(third) && IsUtf8ContinuationByte(fourth))
        {
            *offset = start + 4;
            return ((uint32_t)(first & 0x07) << 18)
                | ((uint32_t)(second & 0x3F) << 12)
                | ((uint32_t)(third & 0x3F) << 6)
                | (uint32_t)(fourth & 0x3F);
        }
    }

    // Consume one byte so every malformed sequence makes progress and becomes U+FFFD.
    *offset = start + 1;
    return UTF_REPLACEMENT_CHARACTER;
}

static uint32_t DecodeUtf16CodePoint(const jchar* utf16, jsize length, jsize* offset)
{
    const uint32_t first = utf16[(*offset)++];
    if (first >= 0xD800 && first <= 0xDBFF)
    {
        if (*offset < length)
        {
            const uint32_t second = utf16[*offset];
            if (second >= 0xDC00 && second <= 0xDFFF)
            {
                ++(*offset);
                return 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00);
            }
        }
        return UTF_REPLACEMENT_CHARACTER;
    }
    if (first >= 0xDC00 && first <= 0xDFFF)
    {
        return UTF_REPLACEMENT_CHARACTER;
    }
    return first;
}

static size_t GetUtf8CodePointLength(uint32_t codePoint)
{
    if (codePoint <= 0x7F)
    {
        return 1;
    }
    if (codePoint <= 0x7FF)
    {
        return 2;
    }
    if (codePoint <= 0xFFFF)
    {
        return 3;
    }
    return 4;
}

static size_t EncodeUtf8CodePoint(uint32_t codePoint, char* output)
{
    if (codePoint <= 0x7F)
    {
        output[0] = (char)codePoint;
        return 1;
    }
    if (codePoint <= 0x7FF)
    {
        output[0] = (char)(0xC0 | (codePoint >> 6));
        output[1] = (char)(0x80 | (codePoint & 0x3F));
        return 2;
    }
    if (codePoint <= 0xFFFF)
    {
        output[0] = (char)(0xE0 | (codePoint >> 12));
        output[1] = (char)(0x80 | ((codePoint >> 6) & 0x3F));
        output[2] = (char)(0x80 | (codePoint & 0x3F));
        return 3;
    }

    output[0] = (char)(0xF0 | (codePoint >> 18));
    output[1] = (char)(0x80 | ((codePoint >> 12) & 0x3F));
    output[2] = (char)(0x80 | ((codePoint >> 6) & 0x3F));
    output[3] = (char)(0x80 | (codePoint & 0x3F));
    return 4;
}

static jstring Utf8ToJString(JNIEnv* env, const char* utf8)
{
    if (!env || !utf8)
    {
        return 0;
    }

    const size_t utf8Length = strlen(utf8);
    if (utf8Length > (size_t)INT_MAX || utf8Length > SIZE_MAX / sizeof(jchar))
    {
        dmLogError("Unable to convert an oversized UTF-8 string to a Java string.");
        return 0;
    }

    jchar* utf16 = utf8Length ? (jchar*)malloc(utf8Length * sizeof(jchar)) : 0;
    if (utf8Length && !utf16)
    {
        dmLogError("Unable to allocate memory for UTF-8 to UTF-16 conversion.");
        return 0;
    }

    size_t utf8Offset = 0;
    jsize utf16Length = 0;
    while (utf8Offset < utf8Length)
    {
        const uint32_t codePoint = DecodeUtf8CodePoint((const uint8_t*)utf8, utf8Length, &utf8Offset);
        if (codePoint <= 0xFFFF)
        {
            utf16[utf16Length++] = (jchar)codePoint;
        }
        else
        {
            const uint32_t supplementary = codePoint - 0x10000;
            utf16[utf16Length++] = (jchar)(0xD800 + (supplementary >> 10));
            utf16[utf16Length++] = (jchar)(0xDC00 + (supplementary & 0x3FF));
        }
    }

    const jchar empty = 0;
    jstring result = env->NewString(utf16Length ? utf16 : &empty, utf16Length);
    free(utf16);
    return result;
}

static bool JStringToUtf8(JNIEnv* env, jstring string, char** output)
{
    if (!output)
    {
        return false;
    }
    *output = 0;
    if (!env || !string)
    {
        return false;
    }

    const jsize utf16Length = env->GetStringLength(string);
    if (utf16Length == 0)
    {
        *output = (char*)malloc(1);
        if (!*output)
        {
            dmLogError("Unable to allocate memory for an empty UTF-8 string.");
            return false;
        }
        (*output)[0] = '\0';
        return true;
    }

    const jchar* utf16 = env->GetStringChars(string, 0);
    if (!utf16)
    {
        return false;
    }

    size_t utf8Length = 0;
    jsize utf16Offset = 0;
    while (utf16Offset < utf16Length)
    {
        const uint32_t codePoint = DecodeUtf16CodePoint(utf16, utf16Length, &utf16Offset);
        if (codePoint == 0)
        {
            env->ReleaseStringChars(string, utf16);
            dmLogError("Unable to pass a Java string containing U+0000 through a C string API.");
            return false;
        }
        const size_t codePointLength = GetUtf8CodePointLength(codePoint);
        if (utf8Length > SIZE_MAX - codePointLength - 1)
        {
            env->ReleaseStringChars(string, utf16);
            dmLogError("Unable to convert an oversized Java string to UTF-8.");
            return false;
        }
        utf8Length += codePointLength;
    }

    char* utf8 = (char*)malloc(utf8Length + 1);
    if (!utf8)
    {
        env->ReleaseStringChars(string, utf16);
        dmLogError("Unable to allocate memory for UTF-16 to UTF-8 conversion.");
        return false;
    }

    size_t utf8Offset = 0;
    utf16Offset = 0;
    while (utf16Offset < utf16Length)
    {
        const uint32_t codePoint = DecodeUtf16CodePoint(utf16, utf16Length, &utf16Offset);
        utf8Offset += EncodeUtf8CodePoint(codePoint, utf8 + utf8Offset);
    }
    utf8[utf8Offset] = '\0';

    env->ReleaseStringChars(string, utf16);
    *output = utf8;
    return true;
}

} // namespace

JNIEXPORT void JNICALL Java_com_defold_applovin_MaxDefoldPlugin_appLovinAddToQueue(JNIEnv * env, jclass cls, jstring jname, jstring jjson)
{
    (void)cls;
    char* name = 0;
    char* json = 0;
    if (!JStringToUtf8(env, jname, &name) || !JStringToUtf8(env, jjson, &json))
    {
        free(name);
        free(json);
        return;
    }

    dmAppLovin::AddToQueueCallback(name, json);
    free(name);
    free(json);
}

namespace dmAppLovin {

struct AppLovin
{
    jobject   m_MaxDefoldPlugin;

    jmethodID m_Destroy;
    jmethodID m_Initialize;
    jmethodID m_IsInitialized;
    jmethodID m_ShowMediationDebugger;
    jmethodID m_SetHasUserConsent;
    jmethodID m_HasUserConsent;
    jmethodID m_SetDoNotSell;
    jmethodID m_IsDoNotSell;
    jmethodID m_SetTermsAndPrivacyPolicyFlowEnabled;
    jmethodID m_SetPrivacyPolicyUrl;
    jmethodID m_SetTermsOfServiceUrl;
    jmethodID m_SetConsentFlowDebugUserGeography;
    jmethodID m_ShowCmpForExistingUser;
    jmethodID m_HasSupportedCmp;
    jmethodID m_IsTablet;
    jmethodID m_SetUserId;
    jmethodID m_SetMuted;
    jmethodID m_IsMuted;
    jmethodID m_SetVerboseLoggingEnabled;
    jmethodID m_IsVerboseLoggingEnabled;
    jmethodID m_SetCreativeDebuggerEnabled;
    jmethodID m_SetTestDeviceAdvertisingIds;
    jmethodID m_TrackEvent;
    jmethodID m_LoadInterstitial;
    jmethodID m_IsInterstitialReady;
    jmethodID m_ShowInterstitial;
    jmethodID m_SetInterstitialExtraParameter;
    jmethodID m_LoadRewardedAd;
    jmethodID m_IsRewardedAdReady;
    jmethodID m_ShowRewardedAd;
    jmethodID m_SetRewardedAdExtraParameter;
    jmethodID m_CreateBanner;
    jmethodID m_SetBannerBackgroundColor;
    jmethodID m_SetBannerPlacement;
    jmethodID m_SetBannerExtraParameter;
    jmethodID m_UpdateBannerPosition;
    jmethodID m_StartBannerAutoRefresh;
    jmethodID m_StopBannerAutoRefresh;
    jmethodID m_ShowBanner;
    jmethodID m_HideBanner;
    jmethodID m_DestroyBanner;
    jmethodID m_CreateMRec;
    jmethodID m_SetMRecPlacement;
    jmethodID m_SetMRecExtraParameter;
    jmethodID m_UpdateMRecPosition;
    jmethodID m_StartMRecAutoRefresh;
    jmethodID m_StopMRecAutoRefresh;
    jmethodID m_ShowMRec;
    jmethodID m_HideMRec;
    jmethodID m_DestroyMRec;
};

static AppLovin   g_applovin;

static void CallVoidMethod(jobject instance, jmethodID method)
{
    if (!instance || !method)
    {
        return;
    }
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    env->CallVoidMethod(instance, method);
}

static bool CallBoolMethod(jobject instance, jmethodID method)
{
    if (!instance || !method)
    {
        return false;
    }
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jboolean return_value = (jboolean)env->CallBooleanMethod(instance, method);
    return JNI_TRUE == return_value;
}

static bool CallBoolMethodChar(jobject instance, jmethodID method, const char* cstr)
{
    if (!instance || !method)
    {
        return false;
    }
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jstring jstr = Utf8ToJString(env, cstr);
    if (!jstr)
    {
        return false;
    }
    jboolean return_value = (jboolean)env->CallBooleanMethod(instance, method, jstr);
    env->DeleteLocalRef(jstr);
    return JNI_TRUE == return_value;
}

static void CallVoidMethodChar(jobject instance, jmethodID method, const char* cstr)
{
    if (!instance || !method)
    {
        return;
    }
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jstring jstr = Utf8ToJString(env, cstr);
    if (!jstr)
    {
        return;
    }
    env->CallVoidMethod(instance, method, jstr);
    env->DeleteLocalRef(jstr);
}

static void CallVoidMethodCharChar(jobject instance, jmethodID method, const char* cstr_1, const char* cstr_2)
{
    if (!instance || !method)
    {
        return;
    }
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jstring jstr_1 = Utf8ToJString(env, cstr_1);
    if (!jstr_1)
    {
        return;
    }
    jstring jstr_2 = Utf8ToJString(env, cstr_2);
    if (!jstr_2)
    {
        env->DeleteLocalRef(jstr_1);
        return;
    }
    env->CallVoidMethod(instance, method, jstr_1, jstr_2);
    env->DeleteLocalRef(jstr_1);
    env->DeleteLocalRef(jstr_2);
}

static void CallVoidMethodCharCharChar(jobject instance, jmethodID method, const char* cstr_1, const char* cstr_2, const char* cstr_3)
{
    if (!instance || !method)
    {
        return;
    }
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jstring jstr_1 = Utf8ToJString(env, cstr_1);
    if (!jstr_1)
    {
        return;
    }
    jstring jstr_2 = Utf8ToJString(env, cstr_2);
    if (!jstr_2)
    {
        env->DeleteLocalRef(jstr_1);
        return;
    }
    jstring jstr_3 = Utf8ToJString(env, cstr_3);
    if (!jstr_3)
    {
        env->DeleteLocalRef(jstr_1);
        env->DeleteLocalRef(jstr_2);
        return;
    }
    env->CallVoidMethod(instance, method, jstr_1, jstr_2, jstr_3);
    env->DeleteLocalRef(jstr_1);
    env->DeleteLocalRef(jstr_2);
    env->DeleteLocalRef(jstr_3);
}

static void CallVoidMethodCharInt(jobject instance, jmethodID method, const char* cstr, int cint)
{
    if (!instance || !method)
    {
        return;
    }
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jstring jstr = Utf8ToJString(env, cstr);
    if (!jstr)
    {
        return;
    }
    env->CallVoidMethod(instance, method, jstr, cint);
    env->DeleteLocalRef(jstr);
}

static void CallVoidMethodInt(jobject instance, jmethodID method, int cint)
{
    if (!instance || !method)
    {
        return;
    }
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    env->CallVoidMethod(instance, method, cint);
}

static void CallVoidMethodBool(jobject instance, jmethodID method, bool cbool)
{
    if (!instance || !method)
    {
        return;
    }
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    env->CallVoidMethod(instance, method, cbool);
}

static void InitJNIMethods(JNIEnv* env, jclass cls)
{
    g_applovin.m_Destroy = env->GetMethodID(cls, "destroy", "()V");
    g_applovin.m_Initialize = env->GetMethodID(cls, "initialize", "(Ljava/lang/String;)V");
    g_applovin.m_ShowMediationDebugger = env->GetMethodID(cls, "showMediationDebugger", "()V");
    g_applovin.m_IsInitialized = env->GetMethodID(cls, "isInitialized", "()Z");
    g_applovin.m_SetHasUserConsent = env->GetMethodID(cls, "setHasUserConsent", "(Z)V");
    g_applovin.m_HasUserConsent = env->GetMethodID(cls, "hasUserConsent", "()Z");
    g_applovin.m_SetDoNotSell = env->GetMethodID(cls, "setDoNotSell", "(Z)V");
    g_applovin.m_IsDoNotSell = env->GetMethodID(cls, "isDoNotSell", "()Z");
    g_applovin.m_SetTermsAndPrivacyPolicyFlowEnabled = env->GetMethodID(cls, "setTermsAndPrivacyPolicyFlowEnabled", "(Z)V");
    g_applovin.m_SetPrivacyPolicyUrl = env->GetMethodID(cls, "setPrivacyPolicyUrl", "(Ljava/lang/String;)V");
    g_applovin.m_SetTermsOfServiceUrl = env->GetMethodID(cls, "setTermsOfServiceUrl", "(Ljava/lang/String;)V");
    g_applovin.m_SetConsentFlowDebugUserGeography = env->GetMethodID(cls, "setConsentFlowDebugUserGeography", "(Ljava/lang/String;)V");
    g_applovin.m_ShowCmpForExistingUser = env->GetMethodID(cls, "showCmpForExistingUser", "()V");
    g_applovin.m_HasSupportedCmp = env->GetMethodID(cls, "hasSupportedCmp", "()Z");
    g_applovin.m_IsTablet = env->GetMethodID(cls, "isTablet", "()Z");
    g_applovin.m_SetUserId = env->GetMethodID(cls, "setUserId", "(Ljava/lang/String;)V");
    g_applovin.m_SetMuted = env->GetMethodID(cls, "setMuted", "(Z)V");
    g_applovin.m_IsMuted = env->GetMethodID(cls, "isMuted", "()Z");
    g_applovin.m_SetVerboseLoggingEnabled = env->GetMethodID(cls, "setVerboseLoggingEnabled", "(Z)V");
    g_applovin.m_IsVerboseLoggingEnabled = env->GetMethodID(cls, "isVerboseLoggingEnabled", "()Z");
    g_applovin.m_SetCreativeDebuggerEnabled = env->GetMethodID(cls, "setCreativeDebuggerEnabled", "(Z)V");
    g_applovin.m_SetTestDeviceAdvertisingIds = env->GetMethodID(cls, "setTestDeviceAdvertisingIds", "([Ljava/lang/String;)V");
    g_applovin.m_TrackEvent = env->GetMethodID(cls, "trackEvent", "(Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_LoadInterstitial = env->GetMethodID(cls, "loadInterstitial", "(Ljava/lang/String;)V");
    g_applovin.m_IsInterstitialReady = env->GetMethodID(cls, "isInterstitialReady", "(Ljava/lang/String;)Z");
    g_applovin.m_ShowInterstitial = env->GetMethodID(cls, "showInterstitial", "(Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_SetInterstitialExtraParameter = env->GetMethodID(cls, "setInterstitialExtraParameter", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_LoadRewardedAd = env->GetMethodID(cls, "loadRewardedAd", "(Ljava/lang/String;)V");
    g_applovin.m_IsRewardedAdReady = env->GetMethodID(cls, "isRewardedAdReady", "(Ljava/lang/String;)Z");
    g_applovin.m_ShowRewardedAd = env->GetMethodID(cls, "showRewardedAd", "(Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_SetRewardedAdExtraParameter = env->GetMethodID(cls, "setRewardedAdExtraParameter", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_CreateBanner = env->GetMethodID(cls, "createBanner", "(Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_SetBannerBackgroundColor = env->GetMethodID(cls, "setBannerBackgroundColor", "(Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_SetBannerPlacement = env->GetMethodID(cls, "setBannerPlacement", "(Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_SetBannerExtraParameter = env->GetMethodID(cls, "setBannerExtraParameter", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_UpdateBannerPosition = env->GetMethodID(cls, "updateBannerPosition", "(Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_StartBannerAutoRefresh = env->GetMethodID(cls, "startBannerAutoRefresh", "(Ljava/lang/String;)V");
    g_applovin.m_StopBannerAutoRefresh = env->GetMethodID(cls, "stopBannerAutoRefresh", "(Ljava/lang/String;)V");
    g_applovin.m_ShowBanner = env->GetMethodID(cls, "showBanner", "(Ljava/lang/String;)V");
    g_applovin.m_HideBanner = env->GetMethodID(cls, "hideBanner", "(Ljava/lang/String;)V");
    g_applovin.m_DestroyBanner = env->GetMethodID(cls, "destroyBanner", "(Ljava/lang/String;)V");
    g_applovin.m_CreateMRec = env->GetMethodID(cls, "createMRec", "(Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_SetMRecPlacement = env->GetMethodID(cls, "setMRecPlacement", "(Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_SetMRecExtraParameter = env->GetMethodID(cls, "setMRecExtraParameter", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_UpdateMRecPosition = env->GetMethodID(cls, "updateMRecPosition", "(Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_StartMRecAutoRefresh = env->GetMethodID(cls, "startMRecAutoRefresh", "(Ljava/lang/String;)V");
    g_applovin.m_StopMRecAutoRefresh = env->GetMethodID(cls, "stopMRecAutoRefresh", "(Ljava/lang/String;)V");
    g_applovin.m_ShowMRec = env->GetMethodID(cls, "showMRec", "(Ljava/lang/String;)V");
    g_applovin.m_HideMRec = env->GetMethodID(cls, "hideMRec", "(Ljava/lang/String;)V");
    g_applovin.m_DestroyMRec = env->GetMethodID(cls, "destroyMRec", "(Ljava/lang/String;)V");
}

void Initialize_Ext(const char* engineVersion, const char* extensionVersion)
{
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();
    jclass cls = dmAndroid::LoadClass(env, "com.defold.applovin.MaxDefoldPlugin");
    if (!cls)
    {
        dmLogError("Unable to load com.defold.applovin.MaxDefoldPlugin.");
        return;
    }

    InitJNIMethods(env, cls);
    jstring jEngineVersion = Utf8ToJString(env, engineVersion);
    if (!jEngineVersion)
    {
        env->DeleteLocalRef(cls);
        return;
    }
    jstring jExtensionVersion = Utf8ToJString(env, extensionVersion);
    if (!jExtensionVersion)
    {
        env->DeleteLocalRef(jEngineVersion);
        env->DeleteLocalRef(cls);
        return;
    }
    jmethodID jni_constructor = env->GetMethodID(cls, "<init>", "(Landroid/app/Activity;Ljava/lang/String;Ljava/lang/String;)V");
    jobject localPlugin = jni_constructor
        ? env->NewObject(cls, jni_constructor, threadAttacher.GetActivity()->clazz, jEngineVersion, jExtensionVersion)
        : 0;
    if (localPlugin)
    {
        g_applovin.m_MaxDefoldPlugin = env->NewGlobalRef(localPlugin);
        env->DeleteLocalRef(localPlugin);
    }
    env->DeleteLocalRef(jEngineVersion);
    env->DeleteLocalRef(jExtensionVersion);
    env->DeleteLocalRef(cls);
}

void Finalize_Ext()
{
    if (!g_applovin.m_MaxDefoldPlugin)
    {
        return;
    }

    CallVoidMethod(g_applovin.m_MaxDefoldPlugin, g_applovin.m_Destroy);
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();
    env->DeleteGlobalRef(g_applovin.m_MaxDefoldPlugin);
    g_applovin.m_MaxDefoldPlugin = 0;
}

void Initialize(const char* sdkKey)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_Initialize, sdkKey);
}

bool IsInitialized()
{
    return CallBoolMethod(g_applovin.m_MaxDefoldPlugin, g_applovin.m_IsInitialized);
}

void ShowMediationDebugger()
{
    CallVoidMethod(g_applovin.m_MaxDefoldPlugin, g_applovin.m_ShowMediationDebugger);
}

void SetHasUserConsent(bool hasUserConsent)
{
    CallVoidMethodBool(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetHasUserConsent, hasUserConsent);
}

bool HasUserConsent()
{
    return CallBoolMethod(g_applovin.m_MaxDefoldPlugin, g_applovin.m_HasUserConsent);
}

void SetDoNotSell(bool doNotSell)
{
    CallVoidMethodBool(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetDoNotSell, doNotSell);
}

bool IsDoNotSell()
{
    return CallBoolMethod(g_applovin.m_MaxDefoldPlugin, g_applovin.m_IsDoNotSell);
}

void SetTermsAndPrivacyPolicyFlowEnabled(bool enabled)
{
    CallVoidMethodBool(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetTermsAndPrivacyPolicyFlowEnabled, enabled);
}

void SetPrivacyPolicyUrl(const char* urlString)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetPrivacyPolicyUrl, urlString);
}

void SetTermsOfServiceUrl(const char* urlString)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetTermsOfServiceUrl, urlString);
}

void SetConsentFlowDebugUserGeography(const char* userGeographyString)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetConsentFlowDebugUserGeography, userGeographyString);
}

void ShowCmpForExistingUser()
{
    CallVoidMethod(g_applovin.m_MaxDefoldPlugin, g_applovin.m_ShowCmpForExistingUser);
}

bool HasSupportedCmp()
{
    return CallBoolMethod(g_applovin.m_MaxDefoldPlugin, g_applovin.m_HasSupportedCmp);
}

bool IsTablet()
{
    return CallBoolMethod(g_applovin.m_MaxDefoldPlugin, g_applovin.m_IsTablet);
}

void SetUserId(const char* userId)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetUserId, userId);
}

void SetMuted(bool muted)
{
    CallVoidMethodBool(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetMuted, muted);
}

bool IsMuted()
{
    return CallBoolMethod(g_applovin.m_MaxDefoldPlugin, g_applovin.m_IsMuted);
}

void SetVerboseLoggingEnabled(bool enabled)
{
    CallVoidMethodBool(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetVerboseLoggingEnabled, enabled);
}

bool IsVerboseLoggingEnabled()
{
    return CallBoolMethod(g_applovin.m_MaxDefoldPlugin, g_applovin.m_IsVerboseLoggingEnabled);
}

void SetCreativeDebuggerEnabled(bool enabled)
{
    CallVoidMethodBool(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetCreativeDebuggerEnabled, enabled);
}

void SetTestDeviceAdvertisingIds(const char** advertisingIds, int count)
{
    if (!g_applovin.m_MaxDefoldPlugin || !g_applovin.m_SetTestDeviceAdvertisingIds
        || count < 0 || (count > 0 && !advertisingIds))
    {
        return;
    }
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jclass stringClass = env->FindClass("java/lang/String");
    if (!stringClass)
    {
        return;
    }
    jobjectArray jAdvertisingIds = env->NewObjectArray((jsize)count, stringClass, NULL);
    if (!jAdvertisingIds)
    {
        env->DeleteLocalRef(stringClass);
        return;
    }
    for (int i = 0; i < count; ++i)
    {
        jstring jAdvertisingId = Utf8ToJString(env, advertisingIds[i]);
        if (!jAdvertisingId)
        {
            env->DeleteLocalRef(jAdvertisingIds);
            env->DeleteLocalRef(stringClass);
            return;
        }
        env->SetObjectArrayElement(jAdvertisingIds, (jsize)i, jAdvertisingId);
        env->DeleteLocalRef(jAdvertisingId);
        if (env->ExceptionCheck())
        {
            env->DeleteLocalRef(jAdvertisingIds);
            env->DeleteLocalRef(stringClass);
            return;
        }
    }

    env->CallVoidMethod(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetTestDeviceAdvertisingIds, jAdvertisingIds);
    env->DeleteLocalRef(jAdvertisingIds);
    env->DeleteLocalRef(stringClass);
}

void TrackEvent(const char* event, const char* parameters)
{
    CallVoidMethodCharChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_TrackEvent, event, parameters);
}

void LoadInterstitial(const char* adUnitId)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_LoadInterstitial, adUnitId);
}

bool IsInterstitialReady(const char* adUnitId)
{
    return CallBoolMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_IsInterstitialReady, adUnitId);
}

void ShowInterstitial(const char* adUnitId, const char* placement)
{
    CallVoidMethodCharChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_ShowInterstitial, adUnitId, placement);
}

void SetInterstitialExtraParameter(const char* adUnitId, const char* key, const char* value)
{
    CallVoidMethodCharCharChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetInterstitialExtraParameter, adUnitId, key, value);
}

void LoadRewardedAd(const char* adUnitId)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_LoadRewardedAd, adUnitId);
}

bool IsRewardedAdReady(const char* adUnitId)
{
    return CallBoolMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_IsRewardedAdReady, adUnitId);
}

void ShowRewardedAd(const char* adUnitId, const char* placement)
{
    CallVoidMethodCharChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_ShowRewardedAd, adUnitId, placement);
}

void SetRewardedAdExtraParameter(const char* adUnitId, const char* key, const char* value)
{
    CallVoidMethodCharCharChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetRewardedAdExtraParameter, adUnitId, key, value);
}

void CreateBanner(const char* adUnitId, const char* bannerPosition)
{
    CallVoidMethodCharChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_CreateBanner, adUnitId, bannerPosition);
}

void SetBannerBackgroundColor(const char* adUnitId, const char* hexColorCode)
{
    CallVoidMethodCharChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetBannerBackgroundColor, adUnitId, hexColorCode);
}

void SetBannerPlacement(const char* adUnitId, const char* placement)
{
    CallVoidMethodCharChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetBannerPlacement, adUnitId, placement);
}

void SetBannerExtraParameter(const char* adUnitId, const char* key, const char* value)
{
    CallVoidMethodCharCharChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetBannerExtraParameter, adUnitId, key, value);
}

void UpdateBannerPosition(const char* adUnitId, const char* bannerPosition)
{
    CallVoidMethodCharChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_UpdateBannerPosition, adUnitId, bannerPosition);
}

void StartBannerAutoRefresh(const char* adUnitId)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_StartBannerAutoRefresh, adUnitId);
}

void StopBannerAutoRefresh(const char* adUnitId)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_StopBannerAutoRefresh, adUnitId);
}

void ShowBanner(const char* adUnitId)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_ShowBanner, adUnitId);
}

void HideBanner(const char* adUnitId)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_HideBanner, adUnitId);
}

void DestroyBanner(const char* adUnitId)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_DestroyBanner, adUnitId);
}

void CreateMRec(const char* adUnitId, const char* mrecPosition)
{
    CallVoidMethodCharChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_CreateMRec, adUnitId, mrecPosition);
}

void SetMRecPlacement(const char* adUnitId, const char* placement)
{
    CallVoidMethodCharChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetMRecPlacement, adUnitId, placement);
}

void SetMRecExtraParameter(const char* adUnitId, const char* key, const char* value)
{
    CallVoidMethodCharCharChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetMRecExtraParameter, adUnitId, key, value);
}

void UpdateMRecPosition(const char* adUnitId, const char* mrecPosition)
{
    CallVoidMethodCharChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_UpdateMRecPosition, adUnitId, mrecPosition);
}

void StartMRecAutoRefresh(const char* adUnitId)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_StartMRecAutoRefresh, adUnitId);
}

void StopMRecAutoRefresh(const char* adUnitId)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_StopMRecAutoRefresh, adUnitId);
}

void ShowMRec(const char* adUnitId)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_ShowMRec, adUnitId);
}

void HideMRec(const char* adUnitId)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_HideMRec, adUnitId);
}

void DestroyMRec(const char* adUnitId)
{
    CallVoidMethodChar(g_applovin.m_MaxDefoldPlugin, g_applovin.m_DestroyMRec, adUnitId);
}

}//namespace dmAppLovin

#endif
