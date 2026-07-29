//
//  MADefoldPlugin.m
//  MAX Defold Plugin
//
#if defined(DM_PLATFORM_IOS)
#include "applovin_private.h"
#include "applovin_callback_private.h"

#import <AppLovinSDK/AppLovinSDK.h>
#import "MADefoldPlugin.h"

typedef NS_ENUM(NSInteger, MADefoldPluginState)
{
    MADefoldPluginStateNew,
    MADefoldPluginStateInitializing,
    MADefoldPluginStateReady,
    MADefoldPluginStateDestroyed
};

static void MARunOnMainQueue(dispatch_block_t block)
{
    if ( [NSThread isMainThread] )
    {
        block();
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

static void MARunSynchronouslyOnMainQueue(dispatch_block_t block)
{
    if ( [NSThread isMainThread] )
    {
        block();
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

static MAAdFormat *MADeviceSpecificAdViewAdFormat()
{
    __block MAAdFormat *adFormat = nil;
    MARunSynchronouslyOnMainQueue(^{
        adFormat = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad ? MAAdFormat.leader : MAAdFormat.banner;
    });
    return adFormat;
}

static MAAdFormat *MAMRecAdViewAdFormat()
{
    __block MAAdFormat *adFormat = nil;
    MARunSynchronouslyOnMainQueue(^{
        adFormat = MAAdFormat.mrec;
    });
    return adFormat;
}

static UIColor * _Nullable MAColorFromHexString(NSString *hexString)
{
    NSString *value = [[hexString stringByTrimmingCharactersInSet: NSCharacterSet.whitespaceAndNewlineCharacterSet]
                       stringByReplacingOccurrencesOfString: @"#" withString: @""];
    NSUInteger length = value.length;
    if ( length != 3 && length != 4 && length != 6 && length != 8 )
    {
        return nil;
    }

    unsigned long long rawValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString: value];
    if ( ![scanner scanHexLongLong: &rawValue] || !scanner.isAtEnd )
    {
        return nil;
    }

    CGFloat alpha = 1.0;
    CGFloat red = 0.0;
    CGFloat green = 0.0;
    CGFloat blue = 0.0;
    if ( length == 3 || length == 4 )
    {
        NSUInteger shift = length == 4 ? 12 : 8;
        if ( length == 4 )
        {
            alpha = ((rawValue >> shift) & 0xF) / 15.0;
            shift -= 4;
        }
        red = ((rawValue >> shift) & 0xF) / 15.0;
        green = ((rawValue >> (shift - 4)) & 0xF) / 15.0;
        blue = (rawValue & 0xF) / 15.0;
    }
    else
    {
        NSUInteger shift = length == 8 ? 24 : 16;
        if ( length == 8 )
        {
            alpha = ((rawValue >> shift) & 0xFF) / 255.0;
            shift -= 8;
        }
        red = ((rawValue >> shift) & 0xFF) / 255.0;
        green = ((rawValue >> (shift - 8)) & 0xFF) / 255.0;
        blue = (rawValue & 0xFF) / 255.0;
    }

    return [UIColor colorWithRed: red green: green blue: blue alpha: alpha];
}

@class MAAdViewDelegateProxy;

@interface MADefoldPlugin()<MAAdRevenueDelegate, MAAdDelegate, MAAdViewAdDelegate, MARewardedAdDelegate>

// Parent Fields
@property (nonatomic, strong) ALSdk *sdk;
@property (nonatomic, assign) MADefoldPluginState state;
@property (nonatomic, strong) ALSdkConfiguration *sdkConfiguration;

// Initialization-only values must be cached until the configuration is built.
@property (nonatomic, strong, nullable) NSArray<NSString *> *testDeviceIdentifiersToSet;

// Fullscreen Ad Fields
@property (nonatomic, strong) NSMutableDictionary<NSString *, MAInterstitialAd *> *interstitials;
@property (nonatomic, strong) NSMutableDictionary<NSString *, MARewardedAd *> *rewardedAds;

// Banner Fields
@property (nonatomic, strong) NSMutableDictionary<NSString *, MAAdView *> *adViews;
@property (nonatomic, strong) NSMutableDictionary<NSString *, MAAdFormat *> *adViewAdFormats;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *adViewPositions;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *adViewPlacements;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, id> *> *adViewExtraParameters;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *adViewAutoRefreshEnabled;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *adViewGenerations;
@property (nonatomic, strong) NSMutableDictionary<NSString *, MAAdViewDelegateProxy *> *adViewDelegateProxies;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<NSLayoutConstraint *> *> *adViewConstraints;
@property (nonatomic, strong) NSMutableArray<NSString *> *adUnitIdentifiersToShowAfterCreate;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIView *> *safeAreaBackgroundViews;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIColor *> *publisherBannerBackgroundColors;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<NSLayoutConstraint *> *> *safeAreaBackgroundConstraints;
@property (nonatomic, assign) NSUInteger nextAdViewGeneration;

@property (nonatomic, strong) UIView *defoldMainView;

- (BOOL)isCurrentAdViewDelegateProxy:(MAAdViewDelegateProxy *)proxy;

@end

@interface MAAdViewDelegateProxy : NSObject<MAAdRevenueDelegate, MAAdViewAdDelegate>

@property (nonatomic, weak, nullable) MADefoldPlugin *plugin;
@property (nonatomic, weak, nullable) MAAdView *adView;
@property (nonatomic, copy) NSString *adUnitIdentifier;
@property (nonatomic, assign) NSUInteger generation;

- (instancetype)initWithPlugin:(MADefoldPlugin *)plugin
                        adView:(MAAdView *)adView
              adUnitIdentifier:(NSString *)adUnitIdentifier
                    generation:(NSUInteger)generation;
- (void)invalidate;

@end

@implementation MAAdViewDelegateProxy

- (instancetype)initWithPlugin:(MADefoldPlugin *)plugin
                        adView:(MAAdView *)adView
              adUnitIdentifier:(NSString *)adUnitIdentifier
                    generation:(NSUInteger)generation
{
    self = [super init];
    if ( self )
    {
        self.plugin = plugin;
        self.adView = adView;
        self.adUnitIdentifier = adUnitIdentifier;
        self.generation = generation;
    }
    return self;
}

- (void)withCurrentPlugin:(void (^)(MADefoldPlugin *plugin))block
{
    MARunOnMainQueue(^{
        MADefoldPlugin *plugin = self.plugin;
        if ( plugin && [plugin isCurrentAdViewDelegateProxy: self] )
        {
            block(plugin);
        }
    });
}

- (void)invalidate
{
    self.plugin = nil;
    self.adView = nil;
}

- (void)didLoadAd:(MAAd *)ad
{
    [self withCurrentPlugin:^(MADefoldPlugin *plugin) {
        [plugin didLoadAd: ad];
    }];
}

- (void)didFailToLoadAdForAdUnitIdentifier:(NSString *)adUnitIdentifier withError:(MAError *)error
{
    [self withCurrentPlugin:^(MADefoldPlugin *plugin) {
        [plugin didFailToLoadAdForAdUnitIdentifier: adUnitIdentifier withError: error];
    }];
}

- (void)didDisplayAd:(MAAd *)ad
{
    [self withCurrentPlugin:^(MADefoldPlugin *plugin) {
        [plugin didDisplayAd: ad];
    }];
}

- (void)didHideAd:(MAAd *)ad
{
    [self withCurrentPlugin:^(MADefoldPlugin *plugin) {
        [plugin didHideAd: ad];
    }];
}

- (void)didClickAd:(MAAd *)ad
{
    [self withCurrentPlugin:^(MADefoldPlugin *plugin) {
        [plugin didClickAd: ad];
    }];
}

- (void)didFailToDisplayAd:(MAAd *)ad withError:(MAError *)error
{
    [self withCurrentPlugin:^(MADefoldPlugin *plugin) {
        [plugin didFailToDisplayAd: ad withError: error];
    }];
}

- (void)didExpandAd:(MAAd *)ad
{
    [self withCurrentPlugin:^(MADefoldPlugin *plugin) {
        [plugin didExpandAd: ad];
    }];
}

- (void)didCollapseAd:(MAAd *)ad
{
    [self withCurrentPlugin:^(MADefoldPlugin *plugin) {
        [plugin didCollapseAd: ad];
    }];
}

- (void)didPayRevenueForAd:(MAAd *)ad
{
    [self withCurrentPlugin:^(MADefoldPlugin *plugin) {
        [plugin didPayRevenueForAd: ad];
    }];
}

@end

@implementation MADefoldPlugin
static NSString *const SDK_TAG = @"AppLovinSdk";
static NSString *const TAG = @"MADefoldPlugin";

#pragma mark - Initialization

- (instancetype)initWithView:(UIView *)mainView
{
    self = [super init];
    if ( self )
    {
        self.state = MADefoldPluginStateNew;
        self.interstitials = [NSMutableDictionary dictionaryWithCapacity: 2];
        self.rewardedAds = [NSMutableDictionary dictionaryWithCapacity: 2];
        self.adViews = [NSMutableDictionary dictionaryWithCapacity: 2];
        self.adViewAdFormats = [NSMutableDictionary dictionaryWithCapacity: 2];
        self.adViewPositions = [NSMutableDictionary dictionaryWithCapacity: 2];
        self.adViewPlacements = [NSMutableDictionary dictionaryWithCapacity: 2];
        self.adViewExtraParameters = [NSMutableDictionary dictionaryWithCapacity: 2];
        self.adViewAutoRefreshEnabled = [NSMutableDictionary dictionaryWithCapacity: 2];
        self.adViewGenerations = [NSMutableDictionary dictionaryWithCapacity: 2];
        self.adViewDelegateProxies = [NSMutableDictionary dictionaryWithCapacity: 2];
        self.adViewConstraints = [NSMutableDictionary dictionaryWithCapacity: 2];
        self.adUnitIdentifiersToShowAfterCreate = [NSMutableArray arrayWithCapacity: 2];
        self.safeAreaBackgroundViews = [NSMutableDictionary dictionaryWithCapacity: 2];
        self.publisherBannerBackgroundColors = [NSMutableDictionary dictionaryWithCapacity: 2];
        self.safeAreaBackgroundConstraints = [NSMutableDictionary dictionaryWithCapacity: 2];
        self.defoldMainView = mainView;

        MARunSynchronouslyOnMainQueue(^{
            self.sdk = [ALSdk shared];
        });
    }
    return self;
}

- (BOOL)isInitialized
{
    __block BOOL initialized = NO;
    MARunSynchronouslyOnMainQueue(^{
        initialized = self.state == MADefoldPluginStateReady;
    });
    return initialized;
}

- (void)initialize:(NSString *)pluginVersion sdkKey:(NSString *)sdkKey
{
    MARunSynchronouslyOnMainQueue(^{
        if ( self.state == MADefoldPluginStateDestroyed )
        {
            [self log: @"Ignoring SDK initialization after plugin destruction"];
            return;
        }

        if ( self.state == MADefoldPluginStateInitializing )
        {
            [self log: @"SDK initialization is already in progress"];
            return;
        }

        if ( self.state == MADefoldPluginStateReady )
        {
            [self sendDefoldEventWithName: @"OnSdkInitializedEvent" parameters: [self initializationMessage]];
            return;
        }

        NSString *sdkKeyToUse = sdkKey;
        if ( sdkKeyToUse.length == 0 )
        {
            id configuredSdkKey = [NSBundle mainBundle].infoDictionary[@"AppLovinSdkKey"];
            if ( [configuredSdkKey isKindOfClass: NSString.class] )
            {
                sdkKeyToUse = configuredSdkKey;
            }
        }

        if ( sdkKeyToUse.length == 0 )
        {
            [self log: @"Unable to initialize AppLovin SDK - no SDK key provided and not found in Info.plist"];
            return;
        }

        self.state = MADefoldPluginStateInitializing;
        [self log: @"Initializing AppLovin MAX Defold v%@...", pluginVersion];

        NSString *pluginVersionToUse = [@"Defold-" stringByAppendingString: pluginVersion];
        NSArray<NSString *> *testDeviceIdentifiers = [self.testDeviceIdentifiersToSet copy];
        ALSdkInitializationConfiguration *initializationConfiguration =
            [ALSdkInitializationConfiguration configurationWithSdkKey: sdkKeyToUse
                                                          builderBlock:^(ALSdkInitializationConfigurationBuilder *builder) {
                builder.mediationProvider = ALMediationProviderMAX;
                builder.pluginVersion = pluginVersionToUse;
                builder.exceptionHandlerEnabled = YES;
                if ( testDeviceIdentifiers.count > 0 )
                {
                    builder.testDeviceAdvertisingIdentifiers = testDeviceIdentifiers;
                }
            }];

        self.testDeviceIdentifiersToSet = nil;
        [self.sdk initializeWithConfiguration: initializationConfiguration
                           completionHandler:^(ALSdkConfiguration *configuration) {
            MARunOnMainQueue(^{
                if ( self.state == MADefoldPluginStateDestroyed )
                {
                    return;
                }

                [self log: @"SDK initialized"];
                self.sdkConfiguration = configuration;
                self.state = MADefoldPluginStateReady;
                [self sendDefoldEventWithName: @"OnSdkInitializedEvent" parameters: [self initializationMessage]];
            });
        }];
    });
}

- (void)destroy
{
    MARunSynchronouslyOnMainQueue(^{
        if ( self.state == MADefoldPluginStateDestroyed )
        {
            return;
        }

        self.state = MADefoldPluginStateDestroyed;

        for ( MAInterstitialAd *interstitial in self.interstitials.allValues )
        {
            if ( interstitial.delegate == self )
            {
                interstitial.delegate = nil;
            }
            if ( interstitial.revenueDelegate == self )
            {
                interstitial.revenueDelegate = nil;
            }
        }
        [self.interstitials removeAllObjects];

        for ( MARewardedAd *rewardedAd in self.rewardedAds.allValues )
        {
            if ( rewardedAd.delegate == self )
            {
                rewardedAd.delegate = nil;
            }
            if ( rewardedAd.revenueDelegate == self )
            {
                rewardedAd.revenueDelegate = nil;
            }
        }
        [self.rewardedAds removeAllObjects];

        for ( NSString *adUnitIdentifier in self.adViews )
        {
            MAAdView *adView = self.adViews[adUnitIdentifier];
            MAAdViewDelegateProxy *proxy = self.adViewDelegateProxies[adUnitIdentifier];
            [adView stopAutoRefresh];
            [proxy invalidate];
            if ( adView.delegate == proxy )
            {
                adView.delegate = nil;
            }
            if ( adView.revenueDelegate == proxy )
            {
                adView.revenueDelegate = nil;
            }
            [adView removeFromSuperview];
        }

        for ( NSArray<NSLayoutConstraint *> *constraints in self.adViewConstraints.allValues )
        {
            [NSLayoutConstraint deactivateConstraints: constraints];
        }
        for ( NSArray<NSLayoutConstraint *> *constraints in self.safeAreaBackgroundConstraints.allValues )
        {
            [NSLayoutConstraint deactivateConstraints: constraints];
        }
        for ( UIView *safeAreaBackground in self.safeAreaBackgroundViews.allValues )
        {
            [safeAreaBackground removeFromSuperview];
        }

        [self.adViews removeAllObjects];
        [self.adViewAdFormats removeAllObjects];
        [self.adViewPositions removeAllObjects];
        [self.adViewPlacements removeAllObjects];
        [self.adViewExtraParameters removeAllObjects];
        [self.adViewAutoRefreshEnabled removeAllObjects];
        [self.adViewGenerations removeAllObjects];
        [self.adViewDelegateProxies removeAllObjects];
        [self.adViewConstraints removeAllObjects];
        [self.adUnitIdentifiersToShowAfterCreate removeAllObjects];
        [self.safeAreaBackgroundViews removeAllObjects];
        [self.publisherBannerBackgroundColors removeAllObjects];
        [self.safeAreaBackgroundConstraints removeAllObjects];

        self.defoldMainView = nil;
        self.sdkConfiguration = nil;
    });
}

- (NSDictionary<NSString *, id> *)initializationMessage
{
    NSMutableDictionary<NSString *, id> *message = [NSMutableDictionary dictionaryWithCapacity: 4];
    
    if ( self.sdkConfiguration )
    {
        message[@"countryCode"] = self.sdkConfiguration.countryCode ?: @"";
        message[@"appTrackingStatus"] = @(self.sdkConfiguration.appTrackingTransparencyStatus);
        message[@"consentFlowUserGeography"] = @(self.sdkConfiguration.consentFlowUserGeography);
        message[@"isTestModeEnabled"] = @(self.sdkConfiguration.isTestModeEnabled);
    }
    
    return message;
}

#pragma mark - Privacy

- (void)setHasUserConsent:(BOOL)hasUserConsent
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateDestroyed )
        {
            [ALPrivacySettings setHasUserConsent: hasUserConsent];
        }
    });
}

