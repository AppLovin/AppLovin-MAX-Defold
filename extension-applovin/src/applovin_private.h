#if defined(DM_PLATFORM_ANDROID) || defined(DM_PLATFORM_IOS)

#pragma once

namespace dmAppLovin {

void Initialize_Ext(const char* version, const char* extVersion);

void Initialize(const char* sdkKey);

bool IsInitialized();

void ShowMediationDebugger();

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

void LoadInterstitial(const char* adUnitId);

bool IsInterstitialReady(const char* adUnitId);

void ShowInterstitial(const char* adUnitId);

void SetInterstitialExtraParameter(const char* adUnitId, const char* key, const char* value);

void LoadRewardedAd(const char* adUnitId);

bool IsRewardedAdReady(const char* adUnitId);

void ShowRewardedAd(const char* adUnitId);

void SetRewardedAdExtraParameter(const char* adUnitId, const char* key, const char* value);

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

} //namespace dmAppLovin

#endif
