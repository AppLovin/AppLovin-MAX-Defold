#if defined(DM_PLATFORM_IOS)

#include "applovin_private.h"
#include "applovin_callback_private.h"

#import "MADefoldPlugin.h"

#include <stdlib.h>
#include <string.h>

namespace dmAppLovin {

static MADefoldPlugin* g_IosPlugin;
static char* g_ExtensionVersion;

static NSString* _Nullable StringFromUtf8(const char* value, const char* parameterName)
{
    if (!value)
    {
        dmLogError("AppLovin %s cannot be null", parameterName);
        return nil;
    }

    NSString* result = [[NSString alloc] initWithBytes:value
                                                length:strlen(value)
                                              encoding:NSUTF8StringEncoding];
    if (!result)
    {
        dmLogError("AppLovin %s must be valid UTF-8", parameterName);
    }
    return result;
}

static NSDictionary<NSString*, id>* EventParametersFromJson(const char* parameters)
{
    if (!parameters || parameters[0] == '\0')
    {
        return @{};
    }

    NSString* json = StringFromUtf8(parameters, "track_event parameters");
    if (!json)
    {
        return @{};
    }

    NSData* data = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSError* error = nil;
    id object = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
    if (![object isKindOfClass:[NSDictionary class]])
    {
        dmLogError("AppLovin track_event parameters must be a JSON object: %s",
                   error.localizedDescription.UTF8String ?: "invalid JSON");
        return @{};
    }

    return (NSDictionary<NSString*, id>*)object;
}

void Initialize_Ext(const char* engineVersion, const char* extensionVersion)
{
    (void)engineVersion;
    free(g_ExtensionVersion);
    g_ExtensionVersion = strdup(extensionVersion ? extensionVersion : "0.0.0");

    UIWindow* window = dmGraphics::GetNativeiOSUIWindow();
    UIView* mainView = window.rootViewController.view;
    if (!mainView)
    {
        dmLogError("AppLovin cannot initialize without the Defold root view");
        return;
    }
    g_IosPlugin = [[MADefoldPlugin alloc] initWithView:mainView];
}

void Finalize_Ext()
{
    if (g_IosPlugin)
    {
        [g_IosPlugin destroy];
        g_IosPlugin = nil;
    }
    free(g_ExtensionVersion);
    g_ExtensionVersion = 0;
}

void Initialize(const char* sdkKey)
{
    NSString* pluginVersion =
        StringFromUtf8(g_ExtensionVersion ? g_ExtensionVersion : "0.0.0", "plugin version");
    if (!pluginVersion)
    {
        pluginVersion = @"0.0.0";
    }

    NSString* sdkKeyString = StringFromUtf8(sdkKey, "SDK key");
    if (!sdkKeyString)
    {
        return;
    }
    [g_IosPlugin initialize:pluginVersion sdkKey:sdkKeyString];
}

bool IsInitialized()
{
    return [g_IosPlugin isInitialized];
}

void ShowMediationDebugger()
{
    [g_IosPlugin showMediationDebugger];
}

void SetHasUserConsent(bool hasUserConsent)
{
    [g_IosPlugin setHasUserConsent: hasUserConsent];
}

bool HasUserConsent()
{
    return [g_IosPlugin hasUserConsent];
}

void SetDoNotSell(bool doNotSell)
{
    [g_IosPlugin setDoNotSell: doNotSell];
}

bool IsDoNotSell()
{
    return [g_IosPlugin isDoNotSell];
}

void SetTermsAndPrivacyPolicyFlowEnabled(bool enabled)
{
    [g_IosPlugin setTermsAndPrivacyPolicyFlowEnabled: enabled];
}

void SetPrivacyPolicyUrl(const char* urlString)
{
    NSString* value = StringFromUtf8(urlString, "privacy policy URL");
    if (!value) return;
    [g_IosPlugin setPrivacyPolicyURL:value];
}

void SetTermsOfServiceUrl(const char* urlString)
{
    NSString* value = StringFromUtf8(urlString, "terms of service URL");
    if (!value) return;
    [g_IosPlugin setTermsOfServiceURL:value];
}

void SetConsentFlowDebugUserGeography(const char* userGeographyString)
{
    NSString* value = StringFromUtf8(userGeographyString, "consent flow debug user geography");
    if (!value) return;
    [g_IosPlugin setConsentFlowDebugUserGeography:value];
}

void ShowCmpForExistingUser()
{
    [g_IosPlugin showCMPForExistingUser];
}

bool HasSupportedCmp()
{
    return [g_IosPlugin hasSupportedCMP];
}

bool IsTablet()
{
    return [g_IosPlugin isTablet];
}

void SetUserId(const char* userId)
{
    NSString* value = StringFromUtf8(userId, "user ID");
    if (!value) return;
    [g_IosPlugin setUserId:value];
}

void SetMuted(bool muted)
{
    [g_IosPlugin setMuted: muted];
}

bool IsMuted()
{
    return [g_IosPlugin isMuted];
}

void SetVerboseLoggingEnabled(bool enabled)
{
    [g_IosPlugin setVerboseLoggingEnabled: enabled];
}

bool IsVerboseLoggingEnabled()
{
    return [g_IosPlugin isVerboseLoggingEnabled];
}

void SetCreativeDebuggerEnabled(bool enabled)
{
    [g_IosPlugin setCreativeDebuggerEnabled: enabled];
}

void SetTestDeviceAdvertisingIds(const char** advertisingIds, int count)
{
    if (count < 0 || (count > 0 && !advertisingIds))
    {
        dmLogError("AppLovin test device advertising ID array is invalid");
        return;
    }

    NSMutableArray<NSString*>* idsArray = [NSMutableArray arrayWithCapacity:(NSUInteger)count];
    for (int i = 0; i < count; ++i)
    {
        NSString* advertisingId =
            StringFromUtf8(advertisingIds[i], "test device advertising ID");
        if (!advertisingId)
        {
            return;
        }
        [idsArray addObject:advertisingId];
    }
    [g_IosPlugin setTestDeviceAdvertisingIds:idsArray];
}

void TrackEvent(const char* event, const char* parameters)
{
    NSString* eventString = StringFromUtf8(event, "event name");
    if (!eventString) return;
    [g_IosPlugin trackEvent:eventString parameters:EventParametersFromJson(parameters)];
}

void LoadInterstitial(const char* adUnitId)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "interstitial ad unit ID");
    if (!adUnitIdentifier) return;
    [g_IosPlugin loadInterstitialForAdUnitIdentifier:adUnitIdentifier];
}