- (BOOL)hasUserConsent
{
    __block BOOL hasUserConsent = NO;
    MARunSynchronouslyOnMainQueue(^{
        if ( self.state != MADefoldPluginStateDestroyed )
        {
            hasUserConsent = [ALPrivacySettings hasUserConsent];
        }
    });
    return hasUserConsent;
}

- (void)setDoNotSell:(BOOL)doNotSell
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateDestroyed )
        {
            [ALPrivacySettings setDoNotSell: doNotSell];
        }
    });
}

- (BOOL)isDoNotSell
{
    __block BOOL doNotSell = NO;
    MARunSynchronouslyOnMainQueue(^{
        if ( self.state != MADefoldPluginStateDestroyed )
        {
            doNotSell = [ALPrivacySettings isDoNotSell];
        }
    });
    return doNotSell;
}

#pragma mark - Terms and Privacy Policy Flow

- (void)setTermsAndPrivacyPolicyFlowEnabled:(BOOL)enabled
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateDestroyed )
        {
            self.sdk.settings.termsAndPrivacyPolicyFlowSettings.enabled = enabled;
        }
    });
}

- (void)setPrivacyPolicyURL:(NSString *)urlString
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateDestroyed )
        {
            self.sdk.settings.termsAndPrivacyPolicyFlowSettings.privacyPolicyURL = [NSURL URLWithString: urlString];
        }
    });
}

