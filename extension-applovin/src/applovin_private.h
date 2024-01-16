#if defined(DM_PLATFORM_ANDROID) || defined(DM_PLATFORM_IOS)

#pragma once

namespace dmAppLovin {

// The same constants/enums are in MaxDefoldPlugin.java
// If you change enums here, pls make sure you update the constants there as well

// enum 
// {
// };

void Initialize_Ext(const char* version, const char* extVersion);

void OnResume();

void OnPause();

// AppLovin SDK

void Initialize(const char* sdkKey);

void ShowMediationDebugger();

bool IsInitialized();

void SetHasUserConsent(bool hasUserConsent);

bool HasUserConsent();

void SetIsAgeRestrictedUser(bool isAgeRestrictedUser);

bool IsAgeRestrictedUser();

void SetDoNotSell(bool doNotSell);

bool IsDoNotSell();

void SetTermsAndPrivacyPolicyFlowEnabled(bool enabled);

void SetPrivacyPolicyUrl(const char* urlString);

void SetTermsOfServiceUrl(const char* urlString);

void SetConsentFlowDebugUserGeography(const char* userGeographyString);

void ShowCmpForExistingUser();

bool HasSupportedCmp();

bool IsTablet();

void SetUserId(const char* userId);

void SetMuted(bool muted);

bool IsMuted();

void SetVerboseLoggingEnabled(bool enabled);

bool IsVerboseLoggingEnabled();

void SetCreativeDebuggerEnabled(bool enabled);

void SetTestDeviceAdvertisingIds(const char** advertisingIds, int count);

void TrackEvent(const char* event, const char* parameters);

void CreateBanner(const char* adUnitId, const char* bannerPosition);

void SetBannerBackgroundColor(const char* adUnitId, const char* hexColorCode);

void SetBannerPlacement(const char* adUnitId, const char* placement);

void SetBannerExtraParameter(const char* adUnitId, const char* key, const char* value);

void UpdateBannerPosition(const char* adUnitId, const char* bannerPosition);

void ShowBanner(const char* adUnitId);

void HideBanner(const char* adUnitId);

void DestroyBanner(const char* adUnitId);

void CreateMRec(const char* adUnitId, const char* mrecPosition);

void SetMRecPlacement(const char* adUnitId, const char* placement);

void SetMRecExtraParameter(const char* adUnitId, const char* key, const char* value);

void UpdateMRecPosition(const char* adUnitId, const char* mrecPosition);

void ShowMRec(const char* adUnitId);

void HideMRec(const char* adUnitId);

void DestroyMRec(const char* adUnitId);

void LoadInterstitial(const char* adUnitId);

void ShowInterstitial(const char* adUnitId);

bool IsInterstitialReady(const char* adUnitId);

void LoadRewardedAd(const char* adUnitId);

bool IsRewardedAdReady(const char* adUnitId);

void ShowRewardedAd(const char* adUnitId);

void SetRewardedAdExtraParameter(const char* adUnitId, const char* key, const char* value);

} //namespace dmAppLovin

#endif