bool IsInterstitialReady(const char* adUnitId)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "interstitial ad unit ID");
    return adUnitIdentifier ? [g_IosPlugin isInterstitialReadyForAdUnitIdentifier:adUnitIdentifier] : false;
}

void ShowInterstitial(const char* adUnitId, const char* placement)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "interstitial ad unit ID");
    NSString* placementString = StringFromUtf8(placement, "interstitial placement");
    if (!adUnitIdentifier || !placementString) return;
    [g_IosPlugin showInterstitialForAdUnitIdentifier:adUnitIdentifier placement:placementString];
}

void SetInterstitialExtraParameter(const char* adUnitId, const char* key, const char* value)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "interstitial ad unit ID");
    NSString* keyString = StringFromUtf8(key, "interstitial extra parameter key");
    NSString* valueString = StringFromUtf8(value, "interstitial extra parameter value");
    if (!adUnitIdentifier || !keyString || !valueString) return;
    [g_IosPlugin setInterstitialExtraParameterForAdUnitIdentifier:adUnitIdentifier
                                                              key:keyString
                                                            value:valueString];
}

void LoadRewardedAd(const char* adUnitId)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "rewarded ad unit ID");
    if (!adUnitIdentifier) return;
    [g_IosPlugin loadRewardedAdForAdUnitIdentifier:adUnitIdentifier];
}

bool IsRewardedAdReady(const char* adUnitId)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "rewarded ad unit ID");
    return adUnitIdentifier ? [g_IosPlugin isRewardedAdReadyForAdUnitIdentifier:adUnitIdentifier] : false;
}

void ShowRewardedAd(const char* adUnitId, const char* placement)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "rewarded ad unit ID");
    NSString* placementString = StringFromUtf8(placement, "rewarded placement");
    if (!adUnitIdentifier || !placementString) return;
    [g_IosPlugin showRewardedAdForAdUnitIdentifier:adUnitIdentifier placement:placementString];
}

void SetRewardedAdExtraParameter(const char* adUnitId, const char* key, const char* value)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "rewarded ad unit ID");
    NSString* keyString = StringFromUtf8(key, "rewarded extra parameter key");
    NSString* valueString = StringFromUtf8(value, "rewarded extra parameter value");
    if (!adUnitIdentifier || !keyString || !valueString) return;
    [g_IosPlugin setRewardedAdExtraParameterForAdUnitIdentifier:adUnitIdentifier
                                                            key:keyString
                                                          value:valueString];
}

void CreateBanner(const char* adUnitId, const char* bannerPosition)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "banner ad unit ID");
    NSString* position = StringFromUtf8(bannerPosition, "banner position");
    if (!adUnitIdentifier || !position) return;
    [g_IosPlugin createBannerForAdUnitIdentifier:adUnitIdentifier atPosition:position];
}

void SetBannerBackgroundColor(const char* adUnitId, const char* hexColorCode)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "banner ad unit ID");
    NSString* color = StringFromUtf8(hexColorCode, "banner background color");
    if (!adUnitIdentifier || !color) return;
    [g_IosPlugin setBannerBackgroundColorForAdUnitIdentifier:adUnitIdentifier
                                                hexColorCode:color];
}

void SetBannerPlacement(const char* adUnitId, const char* placement)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "banner ad unit ID");
    NSString* placementString = StringFromUtf8(placement, "banner placement");
    if (!adUnitIdentifier || !placementString) return;
    [g_IosPlugin setBannerPlacement:placementString forAdUnitIdentifier:adUnitIdentifier];
}