- (void)setTermsOfServiceURL:(NSString *)urlString
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateDestroyed )
        {
            self.sdk.settings.termsAndPrivacyPolicyFlowSettings.termsOfServiceURL = [NSURL URLWithString: urlString];
        }
    });
}

- (void)setConsentFlowDebugUserGeography:(NSString *)userGeography
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateDestroyed )
        {
            self.sdk.settings.termsAndPrivacyPolicyFlowSettings.debugUserGeography = [self toAppLovinConsentFlowUserGeography: userGeography];
        }
    });
}

- (void)showCMPForExistingUser
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        [self.sdk.cmpService showCMPForExistingUserWithCompletion:^(ALCMPError * _Nullable error) {
            MARunOnMainQueue(^{
                if ( self.state == MADefoldPluginStateDestroyed ) return;

                NSDictionary <NSString *, id> *parameters = @{};
                if ( error )
                {
                    parameters = @{@"code" : @(error.code),
                                   @"message" : error.message ?: @"",
                                   @"cmpCode" : @(error.cmpCode),
                                   @"cmpMessage" : error.cmpMessage ?: @""};
                }

                [self sendDefoldEventWithName: @"OnCmpCompletedEvent" parameters: parameters];
            });
        }];
    });
}

- (BOOL)hasSupportedCMP
{
    __block BOOL hasSupportedCMP = NO;
    MARunSynchronouslyOnMainQueue(^{
        if ( self.state == MADefoldPluginStateReady )
        {
            hasSupportedCMP = [self.sdk.cmpService hasSupportedCMP];
        }
    });
    return hasSupportedCMP;
}

#pragma mark - General

- (BOOL)isTablet
{
    __block BOOL tablet = NO;
    MARunSynchronouslyOnMainQueue(^{
        tablet = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
    });
    return tablet;
}

- (void)showMediationDebugger
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady )
        {
            [self log: @"Failed to show mediation debugger - initialize the AppLovin MAX Defold plugin first"];
            return;
        }

        [self.sdk showMediationDebugger];
    });
}

- (void)setUserId:(NSString *)userId
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateDestroyed )
        {
            self.sdk.settings.userIdentifier = userId;
        }
    });
}

- (void)setMuted:(BOOL)muted
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateDestroyed )
        {
            self.sdk.settings.muted = muted;
        }
    });
}

- (BOOL)isMuted
{
    __block BOOL muted = NO;
    MARunSynchronouslyOnMainQueue(^{
        if ( self.state != MADefoldPluginStateDestroyed )
        {
            muted = self.sdk.settings.muted;
        }
    });
    return muted;
}

- (void)setVerboseLoggingEnabled:(BOOL)enabled
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateDestroyed )
        {
            self.sdk.settings.verboseLoggingEnabled = enabled;
        }
    });
}

- (BOOL)isVerboseLoggingEnabled
{
    __block BOOL verboseLoggingEnabled = NO;
    MARunSynchronouslyOnMainQueue(^{
        if ( self.state != MADefoldPluginStateDestroyed )
        {
            verboseLoggingEnabled = self.sdk.settings.isVerboseLoggingEnabled;
        }
    });
    return verboseLoggingEnabled;
}

- (void)setCreativeDebuggerEnabled:(BOOL)enabled
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateDestroyed )
        {
            self.sdk.settings.creativeDebuggerEnabled = enabled;
        }
    });
}

- (void)setTestDeviceAdvertisingIds:(NSArray<NSString *> *)testDeviceAdvertisingIds
{
    MARunOnMainQueue(^{
        if ( self.state == MADefoldPluginStateNew )
        {
            self.testDeviceIdentifiersToSet = [testDeviceAdvertisingIds copy];
        }
        else if ( self.state != MADefoldPluginStateDestroyed )
        {
            [self log: @"Test device advertising identifiers must be set before SDK initialization"];
        }
    });
}

#pragma mark - Event Tracking

- (void)trackEvent:(NSString *)event parameters:(NSDictionary<NSString *, id> *)parameters
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady )
        {
            return;
        }

        if ( event.length == 0 )
        {
            [self log: @"Ignoring custom event with an empty event name"];
            return;
        }

        @try
        {
            [self.sdk.eventService trackEvent: event parameters: parameters];
        }
        @catch ( NSException *exception )
        {
            [self log: @"Unable to track custom event \"%@\": %@: %@",
                       event, exception.name, exception.reason ?: @""];
        }
    });
}

#pragma mark - Interstitials

- (void)loadInterstitialForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MAInterstitialAd *interstitial = [self retrieveInterstitialForAdUnitIdentifier: adUnitIdentifier];
        [interstitial loadAd];
    });
}

- (BOOL)isInterstitialReadyForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    __block BOOL ready = NO;
    MARunSynchronouslyOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MAInterstitialAd *interstitial = [self retrieveInterstitialForAdUnitIdentifier: adUnitIdentifier];
        ready = interstitial.isReady;
    });
    return ready;
}

- (void)showInterstitialForAdUnitIdentifier:(NSString *)adUnitIdentifier placement:(NSString *)placement
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MAInterstitialAd *interstitial = [self retrieveInterstitialForAdUnitIdentifier: adUnitIdentifier];
        [interstitial showAdForPlacement: placement];
    });
}

- (void)setInterstitialExtraParameterForAdUnitIdentifier:(NSString *)adUnitIdentifier key:(NSString *)key value:(NSString *)value
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MAInterstitialAd *interstitial = [self retrieveInterstitialForAdUnitIdentifier: adUnitIdentifier];
        [interstitial setExtraParameterForKey: key value: value];
    });
}

#pragma mark - Rewarded

- (void)loadRewardedAdForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MARewardedAd *rewardedAd = [self retrieveRewardedAdForAdUnitIdentifier: adUnitIdentifier];
        [rewardedAd loadAd];
    });
}

- (BOOL)isRewardedAdReadyForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    __block BOOL ready = NO;
    MARunSynchronouslyOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MARewardedAd *rewardedAd = [self retrieveRewardedAdForAdUnitIdentifier: adUnitIdentifier];
        ready = rewardedAd.isReady;
    });
    return ready;
}

- (void)showRewardedAdForAdUnitIdentifier:(NSString *)adUnitIdentifier placement:(NSString *)placement
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MARewardedAd *rewardedAd = [self retrieveRewardedAdForAdUnitIdentifier: adUnitIdentifier];
        [rewardedAd showAdForPlacement: placement];
    });
}

- (void)setRewardedAdExtraParameterForAdUnitIdentifier:(NSString *)adUnitIdentifier key:(NSString *)key value:(nullable NSString *)value
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MARewardedAd *rewardedAd = [self retrieveRewardedAdForAdUnitIdentifier: adUnitIdentifier];
        [rewardedAd setExtraParameterForKey: key value: value];
    });
}

#pragma mark - Banners

- (void)createBannerForAdUnitIdentifier:(NSString *)adUnitIdentifier atPosition:(NSString *)bannerPosition
{
    [self createAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: MADeviceSpecificAdViewAdFormat() atPosition: bannerPosition];
}

- (void)setBannerBackgroundColorForAdUnitIdentifier:(NSString *)adUnitIdentifier hexColorCode:(NSString *)hexColorCode
{
    [self setAdViewBackgroundColorForAdUnitIdentifier: adUnitIdentifier adFormat: MADeviceSpecificAdViewAdFormat() hexColorCode: hexColorCode];
}

- (void)setBannerPlacement:(nullable NSString *)placement forAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    [self setAdViewPlacement: placement forAdUnitIdentifier: adUnitIdentifier adFormat: MADeviceSpecificAdViewAdFormat()];
}

- (void)setBannerExtraParameterForAdUnitIdentifier:(NSString *)adUnitIdentifier key:(NSString *)key value:(nullable NSString *)value
{
    [self setAdViewExtraParameterForAdUnitIdentifier: adUnitIdentifier adFormat: MADeviceSpecificAdViewAdFormat() key: key value: value];
}

- (void)updateBannerPosition:(NSString *)bannerPosition forAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    [self updateAdViewPosition: bannerPosition forAdUnitIdentifier: adUnitIdentifier adFormat: MADeviceSpecificAdViewAdFormat()];
}

