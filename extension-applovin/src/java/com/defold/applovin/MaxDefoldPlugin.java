package com.defold.applovin;

import android.app.Activity;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Rect;
import android.net.Uri;
import android.os.Bundle;
import android.text.TextUtils;
import android.util.Log;
import android.view.Gravity;
import android.view.OrientationEventListener;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewParent;
import android.view.WindowManager;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;

import com.applovin.impl.sdk.utils.JsonUtils;
import com.applovin.impl.sdk.utils.StringUtils;
import com.applovin.mediation.MaxAd;
import com.applovin.mediation.MaxAdFormat;
import com.applovin.mediation.MaxAdListener;
import com.applovin.mediation.MaxAdRevenueListener;
import com.applovin.mediation.MaxAdViewAdListener;
import com.applovin.mediation.MaxError;
import com.applovin.mediation.MaxReward;
import com.applovin.mediation.MaxRewardedAdListener;
import com.applovin.mediation.ads.MaxAdView;
import com.applovin.mediation.ads.MaxInterstitialAd;
import com.applovin.mediation.ads.MaxRewardedAd;
import com.applovin.sdk.AppLovinCmpError;
import com.applovin.sdk.AppLovinCmpService;
import com.applovin.sdk.AppLovinMediationProvider;
import com.applovin.sdk.AppLovinPrivacySettings;
import com.applovin.sdk.AppLovinSdk;
import com.applovin.sdk.AppLovinSdkConfiguration;
import com.applovin.sdk.AppLovinSdkConfiguration.ConsentFlowUserGeography;
import com.applovin.sdk.AppLovinSdkSettings;
import com.applovin.sdk.AppLovinSdkUtils;

