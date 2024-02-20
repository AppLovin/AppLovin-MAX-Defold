#if defined(DM_PLATFORM_IOS)

#include "applovin_private.h"
#include "applovin_callback_private.h"

#import "MADefoldPlugin.h"

namespace dmAppLovin {

static MADefoldPlugin *iosPlugin;
static NSString *const kPluginVersion = @"1.1.0";

void Initialize_Ext(const char* version, const char* extVersion)
{
    UIWindow* window = dmGraphics::GetNativeiOSUIWindow();
    iosPlugin = [[MADefoldPlugin alloc] initWithView: window.rootViewController.view];
}

void Initialize(const char* sdkKey)
{
    [iosPlugin initialize: kPluginVersion sdkKey: [NSString stringWithUTF8String: sdkKey]];
}

bool IsInitialized()
{
    return [iosPlugin isInitialized];
}

void ShowMediationDebugger()
{
    [iosPlugin showMediationDebugger];
}

void SetHasUserConsent(bool hasUserConsent)
{
    [iosPlugin setHasUserConsent: hasUserConsent];
}

bool HasUserConsent()
{
    return [iosPlugin hasUserConsent];
}

void SetIsAgeRestrictedUser(bool isAgeRestrictedUser)
{
    [iosPlugin setIsAgeRestrictedUser: isAgeRestrictedUser];
}

bool IsAgeRestrictedUser()
{
    return [iosPlugin isAgeRestrictedUser];
}

void SetDoNotSell(bool doNotSell)
{
    [iosPlugin setDoNotSell: doNotSell];
}

bool IsDoNotSell()
{
    return [iosPlugin isDoNotSell];
}

void SetTermsAndPrivacyPolicyFlowEnabled(bool enabled)
{
    [iosPlugin setTermsAndPrivacyPolicyFlowEnabled: enabled];
}

void SetPrivacyPolicyUrl(const char* urlString)
{
    [iosPlugin setPrivacyPolicyURL: [NSString stringWithUTF8String: urlString]];
}

void SetTermsOfServiceUrl(const char* urlString)
{
    [iosPlugin setTermsOfServiceURL: [NSString stringWithUTF8String: urlString]];
}

void SetConsentFlowDebugUserGeography(const char* userGeographyString)
{
    [iosPlugin setConsentFlowDebugUserGeography: [NSString stringWithUTF8String: userGeographyString]];
}

void ShowCmpForExistingUser()
{
    [iosPlugin showCMPForExistingUser];
}

bool HasSupportedCmp()
{
    return [iosPlugin hasSupportedCMP];
}

bool IsTablet()
{
    return [iosPlugin isTablet];
}

void SetUserId(const char* userId)
{
    [iosPlugin setUserId: [NSString stringWithUTF8String: userId]];
}

void SetMuted(bool muted)
{
    [iosPlugin setMuted: muted];
}

bool IsMuted()
{
    return [iosPlugin isMuted];
}

void SetVerboseLoggingEnabled(bool enabled)
{
    [iosPlugin setVerboseLoggingEnabled: enabled];
}

bool IsVerboseLoggingEnabled()
{
    return [iosPlugin isVerboseLoggingEnabled];
}

void SetCreativeDebuggerEnabled(bool enabled)
{
    [iosPlugin setCreativeDebuggerEnabled: enabled];
}

void SetTestDeviceAdvertisingIds(const char** advertisingIds, int count)
{
    NSMutableArray* idsArray = [NSMutableArray arrayWithCapacity: count];
    for(int i = 0; i < count; i++) {
        [idsArray addObject: [NSString stringWithUTF8String: advertisingIds[i]]];
    }
    [iosPlugin setTestDeviceAdvertisingIds: idsArray];
}

void TrackEvent(const char* event, const char* parameters)
{
    [iosPlugin trackEvent: [NSString stringWithUTF8String: event]
               parameters: [NSDictionary dictionary]];
}

void LoadInterstitial(const char* adUnitId)
{
    [iosPlugin loadInterstitialForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

bool IsInterstitialReady(const char* adUnitId)
{
    return [iosPlugin isInterstitialReadyForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void ShowInterstitial(const char* adUnitId, const char* placement)
{
    [iosPlugin showInterstitialForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId] placement: [NSString stringWithUTF8String: placement]];
}

void SetInterstitialAdExtraParameter(const char* adUnitId, const char* key, const char* value)
{
    [iosPlugin setInterstitialExtraParameterForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]
                                                            key: [NSString stringWithUTF8String: key]
                                                          value: [NSString stringWithUTF8String: value]];
}

void LoadRewardedAd(const char* adUnitId)
{
    [iosPlugin loadRewardedAdForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

bool IsRewardedAdReady(const char* adUnitId)
{
    return [iosPlugin isRewardedAdReadyForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void ShowRewardedAd(const char* adUnitId, const char* placement)
{
    [iosPlugin showRewardedAdForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId] placement: [NSString stringWithUTF8String: placement]];
}

void SetRewardedAdExtraParameter(const char* adUnitId, const char* key, const char* value)
{
    [iosPlugin setRewardedAdExtraParameterForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]
                                                          key: [NSString stringWithUTF8String: key]
                                                        value: [NSString stringWithUTF8String: value]];
}

void CreateBanner(const char* adUnitId, const char* bannerPosition)
{
    [iosPlugin createBannerForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]
                                    atPosition: [NSString stringWithUTF8String: bannerPosition]];
}

void SetBannerBackgroundColor(const char* adUnitId, const char* hexColorCode)
{
    [iosPlugin setBannerBackgroundColorForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]
                                              hexColorCode: [NSString stringWithUTF8String: hexColorCode]];
}

void SetBannerPlacement(const char* adUnitId, const char* placement)
{
    [iosPlugin setBannerPlacement: [NSString stringWithUTF8String: placement]
              forAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void SetBannerExtraParameter(const char* adUnitId, const char* key, const char* value)
{
    [iosPlugin setBannerExtraParameterForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]
                                                      key: [NSString stringWithUTF8String: key]
                                                    value: [NSString stringWithUTF8String: value]];
}

void UpdateBannerPosition(const char* adUnitId, const char* bannerPosition)
{
    [iosPlugin updateBannerPosition: [NSString stringWithUTF8String: bannerPosition]
                forAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void StartBannerAutoRefresh(const char* adUnitId)
{
    [iosPlugin startBannerAutoRefreshForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void StopBannerAutoRefresh(const char* adUnitId)
{
    [iosPlugin stopBannerAutoRefreshForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void ShowBanner(const char* adUnitId)
{
    [iosPlugin showBannerForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void HideBanner(const char* adUnitId)
{
    [iosPlugin hideBannerForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void DestroyBanner(const char* adUnitId)
{
    [iosPlugin destroyBannerForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void CreateMRec(const char* adUnitId, const char* mrecPosition)
{
    [iosPlugin createMRecForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]
                                  atPosition: [NSString stringWithUTF8String: mrecPosition]];
}

void SetMRecPlacement(const char* adUnitId, const char* placement)
{
    [iosPlugin setMRecPlacement: [NSString stringWithUTF8String: placement]
            forAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void SetMRecExtraParameter(const char* adUnitId, const char* key, const char* value)
{
    [iosPlugin setMRecExtraParameterForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]
                                                    key: [NSString stringWithUTF8String: key]
                                                  value: [NSString stringWithUTF8String: value]];
}

void UpdateMRecPosition(const char* adUnitId, const char* mrecPosition)
{
    [iosPlugin updateMRecPosition: [NSString stringWithUTF8String: mrecPosition]
              forAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void StartMRecAutoRefresh(const char* adUnitId)
{
    [iosPlugin startMRecAutoRefreshForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void StopMRecAutoRefresh(const char* adUnitId)
{
    [iosPlugin stopMRecAutoRefreshForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void ShowMRec(const char* adUnitId)
{
    [iosPlugin showMRecForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void HideMRec(const char* adUnitId)
{
    [iosPlugin hideMRecForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

void DestroyMRec(const char* adUnitId)
{
    [iosPlugin destroyMRecForAdUnitIdentifier: [NSString stringWithUTF8String: adUnitId]];
}

} //namespace dmAppLovin

#endif