- (void)startBannerAutoRefreshForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    [self startAutoRefresh: adUnitIdentifier adFormat: MADeviceSpecificAdViewAdFormat()];
}

- (void)stopBannerAutoRefreshForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    [self stopAutoRefresh: adUnitIdentifier adFormat: MADeviceSpecificAdViewAdFormat()];
}

- (void)showBannerForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    [self showAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: MADeviceSpecificAdViewAdFormat()];
}

- (void)hideBannerForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    [self hideAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: MADeviceSpecificAdViewAdFormat()];
}

- (void)destroyBannerForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    [self destroyAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: MADeviceSpecificAdViewAdFormat()];
}

#pragma mark - MRECs

- (void)createMRecForAdUnitIdentifier:(NSString *)adUnitIdentifier atPosition:(NSString *)mrecPosition
{
    [self createAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: MAMRecAdViewAdFormat() atPosition: mrecPosition];
}

- (void)setMRecPlacement:(nullable NSString *)placement forAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    [self setAdViewPlacement: placement forAdUnitIdentifier: adUnitIdentifier adFormat: MAMRecAdViewAdFormat()];
}

- (void)setMRecExtraParameterForAdUnitIdentifier:(NSString *)adUnitIdentifier key:(NSString *)key value:(nullable NSString *)value
{
    [self setAdViewExtraParameterForAdUnitIdentifier: adUnitIdentifier adFormat: MAMRecAdViewAdFormat() key: key value: value];
}

- (void)updateMRecPosition:(NSString *)mrecPosition forAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    [self updateAdViewPosition: mrecPosition forAdUnitIdentifier: adUnitIdentifier adFormat: MAMRecAdViewAdFormat()];
}

- (void)startMRecAutoRefreshForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    [self startAutoRefresh: adUnitIdentifier adFormat: MAMRecAdViewAdFormat()];
}

- (void)stopMRecAutoRefreshForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    [self stopAutoRefresh: adUnitIdentifier adFormat: MAMRecAdViewAdFormat()];
}

- (void)showMRecForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    [self showAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: MAMRecAdViewAdFormat()];
}

- (void)hideMRecForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    [self hideAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: MAMRecAdViewAdFormat()];
}

- (void)destroyMRecForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    [self destroyAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: MAMRecAdViewAdFormat()];
}

#pragma mark - Ad Callbacks

- (void)didLoadAd:(MAAd *)ad
{
    if ( ![NSThread isMainThread] )
    {
        MARunOnMainQueue(^{ [self didLoadAd: ad]; });
        return;
    }
    if ( self.state == MADefoldPluginStateDestroyed ) return;

    NSString *name;
    MAAdFormat *adFormat = ad.format;
    if ( [adFormat isAdViewAd] )
    {
        MAAdView *adView = [self retrieveAdViewForAdUnitIdentifier: ad.adUnitIdentifier adFormat: adFormat];
        if ( !adView )
        {
            return;
        }

        MAAdFormat *effectiveAdFormat = [self effectiveAdFormatForAdUnitIdentifier: ad.adUnitIdentifier
                                                                 requestedFormat: adFormat];
        // An ad is now being shown, enable user interaction.
        adView.userInteractionEnabled = YES;
        
        name = ( MAAdFormat.mrec == effectiveAdFormat ) ? @"OnMRecAdLoadedEvent" : @"OnBannerAdLoadedEvent";
        [self positionAdViewForAdUnitIdentifier: ad.adUnitIdentifier adFormat: effectiveAdFormat];
        
        // Visibility pauses refresh temporarily; publisher intent remains cached.
        if ( adView.hidden || ![self isAutoRefreshEnabledForAdUnitIdentifier: ad.adUnitIdentifier] )
        {
            [adView stopAutoRefresh];
        }
    }
    else if ( MAAdFormat.interstitial == adFormat )
    {
        name = @"OnInterstitialAdLoadedEvent";
    }
    else if ( MAAdFormat.rewarded == adFormat )
    {
        name = @"OnRewardedAdLoadedEvent";
    }
    else
    {
        [self logInvalidAdFormat: adFormat];
        return;
    }
    
    [self sendDefoldEventWithName: name parameters: [self adInfoForAd: ad]];
}

- (void)didFailToLoadAdForAdUnitIdentifier:(NSString *)adUnitIdentifier withError:(MAError *)error
{
    if ( ![NSThread isMainThread] )
    {
        MARunOnMainQueue(^{ [self didFailToLoadAdForAdUnitIdentifier: adUnitIdentifier withError: error]; });
        return;
    }
    if ( self.state == MADefoldPluginStateDestroyed ) return;

    if ( !adUnitIdentifier )
    {
        [self log: @"adUnitIdentifier cannot be nil from %@", [NSThread callStackSymbols]];
        return;
    }
    
    NSString *name;
    if ( self.adViews[adUnitIdentifier] )
    {
        MAAdFormat *adFormat = self.adViewAdFormats[adUnitIdentifier];
        name = ( adFormat && MAAdFormat.mrec == adFormat ) ? @"OnMRecAdLoadFailedEvent" : @"OnBannerAdLoadFailedEvent";
    }
    else if ( self.interstitials[adUnitIdentifier] )
    {
        name = @"OnInterstitialAdLoadFailedEvent";
    }
    else if ( self.rewardedAds[adUnitIdentifier] )
    {
        name = @"OnRewardedAdLoadFailedEvent";
    }
    else
    {
        [self log: @"invalid adUnitId from %@", [NSThread callStackSymbols]];
        return;
    }
    
    NSMutableDictionary *parameters = [[self loadErrorInfoForError: error] mutableCopy];
    parameters[@"adUnitIdentifier"] = adUnitIdentifier;
    
    [self sendDefoldEventWithName: name parameters: parameters];
}

- (void)didClickAd:(MAAd *)ad
{
    if ( ![NSThread isMainThread] )
    {
        MARunOnMainQueue(^{ [self didClickAd: ad]; });
        return;
    }
    if ( self.state == MADefoldPluginStateDestroyed ) return;

    NSString *name;
    MAAdFormat *adFormat = ad.format;
    if ( MAAdFormat.banner == adFormat || MAAdFormat.leader == adFormat )
    {
        name = @"OnBannerAdClickedEvent";
    }
    else if ( MAAdFormat.mrec == adFormat )
    {
        name = @"OnMRecAdClickedEvent";
    }
    else if ( MAAdFormat.interstitial == adFormat )
    {
        name = @"OnInterstitialAdClickedEvent";
    }
    else if ( MAAdFormat.rewarded == adFormat )
    {
        name = @"OnRewardedAdClickedEvent";
    }
    else
    {
        [self logInvalidAdFormat: adFormat];
        return;
    }
    
    [self sendDefoldEventWithName: name parameters: [self adInfoForAd: ad]];
}

- (void)didDisplayAd:(MAAd *)ad
{
    if ( ![NSThread isMainThread] )
    {
        MARunOnMainQueue(^{ [self didDisplayAd: ad]; });
        return;
    }
    if ( self.state == MADefoldPluginStateDestroyed ) return;

    // BMLs do not support [DISPLAY] events
    MAAdFormat *adFormat = ad.format;
    if ( adFormat != MAAdFormat.interstitial && adFormat != MAAdFormat.rewarded ) return;
    
    NSString *name;
    if ( MAAdFormat.interstitial == adFormat )
    {
        name = @"OnInterstitialAdDisplayedEvent";
    }
    else // REWARDED
    {
        name = @"OnRewardedAdDisplayedEvent";
    }
    
    [self sendDefoldEventWithName: name parameters: [self adInfoForAd: ad]];
}

- (void)didFailToDisplayAd:(MAAd *)ad withError:(MAError *)error
{
    if ( ![NSThread isMainThread] )
    {
        MARunOnMainQueue(^{ [self didFailToDisplayAd: ad withError: error]; });
        return;
    }
    if ( self.state == MADefoldPluginStateDestroyed ) return;

    // BMLs do not support [DISPLAY] events
    MAAdFormat *adFormat = ad.format;
    if ( adFormat != MAAdFormat.interstitial && adFormat != MAAdFormat.rewarded ) return;
    
    NSString *name;
    if ( MAAdFormat.interstitial == adFormat )
    {
        name = @"OnInterstitialAdDisplayFailedEvent";
    }
    else // REWARDED
    {
        name = @"OnRewardedAdDisplayFailedEvent";
    }
    
    NSMutableDictionary *parameters = [[self adInfoForAd: ad] mutableCopy];
    [parameters addEntriesFromDictionary: [self displayErrorInfoForError: error]];
    
    [self sendDefoldEventWithName: name parameters: parameters];
}