import org.json.JSONObject;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@SuppressWarnings("unused")
public class MaxDefoldPlugin
        implements MaxAdListener, MaxAdViewAdListener, MaxRewardedAdListener, MaxAdRevenueListener, AppLovinCmpService.OnCompletedListener
{
    private static final String TAG     = "MaxDefoldPlugin";
    private static final String SDK_TAG = "AppLovinSdk";

    public static native void appLovinAddToQueue(String msg, String json);

    // Parent Fields
    private AppLovinSdk              sdk;
    private boolean                  isPluginInitialized = false;
    private boolean                  isSdkInitialized    = false;
    private AppLovinSdkConfiguration sdkConfiguration;

    // Store these values if pub sets before initializing
    private String       userIdToSet;
    private Boolean      mutedToSet;
    private List<String> testDeviceAdvertisingIdsToSet;
    private Boolean      verboseLoggingToSet;
    private Boolean      creativeDebuggerEnabledToSet;

    private Boolean termsAndPrivacyPolicyFlowEnabledToSet;
    private Uri     privacyPolicyUriToSet;
    private Uri     termsOfServiceUriToSet;
    private String  debugUserGeographyToSet;

    // Fullscreen Ad Fields
    private final Map<String, MaxInterstitialAd> mInterstitials = new HashMap<>( 2 );
    private final Map<String, MaxRewardedAd>     mRewardedAds   = new HashMap<>( 2 );

    // Banner Fields
    private final Map<String, MaxAdView>   mAdViews                    = new HashMap<>( 2 );
    private final Map<String, MaxAdFormat> mAdViewAdFormats            = new HashMap<>( 2 );
    private final Map<String, String>      mAdViewPositions            = new HashMap<>( 2 );
    private final List<String>             mAdUnitIdsToShowAfterCreate = new ArrayList<>( 2 );

    private final WeakReference<Activity> gameActivity;
    private final String                  engineVersion;
    private final String                  pluginVersion;

    private Activity getGameActivity() { return gameActivity.get(); }

    // region Initialization
    public MaxDefoldPlugin(final Activity activity, final String engineVersion, final String pluginVersion)
    {
        gameActivity = new WeakReference<>( activity );
        this.engineVersion = engineVersion;
        this.pluginVersion = pluginVersion;
    }

    public boolean isInitialized()
    {
        return isPluginInitialized && isSdkInitialized;
    }

    public void initialize(final String sdkKey)
    {
        // Check if Activity is available
        Activity currentActivity = getGameActivity();
        if ( currentActivity == null ) throw new IllegalStateException( "No Activity found" );

        final Context context = currentActivity.getApplicationContext();

        // Guard against running init logic multiple times
        if ( isPluginInitialized )
        {
            sendDefoldEvent( "OnSdkInitializedEvent", getInitializationMessage( context ) );
            return;
        }

        isPluginInitialized = true;

        d( "Initializing AppLovin MAX Defold v" + pluginVersion + "..." );

        // If SDK key passed in is empty, check Android Manifest
        String sdkKeyToUse = sdkKey;
        if ( TextUtils.isEmpty( sdkKey ) )
        {
            try
            {
                PackageManager packageManager = context.getPackageManager();
                String packageName = context.getPackageName();
                ApplicationInfo applicationInfo = packageManager.getApplicationInfo( packageName, PackageManager.GET_META_DATA );
                Bundle metaData = applicationInfo.metaData;

                sdkKeyToUse = metaData.getString( "applovin.sdk.key", "" );
            }
            catch ( Throwable th )
            {
                e( "Unable to retrieve SDK key from Android Manifest: " + th );
            }

            if ( TextUtils.isEmpty( sdkKeyToUse ) )
            {
                throw new IllegalStateException( "Unable to initialize AppLovin SDK - no SDK key provided and not found in Android Manifest!" );
            }
        }

        AppLovinSdkSettings settings = new AppLovinSdkSettings( context );

        // Selective init
        if ( termsAndPrivacyPolicyFlowEnabledToSet != null )
        {
            settings.getTermsAndPrivacyPolicyFlowSettings().setEnabled( termsAndPrivacyPolicyFlowEnabledToSet );
            termsAndPrivacyPolicyFlowEnabledToSet = null;
        }

        if ( privacyPolicyUriToSet != null )
        {
            settings.getTermsAndPrivacyPolicyFlowSettings().setPrivacyPolicyUri( privacyPolicyUriToSet );
            privacyPolicyUriToSet = null;
        }

        if ( termsOfServiceUriToSet != null )
        {
            settings.getTermsAndPrivacyPolicyFlowSettings().setTermsOfServiceUri( termsOfServiceUriToSet );
            termsOfServiceUriToSet = null;
        }

        if ( AppLovinSdkUtils.isValidString( debugUserGeographyToSet ) )
        {
            settings.getTermsAndPrivacyPolicyFlowSettings().setDebugUserGeography( getAppLovinConsentFlowUserGeography( debugUserGeographyToSet ) );
            debugUserGeographyToSet = null;
        }

        if ( mutedToSet != null )
        {
            settings.setMuted( mutedToSet );
            mutedToSet = null;
        }

        if ( testDeviceAdvertisingIdsToSet != null )
        {
            settings.setTestDeviceAdvertisingIds( testDeviceAdvertisingIdsToSet );
            testDeviceAdvertisingIdsToSet = null;
        }

        if ( verboseLoggingToSet != null )
        {
            settings.setVerboseLogging( verboseLoggingToSet );
            verboseLoggingToSet = null;
        }

        if ( creativeDebuggerEnabledToSet != null )
        {
            settings.setCreativeDebuggerEnabled( creativeDebuggerEnabledToSet );
            creativeDebuggerEnabledToSet = null;
        }

        // Initialize SDK
        sdk = AppLovinSdk.getInstance( sdkKeyToUse, settings, currentActivity );
        sdk.setPluginVersion( "Defold-" + pluginVersion );
        sdk.setMediationProvider( AppLovinMediationProvider.MAX );

        if ( !TextUtils.isEmpty( userIdToSet ) )
        {
            sdk.setUserIdentifier( userIdToSet );
            userIdToSet = null;
        }

        sdk.initializeSdk( new AppLovinSdk.SdkInitializationListener()
        {
            @Override
            public void onSdkInitialized(final AppLovinSdkConfiguration configuration)
            {
                d( "SDK initialized" );

                sdkConfiguration = configuration;
                isSdkInitialized = true;

                sendDefoldEvent( "OnSdkInitializedEvent", getInitializationMessage( context ) );
            }
        } );
    }

    private JSONObject getInitializationMessage(final Context context)
    {
        JSONObject message = new JSONObject();

        if ( sdkConfiguration != null )
        {
            JsonUtils.putString( message, "countryCode", sdkConfiguration.getCountryCode() );
            JsonUtils.putInt( message, "consentFlowUserGeography", sdkConfiguration.getConsentFlowUserGeography().ordinal() );
            JsonUtils.putBoolean( message, "isTestModeEnabled", sdkConfiguration.isTestModeEnabled() );
        }

        return message;
    }

    public void showMediationDebugger()
    {
        if ( sdk == null )
        {
            Log.e( "[" + TAG + "]", "Failed to show mediation debugger - please ensure the AppLovin MAX Defold Plugin has been initialized by calling 'UAppLovinMAX::Initialize()'!" );
            return;
        }

        sdk.showMediationDebugger();
    }
    // endregion

    // region Privacy
    public void setHasUserConsent(final boolean hasUserConsent)
    {
        AppLovinPrivacySettings.setHasUserConsent( hasUserConsent, getGameActivity() );
    }

    public boolean hasUserConsent()
    {
        return AppLovinPrivacySettings.hasUserConsent( getGameActivity() );
    }

    public void setIsAgeRestrictedUser(final boolean isAgeRestrictedUser)
    {
        AppLovinPrivacySettings.setIsAgeRestrictedUser( isAgeRestrictedUser, getGameActivity() );
    }

    public boolean isAgeRestrictedUser()
    {
        return AppLovinPrivacySettings.isAgeRestrictedUser( getGameActivity() );
    }

    public void setDoNotSell(final boolean doNotSell)
    {
        AppLovinPrivacySettings.setDoNotSell( doNotSell, getGameActivity() );
    }

    public boolean isDoNotSell()
    {
        return AppLovinPrivacySettings.isDoNotSell( getGameActivity() );
    }
    // endregion

    // region General
    public boolean isTablet()
    {
        return AppLovinSdkUtils.isTablet( getGameActivity() );
    }

    public void setUserId(String userId)
    {
        if ( isPluginInitialized )
        {
            sdk.setUserIdentifier( userId );
            userIdToSet = null;
        }
        else
        {
            userIdToSet = userId;
        }
    }

    public void setMuted(final boolean muted)
    {
        if ( isPluginInitialized )
        {
            sdk.getSettings().setMuted( muted );
            mutedToSet = null;
        }
        else
        {
            mutedToSet = muted;
        }
    }

    public boolean isMuted()
    {
        if ( !isPluginInitialized ) return false;

        return sdk.getSettings().isMuted();
    }

    public void setVerboseLoggingEnabled(final boolean enabled)
    {
        if ( isPluginInitialized )
        {
            sdk.getSettings().setVerboseLogging( enabled );
            verboseLoggingToSet = null;
        }
        else
        {
            verboseLoggingToSet = enabled;
        }
    }

    public boolean isVerboseLoggingEnabled()
    {
        if ( isPluginInitialized )
        {
            return sdk.getSettings().isVerboseLoggingEnabled();
        }
        else if ( verboseLoggingToSet != null )
        {
            return verboseLoggingToSet;
        }

        return false;
    }

    public void setCreativeDebuggerEnabled(final boolean enabled)
    {
        if ( isPluginInitialized )
        {
            sdk.getSettings().setCreativeDebuggerEnabled( enabled );
            creativeDebuggerEnabledToSet = null;
        }
        else
        {
            creativeDebuggerEnabledToSet = enabled;
        }
    }

    public void setTestDeviceAdvertisingIds(final String[] advertisingIds)
    {
        if ( isPluginInitialized )
        {
            sdk.getSettings().setTestDeviceAdvertisingIds( Arrays.asList( advertisingIds ) );
            testDeviceAdvertisingIdsToSet = null;
        }
        else
        {
            testDeviceAdvertisingIdsToSet = Arrays.asList( advertisingIds );
        }
    }
    // endregion

    // region Terms and Privacy Policy Flow
    public void setTermsAndPrivacyPolicyFlowEnabled(final boolean enabled)
    {
        termsAndPrivacyPolicyFlowEnabledToSet = enabled;
    }

    public void setPrivacyPolicyUrl(final String urlString)
    {
        privacyPolicyUriToSet = Uri.parse( urlString );
    }

    public void setTermsOfServiceUrl(final String urlString)
    {
        termsOfServiceUriToSet = Uri.parse( urlString );
    }

    public void setConsentFlowDebugUserGeography(final String userGeography)
    {
        debugUserGeographyToSet = userGeography;
    }

    public void showCmpForExistingUser()
    {
        if ( isPluginInitialized )
        {
            sdk.getCmpService().showCmpForExistingUser( getGameActivity(), this );
        }
    }

    public boolean hasSupportedCmp()
    {
        if ( !isPluginInitialized ) return false;

        return sdk.getCmpService().hasSupportedCmp();
    }

    @Override
    public void onCompleted(final AppLovinCmpError error)
    {
        JSONObject params = new JSONObject();
        if ( error != null )
        {
            JsonUtils.putInt( params, "code", error.getCode().getValue() );
            JsonUtils.putString( params, "message", error.getMessage() );
            JsonUtils.putInt( params, "cmpCode", error.getCmpCode() );
            JsonUtils.putString( params, "cmpMessage", error.getCmpMessage() );
        }

        sendDefoldEvent( "OnCmpCompletedEvent", params );
    }
    // endregion

    // region Event Tracking
    public void trackEvent(final String event, final String parameters)
    {
        if ( sdk == null ) return;

        final Map<String, String> deserialized = deserialize( parameters );
        sdk.getEventService().trackEvent( event, deserialized );
    }
    // endregion

    // region Interstitials
    public void loadInterstitial(final String adUnitId)
    {
        MaxInterstitialAd interstitial = retrieveInterstitial( adUnitId );
        interstitial.loadAd();
    }

    public boolean isInterstitialReady(String adUnitId)
    {
        MaxInterstitialAd interstitial = retrieveInterstitial( adUnitId );
        return interstitial.isReady();
    }

    public void showInterstitial(final String adUnitId, final String placement)
    {
        MaxInterstitialAd interstitial = retrieveInterstitial( adUnitId );
        interstitial.showAd( placement );
    }

    public void setInterstitialExtraParameter(final String adUnitId, final String key, final String value)
    {
        MaxInterstitialAd interstitial = retrieveInterstitial( adUnitId );
        interstitial.setExtraParameter( key, value );
    }
    // endregion

    // region Rewarded
    public void loadRewardedAd(final String adUnitId)
    {
        MaxRewardedAd rewardedAd = retrieveRewardedAd( adUnitId );
        rewardedAd.loadAd();
    }

    public boolean isRewardedAdReady(final String adUnitId)
    {
        MaxRewardedAd rewardedAd = retrieveRewardedAd( adUnitId );
        return rewardedAd.isReady();
    }

    public void showRewardedAd(final String adUnitId, final String placement)
    {
        MaxRewardedAd rewardedAd = retrieveRewardedAd( adUnitId );
        rewardedAd.showAd( placement );
    }

    public void setRewardedAdExtraParameter(final String adUnitId, final String key, final String value)
    {
        MaxRewardedAd rewardedAd = retrieveRewardedAd( adUnitId );
        rewardedAd.setExtraParameter( key, value );
    }
    // endregion

    // region Banners
    public void createBanner(final String adUnitId, final String bannerPosition)
    {
        createAdView( adUnitId, getDeviceSpecificBannerAdViewAdFormat(), bannerPosition );
    }

    public void setBannerBackgroundColor(final String adUnitId, final String hexColorCode)
    {
        setAdViewBackgroundColor( adUnitId, getDeviceSpecificBannerAdViewAdFormat(), hexColorCode );
    }

    public void setBannerPlacement(final String adUnitId, final String placement)
    {
        setAdViewPlacement( adUnitId, getDeviceSpecificBannerAdViewAdFormat(), placement );
    }

    public void setBannerExtraParameter(final String adUnitId, final String key, final String value)
    {
        setAdViewExtraParameters( adUnitId, getDeviceSpecificBannerAdViewAdFormat(), key, value );
    }

    public void updateBannerPosition(final String adUnitId, final String bannerPosition)
    {
        updateAdViewPosition( adUnitId, bannerPosition, getDeviceSpecificBannerAdViewAdFormat() );
    }

    public void startBannerAutoRefresh(final String adUnitId)
    {
        startAutoRefresh( adUnitId, getDeviceSpecificBannerAdViewAdFormat() );
    }

    public void stopBannerAutoRefresh(final String adUnitId)
    {
        stopAutoRefresh( adUnitId, getDeviceSpecificBannerAdViewAdFormat() );
    }

    public void showBanner(final String adUnitId)
    {
        showAdView( adUnitId, getDeviceSpecificBannerAdViewAdFormat() );
    }

    public void hideBanner(final String adUnitId)
    {
        hideAdView( adUnitId, getDeviceSpecificBannerAdViewAdFormat() );
    }

    public void destroyBanner(final String adUnitId)
    {
        destroyAdView( adUnitId, getDeviceSpecificBannerAdViewAdFormat() );
    }
    // endregion

    // region MRECS
    public void createMRec(final String adUnitId, final String mrecPosition)
    {
        createAdView( adUnitId, MaxAdFormat.MREC, mrecPosition );
    }

    public void setMRecPlacement(final String adUnitId, final String placement)
    {
        setAdViewPlacement( adUnitId, MaxAdFormat.MREC, placement );
    }

    public void setMRecExtraParameter(final String adUnitId, final String key, final String value)
    {
        setAdViewExtraParameters( adUnitId, MaxAdFormat.MREC, key, value );
    }

    public void updateMRecPosition(final String adUnitId, final String mrecPosition)
    {
        updateAdViewPosition( adUnitId, mrecPosition, MaxAdFormat.MREC );
    }

    public void startMRecAutoRefresh(final String adUnitId)
    {
        startAutoRefresh( adUnitId, MaxAdFormat.MREC );
    }

    public void stopMRecAutoRefresh(final String adUnitId)
    {
        stopAutoRefresh( adUnitId, MaxAdFormat.MREC );
    }

    public void showMRec(final String adUnitId)
    {
        showAdView( adUnitId, MaxAdFormat.MREC );
    }

    public void hideMRec(final String adUnitId)
    {
        hideAdView( adUnitId, MaxAdFormat.MREC );
    }

    public void destroyMRec(final String adUnitId)
    {
        destroyAdView( adUnitId, MaxAdFormat.MREC );
    }
    // endregion

    // region Ad Callbacks
    @Override
    public void onAdLoaded(MaxAd ad)
    {
        String name;
        MaxAdFormat adFormat = ad.getFormat();
        if ( adFormat.isAdViewAd() )
        {
            name = ( MaxAdFormat.MREC == adFormat ) ? "OnMRecAdLoadedEvent" : "OnBannerAdLoadedEvent";

            String adViewPosition = mAdViewPositions.get( ad.getAdUnitId() );
            if ( !TextUtils.isEmpty( adViewPosition ) )
            {
                // Only position ad if not native UI component
                positionAdView( ad );
            }

            // Do not auto-refresh by default if the ad view is not showing yet (e.g. first load during app launch and publisher does not automatically show banner upon load success)
            // We will resume auto-refresh in {@link #showBanner(String)}.
            MaxAdView adView = retrieveAdView( ad.getAdUnitId(), adFormat );
            if ( adView != null && adView.getVisibility() != View.VISIBLE )
            {
                adView.stopAutoRefresh();
            }
        }
        else if ( MaxAdFormat.INTERSTITIAL == adFormat )
        {
            name = "OnInterstitialAdLoadedEvent";
        }
        else if ( MaxAdFormat.REWARDED == adFormat )
        {
            name = "OnRewardedAdLoadedEvent";
        }
        else
        {
            logInvalidAdFormat( adFormat );
            return;
        }

        sendDefoldEvent( name, getAdInfo( ad ) );
    }

    @Override
    public void onAdLoadFailed(final String adUnitId, final MaxError error)
    {
        if ( TextUtils.isEmpty( adUnitId ) )
        {
            logStackTrace( new IllegalArgumentException( "adUnitId cannot be null" ) );
            return;
        }

        String name;
        if ( mAdViews.containsKey( adUnitId ) )
        {
            name = ( MaxAdFormat.MREC == mAdViewAdFormats.get( adUnitId ) ) ? "OnMRecAdLoadFailedEvent" : "OnBannerAdLoadFailedEvent";
        }
        else if ( mInterstitials.containsKey( adUnitId ) )
        {
            name = "OnInterstitialAdLoadFailedEvent";
        }
        else if ( mRewardedAds.containsKey( adUnitId ) )
        {
            name = "OnRewardedAdLoadFailedEvent";
        }
        else
        {
            logStackTrace( new IllegalStateException( "invalid adUnitId: " + adUnitId ) );
            return;
        }

        JSONObject params = getErrorInfo( error );
        JsonUtils.putString( params, "adUnitIdentifier", adUnitId );

        sendDefoldEvent( name, params );
    }

    @Override
    public void onAdClicked(final MaxAd ad)
    {
        final MaxAdFormat adFormat = ad.getFormat();
        final String name;
        if ( MaxAdFormat.BANNER == adFormat || MaxAdFormat.LEADER == adFormat )
        {
            name = "OnBannerAdClickedEvent";
        }
        else if ( MaxAdFormat.MREC == adFormat )
        {
            name = "OnMRecAdClickedEvent";
        }
        else if ( MaxAdFormat.INTERSTITIAL == adFormat )
        {
            name = "OnInterstitialAdClickedEvent";
        }
        else if ( MaxAdFormat.REWARDED == adFormat )
        {
            name = "OnRewardedAdClickedEvent";
        }
        else
        {
            logInvalidAdFormat( adFormat );
            return;
        }

        sendDefoldEvent( name, getAdInfo( ad ) );
    }

    @Override
    public void onAdDisplayed(final MaxAd ad)
    {
        // BMLs do not support [DISPLAY] events
        final MaxAdFormat adFormat = ad.getFormat();
        if ( adFormat != MaxAdFormat.INTERSTITIAL && adFormat != MaxAdFormat.REWARDED ) return;

        final String name;
        if ( MaxAdFormat.INTERSTITIAL == adFormat )
        {
            name = "OnInterstitialAdDisplayedEvent";
        }
        else // REWARDED
        {
            name = "OnRewardedAdDisplayedEvent";
        }

        sendDefoldEvent( name, getAdInfo( ad ) );
    }

    @Override
    public void onAdDisplayFailed(final MaxAd ad, final MaxError error)
    {
        // BMLs do not support [DISPLAY] events
        final MaxAdFormat adFormat = ad.getFormat();
        if ( adFormat != MaxAdFormat.INTERSTITIAL && adFormat != MaxAdFormat.REWARDED ) return;

        final String name;
        if ( MaxAdFormat.INTERSTITIAL == adFormat )
        {
            name = "OnInterstitialAdDisplayFailedEvent";
        }
        else // REWARDED
        {
            name = "OnRewardedAdDisplayFailedEvent";
        }

        JSONObject params = getAdInfo( ad );
        JsonUtils.putAll( params, getErrorInfo( error ) );

        sendDefoldEvent( name, params );
    }

    @Override
    public void onAdHidden(final MaxAd ad)
    {
        // BMLs do not support [HIDDEN] events
        final MaxAdFormat adFormat = ad.getFormat();
        if ( adFormat != MaxAdFormat.INTERSTITIAL && adFormat != MaxAdFormat.REWARDED ) return;

        String name;
        if ( MaxAdFormat.INTERSTITIAL == adFormat )
        {
            name = "OnInterstitialAdHiddenEvent";
        }
        else // REWARDED
        {
            name = "OnRewardedAdHiddenEvent";
        }

        sendDefoldEvent( name, getAdInfo( ad ) );
    }

    @Override
    public void onAdExpanded(final MaxAd ad)
    {
        final MaxAdFormat adFormat = ad.getFormat();
        if ( !adFormat.isAdViewAd() )
        {
            logInvalidAdFormat( adFormat );
            return;
        }

        sendDefoldEvent( ( MaxAdFormat.MREC == adFormat ) ? "OnMrecAdExpandedEvent" : "OnBannerAdExpandedEvent", getAdInfo( ad ) );
    }

    @Override
    public void onAdCollapsed(final MaxAd ad)
    {
        final MaxAdFormat adFormat = ad.getFormat();
        if ( !adFormat.isAdViewAd() )
        {
            logInvalidAdFormat( adFormat );
            return;
        }

        sendDefoldEvent( ( MaxAdFormat.MREC == adFormat ) ? "OnMRecAdCollapsedEvent" : "OnBannerAdCollapsedEvent", getAdInfo( ad ) );
    }

    @Override
    public void onRewardedVideoCompleted(final MaxAd ad)
    {
        // This event is not forwarded
    }

    @Override
    public void onRewardedVideoStarted(final MaxAd ad)
    {
        // This event is not forwarded
    }

    @Override
    public void onUserRewarded(final MaxAd ad, final MaxReward reward)
    {
        final MaxAdFormat adFormat = ad.getFormat();
        if ( adFormat != MaxAdFormat.REWARDED )
        {
            logInvalidAdFormat( adFormat );
            return;
        }

        JSONObject params = getAdInfo( ad );
        JsonUtils.putString( params, "label", reward != null ? reward.getLabel() : "" );
        JsonUtils.putInt( params, "amount", reward != null ? reward.getAmount() : 0 );

        sendDefoldEvent( "OnRewardedAdReceivedRewardEvent", params );
    }

    @Override
    public void onAdRevenuePaid(final MaxAd ad)
    {
        final MaxAdFormat adFormat = ad.getFormat();
        final String name;
        if ( MaxAdFormat.BANNER == adFormat || MaxAdFormat.LEADER == adFormat )
        {
            name = "OnBannerAdRevenuePaidEvent";
        }
        else if ( MaxAdFormat.MREC == adFormat )
        {
            name = "OnMRecAdRevenuePaidEvent";
        }
        else if ( MaxAdFormat.CROSS_PROMO == adFormat )
        {
            name = "OnCrossPromoAdRevenuePaidEvent";
        }
        else if ( MaxAdFormat.INTERSTITIAL == adFormat )
        {
            name = "OnInterstitialAdRevenuePaidEvent";
        }
        else if ( MaxAdFormat.REWARDED == adFormat )
        {
            name = "OnRewardedAdRevenuePaidEvent";
        }
        else
        {
            logInvalidAdFormat( adFormat );
            return;
        }

        sendDefoldEvent( name, getAdInfo( ad ) );
    }

    // region Internal Methods
    private void createAdView(final String adUnitId, final MaxAdFormat adFormat, final String adViewPosition)
    {
        // Run on main thread to ensure there are no concurrency issues with other ad view methods
        getGameActivity().runOnUiThread( new Runnable()
        {
            @Override
            public void run()
            {
                d( "Creating " + adFormat.getLabel() + " with ad unit id \"" + adUnitId + "\" and position: \"" + adViewPosition + "\"" );

                // Retrieve ad view from the map
                final MaxAdView adView = retrieveAdView( adUnitId, adFormat, adViewPosition );
                if ( adView == null )
                {
                    e( adFormat.getLabel() + " does not exist" );
                    return;
                }

                if ( adView.getParent() == null )
                {
                    final Activity currentActivity = getGameActivity();
                    final RelativeLayout relativeLayout = new RelativeLayout( currentActivity );
                    relativeLayout.setVisibility( View.GONE );
                    relativeLayout.addView( adView );

                    WindowManager.LayoutParams layoutParams = new WindowManager.LayoutParams();
                    layoutParams.width = WindowManager.LayoutParams.WRAP_CONTENT;
                    layoutParams.height = WindowManager.LayoutParams.WRAP_CONTENT;
                    layoutParams.flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL | WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;

                    currentActivity.getWindowManager().addView( relativeLayout, layoutParams );

                    // Position ad view immediately so if publisher sets color before ad loads, it will not be the size of the screen
                    mAdViewAdFormats.put( adUnitId, adFormat );
                    positionAdView( adUnitId, adFormat );
                }

                adView.loadAd();

                // The publisher may have requested to show the banner before it was created. Now that the banner is created, show it.
                if ( mAdUnitIdsToShowAfterCreate.contains( adUnitId ) )
                {
                    showAdView( adUnitId, adFormat );
                    mAdUnitIdsToShowAfterCreate.remove( adUnitId );
                }
            }
        } );
    }

    private void setAdViewPlacement(final String adUnitId, final MaxAdFormat adFormat, final String placement)
    {
        getGameActivity().runOnUiThread( new Runnable()
        {
            @Override
            public void run()
            {
                d( "Setting placement \"" + placement + "\" for " + adFormat.getLabel() + " with ad unit id \"" + adUnitId + "\"" );

                final MaxAdView adView = retrieveAdView( adUnitId, adFormat );
                if ( adView == null )
                {
                    e( adFormat.getLabel() + " does not exist" );
                    return;
                }

                adView.setPlacement( placement );
            }
        } );
    }

    private void updateAdViewPosition(final String adUnitId, final String adViewPosition, final MaxAdFormat adFormat)
    {
        getGameActivity().runOnUiThread( new Runnable()
        {
            @Override
            public void run()
            {
                d( "Updating " + adFormat.getLabel() + " position to \"" + adViewPosition + "\" for ad unit id \"" + adUnitId + "\"" );

                // Retrieve ad view from the map
                final MaxAdView adView = retrieveAdView( adUnitId, adFormat );
                if ( adView == null )
                {
                    e( adFormat.getLabel() + " does not exist" );
                    return;
                }

                // Check if the previous position is same as the new position. If so, no need to update the position again.
                final String previousPosition = mAdViewPositions.get( adUnitId );
                if ( adViewPosition == null || adViewPosition.equals( previousPosition ) ) return;

                mAdViewPositions.put( adUnitId, adViewPosition );
                positionAdView( adUnitId, adFormat );
            }
        } );
    }

    private void showAdView(final String adUnitId, final MaxAdFormat adFormat)
    {
        getGameActivity().runOnUiThread( new Runnable()
        {
            @Override
            public void run()
            {
                d( "Showing " + adFormat.getLabel() + " with ad unit id \"" + adUnitId + "\"" );

                final MaxAdView adView = retrieveAdView( adUnitId, adFormat );
                if ( adView == null )
                {
                    e( adFormat.getLabel() + " does not exist for ad unit id " + adUnitId );

                    // The adView has not yet been created. Store the ad unit ID, so that it can be displayed once the banner has been created.
                    mAdUnitIdsToShowAfterCreate.add( adUnitId );
                    return;
                }

                RelativeLayout relativeLayout = (RelativeLayout) adView.getParent();
                relativeLayout.setVisibility( View.VISIBLE );
                adView.startAutoRefresh();
            }
        } );
    }

    private void hideAdView(final String adUnitId, final MaxAdFormat adFormat)
    {
        getGameActivity().runOnUiThread( new Runnable()
        {
            @Override
            public void run()
            {
                d( "Hiding " + adFormat.getLabel() + " with ad unit id \"" + adUnitId + "\"" );
                mAdUnitIdsToShowAfterCreate.remove( adUnitId );

                final MaxAdView adView = retrieveAdView( adUnitId, adFormat );
                if ( adView == null )
                {
                    e( adFormat.getLabel() + " does not exist" );
                    return;
                }

                adView.setVisibility( View.GONE );
                adView.stopAutoRefresh();
            }
        } );
    }

    private void destroyAdView(final String adUnitId, final MaxAdFormat adFormat)
    {
        getGameActivity().runOnUiThread( new Runnable()
        {
            @Override
            public void run()
            {
                d( "Destroying " + adFormat.getLabel() + " with ad unit id \"" + adUnitId + "\"" );

                final MaxAdView adView = retrieveAdView( adUnitId, adFormat );
                if ( adView == null )
                {
                    e( adFormat.getLabel() + " does not exist" );
                    return;
                }

                final ViewParent parent = adView.getParent();
                if ( parent instanceof ViewGroup )
                {
                    getGameActivity().getWindowManager().removeView( (View) parent );
                }

                adView.setListener( null );
                adView.destroy();

                mAdViews.remove( adUnitId );
                mAdViewAdFormats.remove( adUnitId );
                mAdViewPositions.remove( adUnitId );
            }
        } );
    }

    private void setAdViewBackgroundColor(final String adUnitId, final MaxAdFormat adFormat, final String hexColorCode)
    {
        getGameActivity().runOnUiThread( new Runnable()
        {
            @Override
            public void run()
            {
                d( "Setting " + adFormat.getLabel() + " with ad unit id \"" + adUnitId + "\" to color: " + hexColorCode );

                final MaxAdView adView = retrieveAdView( adUnitId, adFormat );
                if ( adView == null )
                {
                    e( adFormat.getLabel() + " does not exist" );
                    return;
                }

                adView.setBackgroundColor( Color.parseColor( hexColorCode ) );
            }
        } );
    }

    private void setAdViewExtraParameters(final String adUnitId, final MaxAdFormat adFormat, final String key, final String value)
    {
        getGameActivity().runOnUiThread( new Runnable()
        {
            @Override
            public void run()
            {
                d( "Setting " + adFormat.getLabel() + " extra with key: \"" + key + "\" value: " + value );

                // Retrieve ad view from the map
                final MaxAdView adView = retrieveAdView( adUnitId, adFormat );
                if ( adView == null )
                {
                    e( adFormat.getLabel() + " does not exist" );
                    return;
                }

                adView.setExtraParameter( key, value );

                // Handle local changes as needed
                if ( "force_banner".equalsIgnoreCase( key ) && MaxAdFormat.MREC != adFormat )
                {
                    final MaxAdFormat forcedAdFormat;

                    boolean shouldForceBanner = Boolean.parseBoolean( value );
                    if ( shouldForceBanner )
                    {
                        forcedAdFormat = MaxAdFormat.BANNER;
                    }
                    else
                    {
                        forcedAdFormat = getDeviceSpecificBannerAdViewAdFormat();
                    }

                    mAdViewAdFormats.put( adUnitId, forcedAdFormat );
                    positionAdView( adUnitId, forcedAdFormat );
                }
            }
        } );
    }

    private void startAutoRefresh(final String adUnitId, final MaxAdFormat adFormat)
    {
        d( "Starting auto refresh " + adFormat.getLabel() + " with ad unit id \"" + adUnitId + "\"" );

        final MaxAdView adView = retrieveAdView( adUnitId, adFormat );
        if ( adView == null )
        {
            e( adFormat.getLabel() + " does not exist" );
            return;
        }

        adView.startAutoRefresh();
    }

    private void stopAutoRefresh(final String adUnitId, final MaxAdFormat adFormat)
    {
        d( "Stopping auto refresh " + adFormat.getLabel() + " with ad unit id \"" + adUnitId + "\"" );

        final MaxAdView adView = retrieveAdView( adUnitId, adFormat );
        if ( adView == null )
        {
            e( adFormat.getLabel() + " does not exist" );
            return;
        }

        adView.stopAutoRefresh();
    }

    private void logInvalidAdFormat(MaxAdFormat adFormat)
    {
        logStackTrace( new IllegalStateException( "invalid ad format: " + adFormat ) );
    }

    private void logStackTrace(Exception e)
    {
        e( Log.getStackTraceString( e ) );
    }

    public static void d(final String message)
    {
        final String fullMessage = "[" + TAG + "] " + message;
        Log.d( SDK_TAG, fullMessage );
    }

    public static void e(final String message)
    {
        final String fullMessage = "[" + TAG + "] " + message;
        Log.e( SDK_TAG, fullMessage );
    }

    private MaxInterstitialAd retrieveInterstitial(String adUnitId)
    {
        MaxInterstitialAd result = mInterstitials.get( adUnitId );
        if ( result == null )
        {
            result = new MaxInterstitialAd( adUnitId, sdk, getGameActivity() );
            result.setListener( this );

            mInterstitials.put( adUnitId, result );
        }

        return result;
    }

    private MaxRewardedAd retrieveRewardedAd(String adUnitId)
    {
        MaxRewardedAd result = mRewardedAds.get( adUnitId );
        if ( result == null )
        {
            result = MaxRewardedAd.getInstance( adUnitId, sdk, getGameActivity() );
            result.setListener( this );

            mRewardedAds.put( adUnitId, result );
        }

        return result;
    }

    private MaxAdView retrieveAdView(String adUnitId, MaxAdFormat adFormat)
    {
        return retrieveAdView( adUnitId, adFormat, null );
    }

    public MaxAdView retrieveAdView(String adUnitId, MaxAdFormat adFormat, String adViewPosition)
    {
        MaxAdView result = mAdViews.get( adUnitId );
        if ( result == null && adViewPosition != null )
        {
            // Must explicitly cast the GameActivity to Context to avoid a crash from NoSuchMethodError
            result = new MaxAdView( adUnitId, adFormat, sdk, (Context) getGameActivity() );
            result.setListener( this );

            mAdViews.put( adUnitId, result );
            mAdViewPositions.put( adUnitId, adViewPosition );
        }

        return result;
    }

    private void positionAdView(MaxAd ad)
    {
        positionAdView( ad.getAdUnitId(), ad.getFormat() );
    }

    private void positionAdView(String adUnitId, MaxAdFormat adFormat)
    {
        final MaxAdView adView = retrieveAdView( adUnitId, adFormat );
        if ( adView == null )
        {
            e( adFormat.getLabel() + " does not exist" );
            return;
        }

        final RelativeLayout relativeLayout = (RelativeLayout) adView.getParent();
        if ( relativeLayout == null )
        {
            e( adFormat.getLabel() + "'s parent does not exist" );
            return;
        }

        // Size the ad
        final String adViewPosition = mAdViewPositions.get( adUnitId );
        final AdViewSize adViewSize = getAdViewSize( adFormat );
        final int width = AppLovinSdkUtils.dpToPx( getGameActivity(), adViewSize.widthDp );
        final int height = AppLovinSdkUtils.dpToPx( getGameActivity(), adViewSize.heightDp );

        final RelativeLayout.LayoutParams params = (RelativeLayout.LayoutParams) adView.getLayoutParams();

        params.height = height;
        adView.setLayoutParams( params );

        // Parse gravity
        int gravity = 0;

        // Reset rotation, translation and margins so that the banner can be positioned again
        adView.setRotation( 0 );
        adView.setTranslationX( 0 );
        params.setMargins( 0, 0, 0, 0 );

        if ( "centered".equalsIgnoreCase( adViewPosition ) )
        {
            gravity = Gravity.CENTER_VERTICAL | Gravity.CENTER_HORIZONTAL;
        }
        else
        {
            // Figure out vertical params
            if ( adViewPosition == null )
            {
                e( "Error positioning ad view due to null position" );
                return;
            }
            else if ( adViewPosition.contains( "top" ) )
            {
                gravity = Gravity.TOP;
            }
            else if ( adViewPosition.contains( "bottom" ) )
            {
                gravity = Gravity.BOTTOM;
            }

            // Figure out horizontal params
            if ( adViewPosition.contains( "center" ) )
            {
                gravity |= Gravity.CENTER_HORIZONTAL;
                params.width = ( MaxAdFormat.MREC == adFormat ) ? width : RelativeLayout.LayoutParams.MATCH_PARENT; // Stretch width if banner
            }
            else
            {
                params.width = width;

                if ( adViewPosition.contains( "left" ) )
                {
                    gravity |= Gravity.LEFT;
                }
                else if ( adViewPosition.contains( "right" ) )
                {
                    gravity |= Gravity.RIGHT;
                }
            }
        }

        WindowManager.LayoutParams layoutParams = (WindowManager.LayoutParams) relativeLayout.getLayoutParams();
        layoutParams.gravity = gravity;
        getGameActivity().getWindowManager().updateViewLayout( relativeLayout, layoutParams );
    }
    // endregion

    // region Utility Methods
    private MaxAdFormat getDeviceSpecificBannerAdViewAdFormat()
    {
        return getDeviceSpecificBannerAdViewAdFormat( getGameActivity() );
    }

    public static MaxAdFormat getDeviceSpecificBannerAdViewAdFormat(final Context context)
    {
        return AppLovinSdkUtils.isTablet( context ) ? MaxAdFormat.LEADER : MaxAdFormat.BANNER;
    }

    protected static class AdViewSize
    {
        public final int widthDp;
        public final int heightDp;

        private AdViewSize(final int widthDp, final int heightDp)
        {
            this.widthDp = widthDp;
            this.heightDp = heightDp;
        }
    }

    public static AdViewSize getAdViewSize(final MaxAdFormat format)
    {
        if ( MaxAdFormat.LEADER == format )
        {
            return new AdViewSize( 728, 90 );
        }
        else if ( MaxAdFormat.BANNER == format )
        {
            return new AdViewSize( 320, 50 );
        }
        else if ( MaxAdFormat.MREC == format )
        {
            return new AdViewSize( 300, 250 );
        }
        else
        {
            throw new IllegalArgumentException( "Invalid ad format" );
        }
    }

    private JSONObject getAdInfo(final MaxAd ad)
    {
        JSONObject adInfo = new JSONObject();

        JsonUtils.putString( adInfo, "adUnitIdentifier", ad.getAdUnitId() );
        JsonUtils.putString( adInfo, "creativeIdentifier", StringUtils.emptyIfNull( ad.getCreativeId() ) );
        JsonUtils.putString( adInfo, "networkName", ad.getNetworkName() );
        JsonUtils.putString( adInfo, "placement", StringUtils.emptyIfNull( ad.getPlacement() ) );
        JsonUtils.putDouble( adInfo, "revenue", ad.getRevenue() );

        return adInfo;
    }

    private JSONObject getErrorInfo(final MaxError error)
    {
        JSONObject errorInfo = new JSONObject();

        JsonUtils.putInt( errorInfo, "code", error.getCode() );
        JsonUtils.putString( errorInfo, "message", error.getMessage() );

        return errorInfo;
    }

    private static Map<String, String> deserialize(final String serialized)
    {
        if ( !TextUtils.isEmpty( serialized ) )
        {
            try
            {
                return JsonUtils.toStringMap( JsonUtils.jsonObjectFromJsonString( serialized, new JSONObject() ) );
            }
            catch ( Throwable th )
            {
                e( "Failed to deserialize: (" + serialized + ") with exception: " + th );
            }
        }

        return Collections.emptyMap();
    }

    private static ConsentFlowUserGeography getAppLovinConsentFlowUserGeography(final String userGeography)
    {
        if ( "GDPR".equalsIgnoreCase( userGeography ) )
        {
            return ConsentFlowUserGeography.GDPR;
        }
        else if ( "OTHER".equalsIgnoreCase( userGeography ) )
        {
            return ConsentFlowUserGeography.OTHER;
        }

        return ConsentFlowUserGeography.UNKNOWN;
    }
    // endregion

    // region Defold Bridge

    // NOTE: Defold deserializes to the relevant USTRUCT based on the JSON keys, so the keys must match with the corresponding UPROPERTY
    private void sendDefoldEvent(final String name, final JSONObject params)
    {
        appLovinAddToQueue( name, params.toString() );
    }
    // endregion
}