void SetBannerExtraParameter(const char* adUnitId, const char* key, const char* value)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "banner ad unit ID");
    NSString* keyString = StringFromUtf8(key, "banner extra parameter key");
    NSString* valueString = StringFromUtf8(value, "banner extra parameter value");
    if (!adUnitIdentifier || !keyString || !valueString) return;
    [g_IosPlugin setBannerExtraParameterForAdUnitIdentifier:adUnitIdentifier
                                                        key:keyString
                                                      value:valueString];
}

void UpdateBannerPosition(const char* adUnitId, const char* bannerPosition)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "banner ad unit ID");
    NSString* position = StringFromUtf8(bannerPosition, "banner position");
    if (!adUnitIdentifier || !position) return;
    [g_IosPlugin updateBannerPosition:position forAdUnitIdentifier:adUnitIdentifier];
}

void StartBannerAutoRefresh(const char* adUnitId)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "banner ad unit ID");
    if (!adUnitIdentifier) return;
    [g_IosPlugin startBannerAutoRefreshForAdUnitIdentifier:adUnitIdentifier];
}

void StopBannerAutoRefresh(const char* adUnitId)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "banner ad unit ID");
    if (!adUnitIdentifier) return;
    [g_IosPlugin stopBannerAutoRefreshForAdUnitIdentifier:adUnitIdentifier];
}

void ShowBanner(const char* adUnitId)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "banner ad unit ID");
    if (!adUnitIdentifier) return;
    [g_IosPlugin showBannerForAdUnitIdentifier:adUnitIdentifier];
}

void HideBanner(const char* adUnitId)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "banner ad unit ID");
    if (!adUnitIdentifier) return;
    [g_IosPlugin hideBannerForAdUnitIdentifier:adUnitIdentifier];
}

void DestroyBanner(const char* adUnitId)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "banner ad unit ID");
    if (!adUnitIdentifier) return;
    [g_IosPlugin destroyBannerForAdUnitIdentifier:adUnitIdentifier];
}

void CreateMRec(const char* adUnitId, const char* mrecPosition)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "MREC ad unit ID");
    NSString* position = StringFromUtf8(mrecPosition, "MREC position");
    if (!adUnitIdentifier || !position) return;
    [g_IosPlugin createMRecForAdUnitIdentifier:adUnitIdentifier atPosition:position];
}

void SetMRecPlacement(const char* adUnitId, const char* placement)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "MREC ad unit ID");
    NSString* placementString = StringFromUtf8(placement, "MREC placement");
    if (!adUnitIdentifier || !placementString) return;
    [g_IosPlugin setMRecPlacement:placementString forAdUnitIdentifier:adUnitIdentifier];
}

void SetMRecExtraParameter(const char* adUnitId, const char* key, const char* value)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "MREC ad unit ID");
    NSString* keyString = StringFromUtf8(key, "MREC extra parameter key");
    NSString* valueString = StringFromUtf8(value, "MREC extra parameter value");
    if (!adUnitIdentifier || !keyString || !valueString) return;
    [g_IosPlugin setMRecExtraParameterForAdUnitIdentifier:adUnitIdentifier
                                                      key:keyString
                                                    value:valueString];
}

void UpdateMRecPosition(const char* adUnitId, const char* mrecPosition)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "MREC ad unit ID");
    NSString* position = StringFromUtf8(mrecPosition, "MREC position");
    if (!adUnitIdentifier || !position) return;
    [g_IosPlugin updateMRecPosition:position forAdUnitIdentifier:adUnitIdentifier];
}

void StartMRecAutoRefresh(const char* adUnitId)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "MREC ad unit ID");
    if (!adUnitIdentifier) return;
    [g_IosPlugin startMRecAutoRefreshForAdUnitIdentifier:adUnitIdentifier];
}

void StopMRecAutoRefresh(const char* adUnitId)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "MREC ad unit ID");
    if (!adUnitIdentifier) return;
    [g_IosPlugin stopMRecAutoRefreshForAdUnitIdentifier:adUnitIdentifier];
}

void ShowMRec(const char* adUnitId)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "MREC ad unit ID");
    if (!adUnitIdentifier) return;
    [g_IosPlugin showMRecForAdUnitIdentifier:adUnitIdentifier];
}

void HideMRec(const char* adUnitId)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "MREC ad unit ID");
    if (!adUnitIdentifier) return;
    [g_IosPlugin hideMRecForAdUnitIdentifier:adUnitIdentifier];
}

void DestroyMRec(const char* adUnitId)
{
    NSString* adUnitIdentifier = StringFromUtf8(adUnitId, "MREC ad unit ID");
    if (!adUnitIdentifier) return;
    [g_IosPlugin destroyMRecForAdUnitIdentifier:adUnitIdentifier];
}

} //namespace dmAppLovin

#endif