- (void)didHideAd:(MAAd *)ad
{
    if ( ![NSThread isMainThread] )
    {
        MARunOnMainQueue(^{ [self didHideAd: ad]; });
        return;
    }
    if ( self.state == MADefoldPluginStateDestroyed ) return;

    // BMLs do not support [HIDDEN] events
    MAAdFormat *adFormat = ad.format;
    if ( adFormat != MAAdFormat.interstitial && adFormat != MAAdFormat.rewarded ) return;
    
    NSString *name;
    if ( MAAdFormat.interstitial == adFormat )
    {
        name = @"OnInterstitialAdHiddenEvent";
    }
    else // REWARDED
    {
        name = @"OnRewardedAdHiddenEvent";
    }
    
    [self sendDefoldEventWithName: name parameters: [self adInfoForAd: ad]];
}

- (void)didExpandAd:(MAAd *)ad
{
    if ( ![NSThread isMainThread] )
    {
        MARunOnMainQueue(^{ [self didExpandAd: ad]; });
        return;
    }
    if ( self.state == MADefoldPluginStateDestroyed ) return;

    MAAdFormat *adFormat = ad.format;
    if ( ![adFormat isAdViewAd] )
    {
        [self logInvalidAdFormat: adFormat];
        return;
    }
    
    [self sendDefoldEventWithName: ( MAAdFormat.mrec == adFormat ) ? @"OnMRecAdExpandedEvent" : @"OnBannerAdExpandedEvent"
                       parameters: [self adInfoForAd: ad]];
}

- (void)didCollapseAd:(MAAd *)ad
{
    if ( ![NSThread isMainThread] )
    {
        MARunOnMainQueue(^{ [self didCollapseAd: ad]; });
        return;
    }
    if ( self.state == MADefoldPluginStateDestroyed ) return;

    MAAdFormat *adFormat = ad.format;
    if ( ![adFormat isAdViewAd] )
    {
        [self logInvalidAdFormat: adFormat];
        return;
    }
    
    [self sendDefoldEventWithName: ( MAAdFormat.mrec == adFormat ) ? @"OnMRecAdCollapsedEvent" : @"OnBannerAdCollapsedEvent"
                       parameters: [self adInfoForAd: ad]];
}

- (void)didRewardUserForAd:(MAAd *)ad withReward:(MAReward *)reward
{
    if ( ![NSThread isMainThread] )
    {
        MARunOnMainQueue(^{ [self didRewardUserForAd: ad withReward: reward]; });
        return;
    }
    if ( self.state == MADefoldPluginStateDestroyed ) return;

    MAAdFormat *adFormat = ad.format;
    if ( adFormat != MAAdFormat.rewarded )
    {
        [self logInvalidAdFormat: adFormat];
        return;
    }
    
    NSMutableDictionary *parameters = [[self adInfoForAd: ad] mutableCopy];
    parameters[@"label"] = reward ? reward.label : @"";
    parameters[@"amount"] = reward ? @(reward.amount) : @(0);
    
    [self sendDefoldEventWithName: @"OnRewardedAdReceivedRewardEvent" parameters: parameters];
}

- (void)didPayRevenueForAd:(MAAd *)ad
{
    if ( ![NSThread isMainThread] )
    {
        MARunOnMainQueue(^{ [self didPayRevenueForAd: ad]; });
        return;
    }
    if ( self.state == MADefoldPluginStateDestroyed ) return;

    NSString *name;
    MAAdFormat *adFormat = ad.format;
    if ( MAAdFormat.banner == adFormat || MAAdFormat.leader == adFormat )
    {
        name = @"OnBannerAdRevenuePaidEvent";
    }
    else if ( MAAdFormat.mrec == adFormat )
    {
        name = @"OnMRecAdRevenuePaidEvent";
    }
    else if ( MAAdFormat.interstitial == adFormat )
    {
        name = @"OnInterstitialAdRevenuePaidEvent";
    }
    else if ( MAAdFormat.rewarded == adFormat )
    {
        name = @"OnRewardedAdRevenuePaidEvent";
    }
    else
    {
        [self logInvalidAdFormat: adFormat];
        return;
    }
    
    [self sendDefoldEventWithName: name parameters: [self adInfoForAd: ad]];
}

#pragma mark - Internal Methods

- (void)createAdViewForAdUnitIdentifier:(NSString *)adUnitIdentifier adFormat:(MAAdFormat *)adFormat atPosition:(NSString *)adViewPosition
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MAAdView *existingAdView = self.adViews[adUnitIdentifier];
        if ( existingAdView )
        {
            MAAdFormat *effectiveAdFormat = [self effectiveAdFormatForAdUnitIdentifier: adUnitIdentifier
                                                                      requestedFormat: adFormat];
            [self log: @"Updating existing %@ with ad unit identifier \"%@\" and position: \"%@\"",
                       effectiveAdFormat, adUnitIdentifier, adViewPosition];
            self.adViewPositions[adUnitIdentifier] = adViewPosition;
            [self positionAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: effectiveAdFormat];
            return;
        }

        [self log: @"Creating %@ with ad unit identifier \"%@\" and position: \"%@\"", adFormat, adUnitIdentifier, adViewPosition];

        MAAdFormat *effectiveAdFormat = [self effectiveAdFormatForAdUnitIdentifier: adUnitIdentifier
                                                                  requestedFormat: adFormat];

        // Retrieve ad view from the map
        MAAdView *adView = [self retrieveAdViewForAdUnitIdentifier: adUnitIdentifier
                                                         adFormat: effectiveAdFormat
                                                       atPosition: adViewPosition];
        adView.hidden = YES;
        
        // Position ad view immediately so if publisher sets color before ad loads, it will not be the size of the screen
        [self positionAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: effectiveAdFormat];
        [self updateSafeAreaBackgroundVisibility];

        // Defer the initial load by one main-queue turn. This preserves the
        // public create-then-configure pattern and guarantees that placement
        // and extra parameters issued immediately after create are applied
        // before the first request.
        NSNumber *generation = self.adViewGenerations[adUnitIdentifier];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( self.state != MADefoldPluginStateReady
                 || self.adViews[adUnitIdentifier] != adView
                 || ![self.adViewGenerations[adUnitIdentifier] isEqualToNumber: generation] )
            {
                return;
            }

            NSString *placement = self.adViewPlacements[adUnitIdentifier];
            if ( placement )
            {
                adView.placement = placement;
            }
            [self applyCachedExtraParametersToAdView: adView adUnitIdentifier: adUnitIdentifier];
            [adView loadAd];
        });
        
        // The publisher may have requested to show the banner before it was created. Now that the banner is created, show it.
        if ( [self.adUnitIdentifiersToShowAfterCreate containsObject: adUnitIdentifier] )
        {
            [self showAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: effectiveAdFormat];
            [self.adUnitIdentifiersToShowAfterCreate removeObject: adUnitIdentifier];
        }
    });
}

- (void)setAdViewBackgroundColorForAdUnitIdentifier:(NSString *)adUnitIdentifier adFormat:(MAAdFormat *)adFormat hexColorCode:(NSString *)hexColorCode
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MAAdFormat *effectiveAdFormat = [self effectiveAdFormatForAdUnitIdentifier: adUnitIdentifier
                                                                  requestedFormat: adFormat];
        [self log: @"Setting %@ with ad unit identifier \"%@\" to color: \"%@\"",
                   effectiveAdFormat, adUnitIdentifier, hexColorCode];
        
        // In some cases, black color may get redrawn on each frame update, resulting in an undesired flicker
        NSString *hexColorCodeToUse = [hexColorCode containsString: @"FF000000"] ? @"FF000001" : hexColorCode;
        UIColor *convertedColor = MAColorFromHexString(hexColorCodeToUse);
        if ( !convertedColor )
        {
            [self log: @"Invalid ad view color \"%@\"", hexColorCode];
            return;
        }
        
        MAAdView *view = [self retrieveAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: effectiveAdFormat];
        UIView *safeAreaBackground = self.safeAreaBackgroundViews[adUnitIdentifier];
        self.publisherBannerBackgroundColors[adUnitIdentifier] = convertedColor;
        safeAreaBackground.backgroundColor = view.backgroundColor = convertedColor;
        [self positionAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: effectiveAdFormat];
    });
}

- (void)setAdViewPlacement:(nullable NSString *)placement forAdUnitIdentifier:(NSString *)adUnitIdentifier adFormat:(MAAdFormat *)adFormat
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MAAdFormat *effectiveAdFormat = [self effectiveAdFormatForAdUnitIdentifier: adUnitIdentifier
                                                                  requestedFormat: adFormat];
        [self log: @"Setting placement \"%@\" for \"%@\" with ad unit identifier \"%@\"",
                   placement, effectiveAdFormat, adUnitIdentifier];

        if ( placement )
        {
            self.adViewPlacements[adUnitIdentifier] = placement;
        }
        else
        {
            [self.adViewPlacements removeObjectForKey: adUnitIdentifier];
        }
        
        MAAdView *adView = [self retrieveAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: effectiveAdFormat];
        adView.placement = placement;
    });
}

