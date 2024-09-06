#if defined(DM_PLATFORM_ANDROID)

#include <dmsdk/dlib/android.h>
#include "applovin_private.h"
#include "com_defold_applovin_MaxDefoldPlugin.h"
#include "applovin_callback_private.h"

JNIEXPORT void JNICALL Java_com_defold_applovin_MaxDefoldPlugin_appLovinAddToQueue(JNIEnv * env, jclass cls, jstring jname, jstring jjson)
{
    const char* name = env->GetStringUTFChars(jname, 0);
    const char* json = env->GetStringUTFChars(jjson, 0);
    dmAppLovin::AddToQueueCallback(name, json);
    env->ReleaseStringUTFChars(jname, name);
    env->ReleaseStringUTFChars(jjson, json);
}

namespace dmAppLovin {

struct AppLovin
{
    jobject   m_MaxDefoldPlugin;

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
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    env->CallVoidMethod(instance, method);
}

static bool CallBoolMethod(jobject instance, jmethodID method)
{
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jboolean return_value = (jboolean)env->CallBooleanMethod(instance, method);
    return JNI_TRUE == return_value;
}

static bool CallBoolMethodChar(jobject instance, jmethodID method, const char* cstr)
{
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jstring jstr = env->NewStringUTF(cstr);
    jboolean return_value = (jboolean)env->CallBooleanMethod(instance, method, jstr);
    env->DeleteLocalRef(jstr);
    return JNI_TRUE == return_value;
}

static void CallVoidMethodChar(jobject instance, jmethodID method, const char* cstr)
{
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jstring jstr = env->NewStringUTF(cstr);
    env->CallVoidMethod(instance, method, jstr);
    env->DeleteLocalRef(jstr);
}

static char const* CallCharMethodChar(jobject instance, jmethodID method, const char* cstr)
{
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jstring jstr = env->NewStringUTF(cstr);
    jstring returned_value = (jstring)env->CallObjectMethod(instance, method, jstr);
    env->DeleteLocalRef(jstr);
    if (returned_value == NULL)
    {
        return NULL;
    }
    const char* returned_char = env->GetStringUTFChars(returned_value, 0);
    env->DeleteLocalRef(returned_value);
    return returned_char;
}

static void CallVoidMethodCharChar(jobject instance, jmethodID method, const char* cstr_1, const char* cstr_2)
{
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jstring jstr_1 = env->NewStringUTF(cstr_1);
    jstring jstr_2 = env->NewStringUTF(cstr_2);
    env->CallVoidMethod(instance, method, jstr_1, jstr_2);
    env->DeleteLocalRef(jstr_1);
    env->DeleteLocalRef(jstr_2);
}

static void CallVoidMethodCharCharChar(jobject instance, jmethodID method, const char* cstr_1, const char* cstr_2, const char* cstr_3)
{
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jstring jstr_1 = env->NewStringUTF(cstr_1);
    jstring jstr_2 = env->NewStringUTF(cstr_2);
    jstring jstr_3 = env->NewStringUTF(cstr_3);
    env->CallVoidMethod(instance, method, jstr_1, jstr_2, jstr_3);
    env->DeleteLocalRef(jstr_1);
    env->DeleteLocalRef(jstr_2);
    env->DeleteLocalRef(jstr_3);
}

static void CallVoidMethodCharInt(jobject instance, jmethodID method, const char* cstr, int cint)
{
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jstring jstr = env->NewStringUTF(cstr);
    env->CallVoidMethod(instance, method, jstr, cint);
    env->DeleteLocalRef(jstr);
}

static void CallVoidMethodInt(jobject instance, jmethodID method, int cint)
{
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    env->CallVoidMethod(instance, method, cint);
}

static void CallVoidMethodBool(jobject instance, jmethodID method, bool cbool)
{
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    env->CallVoidMethod(instance, method, cbool);
}

static void InitJNIMethods(JNIEnv* env, jclass cls)
{
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

void Initialize_Ext(const char* version, const char* extVersion)
{
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();
    jclass cls = dmAndroid::LoadClass(env, "com.defold.applovin.MaxDefoldPlugin");

    InitJNIMethods(env, cls);
    jstring jstr = env->NewStringUTF(version);
    jstring jstr1 = env->NewStringUTF(extVersion);
    jmethodID jni_constructor = env->GetMethodID(cls, "<init>", "(Landroid/app/Activity;Ljava/lang/String;Ljava/lang/String;)V");
    g_applovin.m_MaxDefoldPlugin = env->NewGlobalRef(env->NewObject(cls, jni_constructor, threadAttacher.GetActivity()->clazz, jstr, jstr1));
    env->DeleteLocalRef(jstr);
    env->DeleteLocalRef(jstr1);
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
    dmAndroid::ThreadAttacher threadAttacher;
    JNIEnv* env = threadAttacher.GetEnv();

    jobjectArray jAdvertisingIds = env->NewObjectArray(count, env->FindClass("java/lang/String"), NULL);
    for(int i = 0; i < count; i++) {
        env->SetObjectArrayElement(jAdvertisingIds, i, env->NewStringUTF(advertisingIds[i]));
    }

    env->CallVoidMethod(g_applovin.m_MaxDefoldPlugin, g_applovin.m_SetTestDeviceAdvertisingIds, jAdvertisingIds);
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
