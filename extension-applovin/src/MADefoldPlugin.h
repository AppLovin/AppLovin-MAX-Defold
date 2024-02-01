#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MADefoldPlugin : NSObject

#pragma mark - Initialization

- (instancetype)initWithView:(UIView *)mainView;
- (void)initialize:(NSString *)pluginVersion sdkKey:(NSString *)sdkKey;
- (BOOL)isInitialized;

#pragma mark - Privacy

- (void)setHasUserConsent:(BOOL)hasUserConsent;
- (BOOL)hasUserConsent;
- (void)setIsAgeRestrictedUser:(BOOL)isAgeRestrictedUser;
- (BOOL)isAgeRestrictedUser;
- (void)setDoNotSell:(BOOL)doNotSell;
- (BOOL)isDoNotSell;

#pragma mark - Terms and Privacy Policy Flow

- (void)setTermsAndPrivacyPolicyFlowEnabled:(BOOL)enabled;
- (void)setPrivacyPolicyURL:(NSString *)urlString;
- (void)setTermsOfServiceURL:(NSString *)urlString;
- (void)setConsentFlowDebugUserGeography:(NSString *)userGeographyString;
- (void)showCMPForExistingUser;
- (BOOL)hasSupportedCMP;

#pragma mark - General

- (BOOL)isTablet;
- (void)showMediationDebugger;
- (void)setUserId:(NSString *)userId;
- (void)setMuted:(BOOL)muted;
- (BOOL)isMuted;
- (void)setVerboseLoggingEnabled:(BOOL)enabled;
- (BOOL)isVerboseLoggingEnabled;
- (void)setCreativeDebuggerEnabled:(BOOL)enabled;
- (void)setTestDeviceAdvertisingIds:(NSArray<NSString *> *)testDeviceAdvertisingIds;

#pragma mark - Event Tracking

- (void)trackEvent:(NSString *)event parameters:(NSDictionary<NSString *, NSString *> *)parameters;

#pragma mark - Interstitials

- (void)loadInterstitialForAdUnitIdentifier:(NSString *)adUnitIdentifier;
- (BOOL)isInterstitialReadyForAdUnitIdentifier:(NSString *)adUnitIdentifier;
- (void)showInterstitialForAdUnitIdentifier:(NSString *)adUnitIdentifier placement:(NSString *)placement;
- (void)setInterstitialExtraParameterForAdUnitIdentifier:(NSString *)adUnitIdentifier key:(NSString *)key value:(NSString *)value;

#pragma mark - Rewarded

- (void)loadRewardedAdForAdUnitIdentifier:(NSString *)adUnitIdentifier;
- (BOOL)isRewardedAdReadyForAdUnitIdentifier:(NSString *)adUnitIdentifier;
- (void)showRewardedAdForAdUnitIdentifier:(NSString *)adUnitIdentifier placement:(NSString *)placement;
- (void)setRewardedAdExtraParameterForAdUnitIdentifier:(NSString *)adUnitIdentifier key:(NSString *)key value:(nullable NSString *)value;

#pragma mark - Banners

- (void)createBannerForAdUnitIdentifier:(NSString *)adUnitIdentifier atPosition:(NSString *)bannerPosition;
- (void)setBannerBackgroundColorForAdUnitIdentifier:(NSString *)adUnitIdentifier hexColorCode:(NSString *)hexColorCode;
- (void)setBannerPlacement:(nullable NSString *)placement forAdUnitIdentifier:(NSString *)adUnitIdentifier;
- (void)setBannerExtraParameterForAdUnitIdentifier:(NSString *)adUnitIdentifier key:(NSString *)key value:(nullable NSString *)value;
- (void)updateBannerPosition:(NSString *)bannerPosition forAdUnitIdentifier:(NSString *)adUnitIdentifier;
- (void)showBannerForAdUnitIdentifier:(NSString *)adUnitIdentifier;
- (void)hideBannerForAdUnitIdentifier:(NSString *)adUnitIdentifier;
- (void)destroyBannerForAdUnitIdentifier:(NSString *)adUnitIdentifier;

#pragma mark - MRECs

- (void)createMRecForAdUnitIdentifier:(NSString *)adUnitIdentifier atPosition:(NSString *)mrecPosition;
- (void)setMRecPlacement:(nullable NSString *)placement forAdUnitIdentifier:(NSString *)adUnitIdentifier;
- (void)setMRecExtraParameterForAdUnitIdentifier:(NSString *)adUnitIdentifier key:(NSString *)key value:(nullable NSString *)value;
- (void)updateMRecPosition:(NSString *)mrecPosition forAdUnitIdentifier:(NSString *)adUnitIdentifier;
- (void)showMRecForAdUnitIdentifier:(NSString *)adUnitIdentifier;
- (void)hideMRecForAdUnitIdentifier:(NSString *)adUnitIdentifier;
- (void)destroyMRecForAdUnitIdentifier:(NSString *)adUnitIdentifier;

@end

NS_ASSUME_NONNULL_END