- (void)updateAdViewPosition:(NSString *)adViewPosition forAdUnitIdentifier:(NSString *)adUnitIdentifier adFormat:(MAAdFormat *)adFormat
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        // Check if the previous position is same as the new position. If so, no need to update the position again.
        NSString *previousPosition = self.adViewPositions[adUnitIdentifier];
        if ( !adViewPosition || [adViewPosition isEqualToString: previousPosition] ) return;
        
        MAAdFormat *effectiveAdFormat = [self effectiveAdFormatForAdUnitIdentifier: adUnitIdentifier
                                                                  requestedFormat: adFormat];
        self.adViewPositions[adUnitIdentifier] = adViewPosition;
        [self positionAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: effectiveAdFormat];
    });
}

- (void)setAdViewExtraParameterForAdUnitIdentifier:(NSString *)adUnitIdentifier adFormat:(MAAdFormat *)adFormat key:(NSString *)key value:(nullable NSString *)value
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MAAdFormat *effectiveAdFormat = [self effectiveAdFormatForAdUnitIdentifier: adUnitIdentifier
                                                                  requestedFormat: adFormat];
        NSMutableDictionary<NSString *, id> *extraParameters =
            self.adViewExtraParameters[adUnitIdentifier];
        if ( !extraParameters )
        {
            extraParameters = [NSMutableDictionary dictionary];
            self.adViewExtraParameters[adUnitIdentifier] = extraParameters;
        }
        extraParameters[key] = value ?: NSNull.null;

        BOOL isForceBannerParameter =
            [@"force_banner" caseInsensitiveCompare: key] == NSOrderedSame
            && MAAdFormat.mrec != effectiveAdFormat;
        if ( isForceBannerParameter )
        {
            effectiveAdFormat =
                value.boolValue ? MAAdFormat.banner : MADeviceSpecificAdViewAdFormat();
            self.adViewAdFormats[adUnitIdentifier] = effectiveAdFormat;
        }

        [self log: @"Setting %@ extra with key: \"%@\" value: \"%@\"", effectiveAdFormat, key, value];

        MAAdView *adView = [self retrieveAdViewForAdUnitIdentifier: adUnitIdentifier
                                                         adFormat: effectiveAdFormat];
        if ( adView )
        {
            [adView setExtraParameterForKey: key value: value];
            if ( isForceBannerParameter )
            {
                [self positionAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: effectiveAdFormat];
            }
        }
    });
}

- (void)startAutoRefresh:(NSString *)adUnitIdentifier adFormat:(MAAdFormat *)adFormat
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MAAdFormat *effectiveAdFormat = [self effectiveAdFormatForAdUnitIdentifier: adUnitIdentifier
                                                                  requestedFormat: adFormat];
        [self log: @"Starting auto refresh \"%@\" with ad unit identifier \"%@\"", effectiveAdFormat, adUnitIdentifier];
        self.adViewAutoRefreshEnabled[adUnitIdentifier] = @YES;

        MAAdView *view = [self retrieveAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: effectiveAdFormat];
        if ( !view )
        {
            [self log: @"%@ does not exist for ad unit identifier %@.", effectiveAdFormat, adUnitIdentifier];
            return;
        }

        if ( !view.hidden )
        {
            [view startAutoRefresh];
        }
    });
}

- (void)stopAutoRefresh:(NSString *)adUnitIdentifier adFormat:(MAAdFormat *)adFormat
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MAAdFormat *effectiveAdFormat = [self effectiveAdFormatForAdUnitIdentifier: adUnitIdentifier
                                                                  requestedFormat: adFormat];
        [self log: @"Stopping auto refresh \"%@\" with ad unit identifier \"%@\"", effectiveAdFormat, adUnitIdentifier];
        self.adViewAutoRefreshEnabled[adUnitIdentifier] = @NO;

        MAAdView *view = [self retrieveAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: effectiveAdFormat];
        if ( !view )
        {
            [self log: @"%@ does not exist for ad unit identifier %@.", effectiveAdFormat, adUnitIdentifier];
            return;
        }

        [view stopAutoRefresh];
    });
}

- (void)showAdViewForAdUnitIdentifier:(NSString *)adUnitIdentifier adFormat:(MAAdFormat *)adFormat
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MAAdFormat *effectiveAdFormat = [self effectiveAdFormatForAdUnitIdentifier: adUnitIdentifier
                                                                  requestedFormat: adFormat];
        [self log: @"Showing %@ with ad unit identifier \"%@\"", effectiveAdFormat, adUnitIdentifier];
        
        MAAdView *view = [self retrieveAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: effectiveAdFormat];
        if ( !view )
        {
            [self log: @"%@ does not exist for ad unit identifier %@.", effectiveAdFormat, adUnitIdentifier];
            
            // The adView has not yet been created. Store the ad unit ID, so that it can be displayed once the banner has been created.
            if ( ![self.adUnitIdentifiersToShowAfterCreate containsObject: adUnitIdentifier] )
            {
                [self.adUnitIdentifiersToShowAfterCreate addObject: adUnitIdentifier];
            }
            return;
        }
        
        view.hidden = NO;
        [self updateSafeAreaBackgroundVisibility];
        if ( [self isAutoRefreshEnabledForAdUnitIdentifier: adUnitIdentifier] )
        {
            [view startAutoRefresh];
        }
        else
        {
            [view stopAutoRefresh];
        }
    });
}

- (void)hideAdViewForAdUnitIdentifier:(NSString *)adUnitIdentifier adFormat:(MAAdFormat *)adFormat
{
    MARunOnMainQueue(^{
        if ( self.state != MADefoldPluginStateReady ) return;

        MAAdFormat *effectiveAdFormat = [self effectiveAdFormatForAdUnitIdentifier: adUnitIdentifier
                                                                  requestedFormat: adFormat];
        [self log: @"Hiding %@ with ad unit identifier \"%@\"", effectiveAdFormat, adUnitIdentifier];
        [self.adUnitIdentifiersToShowAfterCreate removeObject: adUnitIdentifier];
        
        MAAdView *view = [self retrieveAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: effectiveAdFormat];
        view.hidden = YES;
        [self updateSafeAreaBackgroundVisibility];
        [view stopAutoRefresh];
    });
}

- (void)destroyAdViewForAdUnitIdentifier:(NSString *)adUnitIdentifier adFormat:(MAAdFormat *)adFormat
{
    MARunOnMainQueue(^{
        if ( self.state == MADefoldPluginStateDestroyed ) return;

        MAAdFormat *effectiveAdFormat = [self effectiveAdFormatForAdUnitIdentifier: adUnitIdentifier
                                                                  requestedFormat: adFormat];
        [self log: @"Destroying %@ with ad unit identifier \"%@\"", effectiveAdFormat, adUnitIdentifier];
        
        MAAdView *view = [self retrieveAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: effectiveAdFormat];
        MAAdViewDelegateProxy *proxy = self.adViewDelegateProxies[adUnitIdentifier];
        [view stopAutoRefresh];
        [proxy invalidate];
        if ( view.delegate == proxy )
        {
            view.delegate = nil;
        }
        if ( view.revenueDelegate == proxy )
        {
            view.revenueDelegate = nil;
        }
        
        [view removeFromSuperview];

        NSArray<NSLayoutConstraint *> *adViewConstraints = self.adViewConstraints[adUnitIdentifier];
        if ( adViewConstraints )
        {
            [NSLayoutConstraint deactivateConstraints: adViewConstraints];
        }
        NSArray<NSLayoutConstraint *> *safeAreaConstraints =
            self.safeAreaBackgroundConstraints[adUnitIdentifier];
        if ( safeAreaConstraints )
        {
            [NSLayoutConstraint deactivateConstraints: safeAreaConstraints];
        }
        [self.safeAreaBackgroundViews[adUnitIdentifier] removeFromSuperview];
        [self.adViews removeObjectForKey: adUnitIdentifier];
        [self.adViewPositions removeObjectForKey: adUnitIdentifier];
        [self.adViewPlacements removeObjectForKey: adUnitIdentifier];
        [self.adViewExtraParameters removeObjectForKey: adUnitIdentifier];
        [self.adViewAutoRefreshEnabled removeObjectForKey: adUnitIdentifier];
        [self.adViewGenerations removeObjectForKey: adUnitIdentifier];
        [self.adViewDelegateProxies removeObjectForKey: adUnitIdentifier];
        [self.adViewAdFormats removeObjectForKey: adUnitIdentifier];
        [self.adViewConstraints removeObjectForKey: adUnitIdentifier];
        [self.safeAreaBackgroundViews removeObjectForKey: adUnitIdentifier];
        [self.publisherBannerBackgroundColors removeObjectForKey: adUnitIdentifier];
        [self.safeAreaBackgroundConstraints removeObjectForKey: adUnitIdentifier];
        [self.adUnitIdentifiersToShowAfterCreate removeObject: adUnitIdentifier];
        [self updateSafeAreaBackgroundVisibility];
    });
}

- (void)updateSafeAreaBackgroundVisibility
{
    for ( NSString *adUnitIdentifier in self.safeAreaBackgroundViews )
    {
        UIView *safeAreaBackground = self.safeAreaBackgroundViews[adUnitIdentifier];
        MAAdView *adView = self.adViews[adUnitIdentifier];
        MAAdFormat *adFormat = self.adViewAdFormats[adUnitIdentifier];
        NSString *position = self.adViewPositions[adUnitIdentifier];
        BOOL isCenteredAtScreenEdge =
            [position isEqualToString: @"top_center"] || [position isEqualToString: @"bottom_center"];
        BOOL hasActiveConstraints = self.safeAreaBackgroundConstraints[adUnitIdentifier].count > 0;
        BOOL shouldShowSafeAreaBackground =
            self.publisherBannerBackgroundColors[adUnitIdentifier]
            && adView
            && !adView.hidden
            && adFormat != MAAdFormat.mrec
            && isCenteredAtScreenEdge
            && hasActiveConstraints;
        safeAreaBackground.hidden = !shouldShowSafeAreaBackground;
    }
}

- (MAAdFormat *)effectiveAdFormatForAdUnitIdentifier:(NSString *)adUnitIdentifier
                                     requestedFormat:(MAAdFormat *)requestedFormat
{
    return self.adViewAdFormats[adUnitIdentifier] ?: requestedFormat;
}

- (BOOL)isAutoRefreshEnabledForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    NSNumber *enabled = self.adViewAutoRefreshEnabled[adUnitIdentifier];
    return !enabled || enabled.boolValue;
}

- (void)applyCachedExtraParametersToAdView:(MAAdView *)adView
                         adUnitIdentifier:(NSString *)adUnitIdentifier
{
    NSDictionary<NSString *, id> *extraParameters =
        self.adViewExtraParameters[adUnitIdentifier];
    NSArray<NSString *> *keys =
        [extraParameters.allKeys sortedArrayUsingSelector: @selector(compare:)];
    for ( NSString *key in keys )
    {
        id cachedValue = extraParameters[key];
        NSString *value = cachedValue == NSNull.null ? nil : (NSString *)cachedValue;
        [adView setExtraParameterForKey: key value: value];
    }
}

- (BOOL)isCurrentAdViewDelegateProxy:(MAAdViewDelegateProxy *)proxy
{
    if ( self.state == MADefoldPluginStateDestroyed || !proxy )
    {
        return NO;
    }

    NSString *adUnitIdentifier = proxy.adUnitIdentifier;
    return self.adViewDelegateProxies[adUnitIdentifier] == proxy
        && self.adViews[adUnitIdentifier] == proxy.adView
        && self.adViewGenerations[adUnitIdentifier].unsignedIntegerValue == proxy.generation;
}

- (void)logInvalidAdFormat:(MAAdFormat *)adFormat
{
    [self log: @"invalid ad format: %@, from %@", adFormat, [NSThread callStackSymbols]];
}

- (void)log:(NSString *)format, ...
{
    va_list valist;
    va_start(valist, format);
    NSString *message = [[NSString alloc] initWithFormat: format arguments: valist];
    va_end(valist);
    
    NSLog(@"[%@] [%@] %@", SDK_TAG, TAG, message);
}

- (MAInterstitialAd *)retrieveInterstitialForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    MAInterstitialAd *result = self.interstitials[adUnitIdentifier];
    if ( !result )
    {
        result = [[MAInterstitialAd alloc] initWithAdUnitIdentifier: adUnitIdentifier];
        result.delegate = self;
        result.revenueDelegate = self;
        
        self.interstitials[adUnitIdentifier] = result;
    }
    
    return result;
}

- (MARewardedAd *)retrieveRewardedAdForAdUnitIdentifier:(NSString *)adUnitIdentifier
{
    MARewardedAd *result = self.rewardedAds[adUnitIdentifier];
    if ( !result )
    {
        result = [MARewardedAd sharedWithAdUnitIdentifier: adUnitIdentifier];
        result.delegate = self;
        result.revenueDelegate = self;
        
        self.rewardedAds[adUnitIdentifier] = result;
    }
    
    return result;
}

- (MAAdView *)retrieveAdViewForAdUnitIdentifier:(NSString *)adUnitIdentifier adFormat:(MAAdFormat *)adFormat
{
    return [self retrieveAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: adFormat atPosition: nil];
}

- (MAAdView *)retrieveAdViewForAdUnitIdentifier:(NSString *)adUnitIdentifier adFormat:(MAAdFormat *)adFormat atPosition:(NSString *)adViewPosition
{
    MAAdView *result = self.adViews[adUnitIdentifier];
    if ( !result && adViewPosition )
    {
        result = [[MAAdView alloc] initWithAdUnitIdentifier: adUnitIdentifier adFormat: adFormat];
        result.userInteractionEnabled = NO;
        result.translatesAutoresizingMaskIntoConstraints = NO;
        [result setExtraParameterForKey: @"allow_pause_auto_refresh_immediately" value: @"true"];
        [self applyCachedExtraParametersToAdView: result adUnitIdentifier: adUnitIdentifier];

        NSString *placement = self.adViewPlacements[adUnitIdentifier];
        if ( placement )
        {
            result.placement = placement;
        }

        self.nextAdViewGeneration += 1;
        NSUInteger generation = self.nextAdViewGeneration;
        MAAdViewDelegateProxy *proxy =
            [[MAAdViewDelegateProxy alloc] initWithPlugin: self
                                                  adView: result
                                        adUnitIdentifier: adUnitIdentifier
                                              generation: generation];
        result.delegate = proxy;
        result.revenueDelegate = proxy;

        self.adViews[adUnitIdentifier] = result;
        self.adViewAdFormats[adUnitIdentifier] = adFormat;
        self.adViewPositions[adUnitIdentifier] = adViewPosition;
        self.adViewGenerations[adUnitIdentifier] = @(generation);
        self.adViewDelegateProxies[adUnitIdentifier] = proxy;
        if ( !self.adViewAutoRefreshEnabled[adUnitIdentifier] )
        {
            self.adViewAutoRefreshEnabled[adUnitIdentifier] = @YES;
        }

        UIView *safeAreaBackground = [[UIView alloc] init];
        safeAreaBackground.hidden = YES;
        safeAreaBackground.backgroundColor = UIColor.clearColor;
        safeAreaBackground.translatesAutoresizingMaskIntoConstraints = NO;
        safeAreaBackground.userInteractionEnabled = NO;
        self.safeAreaBackgroundViews[adUnitIdentifier] = safeAreaBackground;

        UIColor *publisherBackgroundColor = self.publisherBannerBackgroundColors[adUnitIdentifier];
        if ( publisherBackgroundColor )
        {
            safeAreaBackground.backgroundColor = publisherBackgroundColor;
            result.backgroundColor = publisherBackgroundColor;
        }

        [self.defoldMainView addSubview: safeAreaBackground];
        [self.defoldMainView addSubview: result];
    }
    
    return result;
}

- (void)positionAdViewForAdUnitIdentifier:(NSString *)adUnitIdentifier adFormat:(MAAdFormat *)adFormat
{
    MAAdFormat *effectiveAdFormat = [self effectiveAdFormatForAdUnitIdentifier: adUnitIdentifier
                                                              requestedFormat: adFormat];
    MAAdView *adView = [self retrieveAdViewForAdUnitIdentifier: adUnitIdentifier adFormat: effectiveAdFormat];
    NSString *adViewPosition = self.adViewPositions[adUnitIdentifier];
    
    UIView *superview = adView.superview;
    if ( !superview ) return;
    
    // Deactivate any previous constraints so that the banner can be positioned again.
    NSArray<NSLayoutConstraint *> *activeConstraints = self.adViewConstraints[adUnitIdentifier];
    [NSLayoutConstraint deactivateConstraints: activeConstraints];
    NSArray<NSLayoutConstraint *> *activeSafeAreaBackgroundConstraints =
        self.safeAreaBackgroundConstraints[adUnitIdentifier];
    [NSLayoutConstraint deactivateConstraints: activeSafeAreaBackgroundConstraints];
    adView.transform = CGAffineTransformIdentity;

    UIView *safeAreaBackground = self.safeAreaBackgroundViews[adUnitIdentifier];
    if ( safeAreaBackground.superview != superview )
    {
        [safeAreaBackground removeFromSuperview];
        [superview insertSubview: safeAreaBackground belowSubview: adView];
    }
    else
    {
        [superview insertSubview: safeAreaBackground belowSubview: adView];
    }

    safeAreaBackground.hidden = YES;

    CGSize adViewSize = [[self class] adViewSizeForAdFormat: effectiveAdFormat];
    
    // All positions have constant height
    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithObject: [adView.heightAnchor constraintEqualToConstant: adViewSize.height]];
    NSMutableArray<NSLayoutConstraint *> *safeAreaConstraints = [NSMutableArray array];
    
    UILayoutGuide *layoutGuide = superview.safeAreaLayoutGuide;
    
    // If top of bottom center, stretch width of screen
    if ( [adViewPosition isEqual: @"top_center"] || [adViewPosition isEqual: @"bottom_center"] )
    {
        // If publisher actually provided a banner background color, span the banner across the realm
        if ( self.publisherBannerBackgroundColors[adUnitIdentifier] && effectiveAdFormat != MAAdFormat.mrec )
        {
            [safeAreaConstraints addObjectsFromArray: @[[safeAreaBackground.leftAnchor constraintEqualToAnchor: superview.leftAnchor],
                                                        [safeAreaBackground.rightAnchor constraintEqualToAnchor: superview.rightAnchor]]];
            
            if ( [adViewPosition isEqual: @"top_center"] )
            {
                [constraints addObjectsFromArray: @[[adView.topAnchor constraintEqualToAnchor: layoutGuide.topAnchor],
                                                    [adView.leftAnchor constraintEqualToAnchor: superview.leftAnchor],
                                                    [adView.rightAnchor constraintEqualToAnchor: superview.rightAnchor]]];
                [safeAreaConstraints addObjectsFromArray: @[[safeAreaBackground.topAnchor constraintEqualToAnchor: superview.topAnchor],
                                                            [safeAreaBackground.bottomAnchor constraintEqualToAnchor: layoutGuide.topAnchor]]];
            }
            else // BottomCenter
            {
                [constraints addObjectsFromArray: @[[adView.bottomAnchor constraintEqualToAnchor: layoutGuide.bottomAnchor],
                                                    [adView.leftAnchor constraintEqualToAnchor: superview.leftAnchor],
                                                    [adView.rightAnchor constraintEqualToAnchor: superview.rightAnchor]]];
                [safeAreaConstraints addObjectsFromArray: @[[safeAreaBackground.topAnchor constraintEqualToAnchor: layoutGuide.bottomAnchor],
                                                            [safeAreaBackground.bottomAnchor constraintEqualToAnchor: superview.bottomAnchor]]];
            }
        }
        // If pub does not have a background color set - we shouldn't span the banner the width of the realm (there might be user-interactable UI on the sides)
        else
        {
            // Assign constant width of 320 or 728
            [constraints addObject: [adView.widthAnchor constraintEqualToConstant: adViewSize.width]];
            [constraints addObject: [adView.centerXAnchor constraintEqualToAnchor: layoutGuide.centerXAnchor]];
            
            if ( [adViewPosition isEqual: @"top_center"] )
            {
                [constraints addObject: [adView.topAnchor constraintEqualToAnchor: layoutGuide.topAnchor]];
            }
            else // BottomCenter
            {
                [constraints addObject: [adView.bottomAnchor constraintEqualToAnchor: layoutGuide.bottomAnchor]];
            }
        }
    }
    // Otherwise, publisher will likely construct their own views around the adview
    else
    {
        // Assign constant width of 320 or 728
        [constraints addObject: [adView.widthAnchor constraintEqualToConstant: adViewSize.width]];
        
        if ( [adViewPosition isEqual: @"top_left"] )
        {
            [constraints addObjectsFromArray: @[[adView.topAnchor constraintEqualToAnchor: layoutGuide.topAnchor],
                                                [adView.leftAnchor constraintEqualToAnchor: superview.leftAnchor]]];
        }
        else if ( [adViewPosition isEqual: @"top_right"] )
        {
            [constraints addObjectsFromArray: @[[adView.topAnchor constraintEqualToAnchor: layoutGuide.topAnchor],
                                                [adView.rightAnchor constraintEqualToAnchor: superview.rightAnchor]]];
        }
        else if ( [adViewPosition isEqual: @"centered"] )
        {
            [constraints addObjectsFromArray: @[[adView.centerXAnchor constraintEqualToAnchor: layoutGuide.centerXAnchor],
                                                [adView.centerYAnchor constraintEqualToAnchor: layoutGuide.centerYAnchor]]];
        }
        else if ( [adViewPosition isEqual: @"bottom_left"] )
        {
            [constraints addObjectsFromArray: @[[adView.bottomAnchor constraintEqualToAnchor: layoutGuide.bottomAnchor],
                                                [adView.leftAnchor constraintEqualToAnchor: superview.leftAnchor]]];
        }
        else if ( [adViewPosition isEqual: @"bottom_right"] )
        {
            [constraints addObjectsFromArray: @[[adView.bottomAnchor constraintEqualToAnchor: layoutGuide.bottomAnchor],
                                                [adView.rightAnchor constraintEqualToAnchor: superview.rightAnchor]]];
        }
    }
    
    self.adViewConstraints[adUnitIdentifier] = constraints;
    self.safeAreaBackgroundConstraints[adUnitIdentifier] = safeAreaConstraints;
    
    [NSLayoutConstraint activateConstraints: constraints];
    [NSLayoutConstraint activateConstraints: safeAreaConstraints];
    [self updateSafeAreaBackgroundVisibility];
}

+ (CGSize)adViewSizeForAdFormat:(MAAdFormat *)adFormat
{
    if ( MAAdFormat.leader == adFormat )
    {
        return CGSizeMake(728.0f, 90.0f);
    }
    else if ( MAAdFormat.banner == adFormat )
    {
        return CGSizeMake(320.0f, 50.0f);
    }
    else if ( MAAdFormat.mrec == adFormat )
    {
        return CGSizeMake(300.0f, 250.0f);
    }
    else
    {
        [NSException raise: NSInvalidArgumentException format: @"Invalid ad format"];
        return CGSizeZero;
    }
}

#pragma mark - Utility Methods

- (NSDictionary<NSString *, id> *)adInfoForAd:(MAAd *)ad
{
    const NSTimeInterval requestLatency = ad.requestLatency;
    const long long requestLatencyMillis =
        requestLatency < 0.0 ? (long long)requestLatency : (long long)(requestLatency * 1000.0);

    return @{@"adUnitIdentifier" : ad.adUnitIdentifier,
             @"creativeIdentifier" : ad.creativeIdentifier ?: @"",
             @"networkName" : ad.networkName ?: @"",
             @"networkPlacement" : ad.networkPlacement ?: @"",
             @"placement" : ad.placement ?: @"",
             @"revenue" : @(ad.revenue),
             @"revenuePrecision" : ad.revenuePrecision ?: @"",
             @"requestLatencyMillis" : @(requestLatencyMillis),
             @"dspName" : ad.DSPName ?: @"",
             @"dspIdentifier" : ad.DSPIdentifier ?: @"",
             @"format" : ad.format.label ?: @""};
}

- (NSDictionary<NSString *, id> *)loadErrorInfoForError:(MAError *)error
{
    const NSTimeInterval requestLatency = error.requestLatency;
    const long long requestLatencyMillis =
        requestLatency < 0.0 ? (long long)requestLatency : (long long)(requestLatency * 1000.0);

    return @{@"code" : @(error.code),
             @"message" : error.message ?: @"",
             @"requestLatencyMillis" : @(requestLatencyMillis)};
}

- (NSDictionary<NSString *, id> *)displayErrorInfoForError:(MAError *)error
{
    return @{@"code" : @(error.code),
             @"message" : error.message ?: @"",
             @"mediatedNetworkErrorCode" : @(error.mediatedNetworkErrorCode),
             @"mediatedNetworkErrorMessage" : error.mediatedNetworkErrorMessage ?: @""};
}

- (ALConsentFlowUserGeography)toAppLovinConsentFlowUserGeography:(NSString *)userGeography
{
    if ( [@"GDPR" caseInsensitiveCompare: userGeography] == NSOrderedSame )
    {
        return ALConsentFlowUserGeographyGDPR;
    }
    else if ( [@"OTHER" caseInsensitiveCompare: userGeography] == NSOrderedSame )
    {
        return ALConsentFlowUserGeographyOther;
    }

    return ALConsentFlowUserGeographyUnknown;
}

#pragma mark - Defold Bridge

- (void)sendDefoldEventWithName:(NSString *)name parameters:(NSDictionary<NSString *, id> *)parameters
{
    if ( self.state == MADefoldPluginStateDestroyed ) return;

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject: parameters options: 0 error: &error];
    if ( !data )
    {
        [self log: @"Failed to serialize %@ event parameters: %@", name, error.localizedDescription];
        return;
    }

    NSString *serializedParameters = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];

    dmAppLovin::AddToQueueCallback([name UTF8String], [serializedParameters UTF8String]);
}

@end

#endif
