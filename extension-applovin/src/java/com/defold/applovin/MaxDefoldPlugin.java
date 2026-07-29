package com.defold.applovin;

import android.app.Activity;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewParent;
import android.view.WindowManager;
import android.widget.RelativeLayout;

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
import com.applovin.sdk.AppLovinSdkInitializationConfiguration;
import com.applovin.sdk.AppLovinSdkSettings;
import com.applovin.sdk.AppLovinSdkUtils;
import com.applovin.sdk.AppLovinTermsAndPrivacyPolicyFlowSettings;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Callable;
import java.util.concurrent.FutureTask;
import java.util.concurrent.TimeUnit;

@SuppressWarnings("unused")
public class MaxDefoldPlugin
        implements MaxAdListener, MaxAdViewAdListener, MaxRewardedAdListener, MaxAdRevenueListener, AppLovinCmpService.OnCompletedListener
{
    private static final String TAG = "MaxDefoldPlugin";
    private static final String SDK_TAG = "AppLovinSdk";
    private static final long UI_CALL_TIMEOUT_SECONDS = 5;
    private static final long SHARED_INITIALIZATION_WAIT_MILLIS = 50;

    private enum State
    {
        NEW,
        INITIALIZING,
        READY,
        DESTROYED
    }

    private enum SharedInitializationState
    {
        IDLE,
        IN_PROGRESS,
        COMPLETE
    }

    private interface ActivityAction
    {
        void run(Activity activity);
    }

    private interface ActivityCallable<T>
    {
        T call(Activity activity) throws Exception;
    }

    public static native void appLovinAddToQueue(String msg, String json);

    private static final Object SHARED_INITIALIZATION_LOCK = new Object();
    private static SharedInitializationState sharedInitializationState =
            SharedInitializationState.IDLE;
    private static AppLovinSdkConfiguration sharedSdkConfiguration;
    private static long sharedInitializationGeneration;

    private final WeakReference<Activity> gameActivity;
    private final Handler mainHandler = new Handler( Looper.getMainLooper() );
    private final Object lifecycleLock = new Object();
    private final String pluginVersion;

    private volatile State state = State.NEW;
    private volatile long lifecycleGeneration = 1;
    private volatile boolean destroyRequested;
    private long initializationGeneration;
    private FutureTask<Void> destroyTask;
    private AppLovinSdk sdk;
    private AppLovinSdkConfiguration sdkConfiguration;

    // Values set before initialization are applied to SDK settings/configuration in initialize().
    private String userIdToSet;
    private Boolean mutedToSet;
    private List<String> testDeviceAdvertisingIdsToSet;
    private Boolean verboseLoggingToSet;
    private Boolean creativeDebuggerEnabledToSet;
    private Boolean termsAndPrivacyPolicyFlowEnabledToSet;
    private Uri privacyPolicyUriToSet;
    private Uri termsOfServiceUriToSet;
    private String debugUserGeographyToSet;

    // All ad object collections are confined to the Android UI thread.
    private final Map<String, MaxInterstitialAd> mInterstitials = new HashMap<>( 2 );
    private final Map<String, MaxRewardedAd> mRewardedAds = new HashMap<>( 2 );
    private final Map<String, MaxAdView> mAdViews = new HashMap<>( 2 );
    private final Map<String, MaxAdFormat> mAdViewAdFormats = new HashMap<>( 2 );
    private final Map<String, String> mAdViewPlacements = new HashMap<>( 2 );
    private final Map<String, Map<String, String>> mAdViewExtraParameters =
            new HashMap<>( 2 );
    private final Map<String, String> mAdViewPositions = new HashMap<>( 2 );
    private final Map<String, Long> mAdViewGenerations = new HashMap<>( 2 );
    private final Set<String> mAdUnitIdsToShowAfterCreate = new HashSet<>( 2 );
    private final Set<String> mAdUnitIdsWithStoppedAutoRefresh = new HashSet<>( 2 );
    private long nextAdViewGeneration;
    private boolean callbackDispatchInProgress;

    private final class AdViewListener
            implements MaxAdListener, MaxAdViewAdListener, MaxAdRevenueListener
    {
        private final String adUnitId;
        private final long generation;

        private AdViewListener(final String adUnitId, final long generation)
        {
            this.adUnitId = adUnitId;
            this.generation = generation;
        }

        @Override
        public void onAdLoaded(final MaxAd ad)
        {
            dispatchAdViewCallback( "ad loaded callback", adUnitId, generation, new Runnable()
            {
                @Override
                public void run()
                {
                    MaxDefoldPlugin.this.onAdLoaded( ad );
                }
            } );
        }

        @Override
        public void onAdLoadFailed(final String ignoredAdUnitId, final MaxError error)
        {
            dispatchAdViewCallback( "ad load failed callback", adUnitId, generation, new Runnable()
            {
                @Override
                public void run()
                {
                    MaxDefoldPlugin.this.onAdLoadFailed( adUnitId, error );
                }
            } );
        }

        @Override
        public void onAdClicked(final MaxAd ad)
        {
            dispatchAdViewCallback( "ad clicked callback", adUnitId, generation, new Runnable()
            {
                @Override
                public void run()
                {
                    MaxDefoldPlugin.this.onAdClicked( ad );
                }
            } );
        }

        @Override
        public void onAdDisplayed(final MaxAd ad)
        {
            dispatchAdViewCallback( "ad displayed callback", adUnitId, generation, new Runnable()
            {
                @Override
                public void run()
                {
                    MaxDefoldPlugin.this.onAdDisplayed( ad );
                }
            } );
        }

        @Override
        public void onAdDisplayFailed(final MaxAd ad, final MaxError error)
        {
            dispatchAdViewCallback(
                    "ad display failed callback",
                    adUnitId,
                    generation,
                    new Runnable()
                    {
                        @Override
                        public void run()
                        {
                            MaxDefoldPlugin.this.onAdDisplayFailed( ad, error );
                        }
                    } );
        }

        @Override
        public void onAdHidden(final MaxAd ad)
        {
            dispatchAdViewCallback( "ad hidden callback", adUnitId, generation, new Runnable()
            {
                @Override
                public void run()
                {
                    MaxDefoldPlugin.this.onAdHidden( ad );
                }
            } );
        }

        @Override
        public void onAdExpanded(final MaxAd ad)
        {
            dispatchAdViewCallback( "ad expanded callback", adUnitId, generation, new Runnable()
            {
                @Override
                public void run()
                {
                    MaxDefoldPlugin.this.onAdExpanded( ad );
                }
            } );
        }

        @Override
        public void onAdCollapsed(final MaxAd ad)
        {
            dispatchAdViewCallback( "ad collapsed callback", adUnitId, generation, new Runnable()
            {
                @Override
                public void run()
                {
                    MaxDefoldPlugin.this.onAdCollapsed( ad );
                }
            } );
        }

        @Override
        public void onAdRevenuePaid(final MaxAd ad)
        {
            dispatchAdViewCallback( "ad revenue callback", adUnitId, generation, new Runnable()
            {
                @Override
                public void run()
                {
                    MaxDefoldPlugin.this.onAdRevenuePaid( ad );
                }
            } );
        }
    }

    // region Initialization
    public MaxDefoldPlugin(final Activity activity, final String engineVersion, final String pluginVersion)
    {
        gameActivity = new WeakReference<>( activity );
        this.pluginVersion = TextUtils.isEmpty( pluginVersion ) ? "unknown" : pluginVersion;
    }

    public boolean isInitialized()
    {
        return !destroyRequested && state == State.READY;
    }

    public void initialize(final String sdkKey)
    {
        runOnUiThread( "initialize", new ActivityAction()
        {
            @Override
            public void run(final Activity activity)
            {
                if ( state == State.INITIALIZING )
                {
                    d( "Ignoring initialize() while SDK initialization is already in progress" );
                    return;
                }

                if ( state == State.READY )
                {
                    d( "SDK is already initialized" );
                    sendDefoldEvent( "OnSdkInitializedEvent", getInitializationMessage() );
                    return;
                }

                final Context context = activity.getApplicationContext();
                final String sdkKeyToUse = resolveSdkKey( sdkKey, context );
                if ( TextUtils.isEmpty( sdkKeyToUse ) )
                {
                    e( "Unable to initialize AppLovin SDK: no SDK key was provided or found in AndroidManifest.xml" );
                    return;
                }

                d( "Initializing AppLovin MAX Defold v" + pluginVersion + "..." );

                try
                {
                    sdk = AppLovinSdk.getInstance( context );
                    applyCachedSettings( sdk.getSettings() );

                    AppLovinSdkInitializationConfiguration.Builder builder =
                            AppLovinSdkInitializationConfiguration.builder( sdkKeyToUse )
                                    .setMediationProvider( AppLovinMediationProvider.MAX )
                                    .setPluginVersion( "Defold-" + pluginVersion )
                                    .setExceptionHandlerEnabled( true );

                    if ( testDeviceAdvertisingIdsToSet != null )
                    {
                        builder.setTestDeviceAdvertisingIds( new ArrayList<>( testDeviceAdvertisingIdsToSet ) );
                    }

                    final long expectedLifecycleGeneration;
                    final long expectedInitializationGeneration;
                    synchronized ( lifecycleLock )
                    {
                        if ( destroyRequested || state == State.DESTROYED )
                        {
                            return;
                        }

                        expectedLifecycleGeneration = lifecycleGeneration;
                        expectedInitializationGeneration = ++initializationGeneration;
                        state = State.INITIALIZING;
                    }
                    startOrJoinSdkInitialization(
                            builder.build(),
                            expectedLifecycleGeneration,
                            expectedInitializationGeneration );
                }
                catch ( final Throwable throwable )
                {
                    synchronized ( lifecycleLock )
                    {
                        if ( !destroyRequested
                                && ( state == State.NEW || state == State.INITIALIZING ) )
                        {
                            ++initializationGeneration;
                            sdk = null;
                            sdkConfiguration = null;
                            state = State.NEW;
                        }
                    }
                    e( "Failed to initialize AppLovin SDK: " + Log.getStackTraceString( throwable ) );
                }
            }
        } );
    }

    private void completeSdkInitialization(
            final AppLovinSdkConfiguration configuration,
            final long expectedLifecycleGeneration,
            final long expectedInitializationGeneration)
    {
        synchronized ( lifecycleLock )
        {
            if ( destroyRequested
                    || state != State.INITIALIZING
                    || lifecycleGeneration != expectedLifecycleGeneration
                    || initializationGeneration != expectedInitializationGeneration )
            {
                return;
            }

            sdkConfiguration = configuration;
            state = State.READY;
        }
        d( "SDK initialized" );
        sendDefoldEvent( "OnSdkInitializedEvent", getInitializationMessage() );
    }

    private void startOrJoinSdkInitialization(
            final AppLovinSdkInitializationConfiguration initializationConfiguration,
            final long expectedLifecycleGeneration,
            final long expectedInitializationGeneration) throws Throwable
    {
        synchronized ( lifecycleLock )
        {
            if ( destroyRequested
                    || state != State.INITIALIZING
                    || lifecycleGeneration != expectedLifecycleGeneration
                    || initializationGeneration != expectedInitializationGeneration )
            {
                return;
            }
        }

        final boolean shouldInitialize;
        final boolean initializationComplete;
        final AppLovinSdkConfiguration completedConfiguration;
        final long expectedSharedInitializationGeneration;
        synchronized ( SHARED_INITIALIZATION_LOCK )
        {
            initializationComplete =
                    sharedInitializationState == SharedInitializationState.COMPLETE;
            completedConfiguration = sharedSdkConfiguration;
            if ( sharedInitializationState == SharedInitializationState.IDLE )
            {
                sharedInitializationState = SharedInitializationState.IN_PROGRESS;
                expectedSharedInitializationGeneration = ++sharedInitializationGeneration;
                shouldInitialize = true;
            }
            else
            {
                expectedSharedInitializationGeneration = sharedInitializationGeneration;
                shouldInitialize = false;
            }
        }

        if ( initializationComplete )
        {
            completeSdkInitialization(
                    completedConfiguration,
                    expectedLifecycleGeneration,
                    expectedInitializationGeneration );
            return;
        }

        if ( !shouldInitialize )
        {
            scheduleSharedInitializationWait(
                    initializationConfiguration,
                    expectedLifecycleGeneration,
                    expectedInitializationGeneration );
            return;
        }

        try
        {
            sdk.initialize( initializationConfiguration, new AppLovinSdk.SdkInitializationListener()
            {
                @Override
                public void onSdkInitialized(final AppLovinSdkConfiguration configuration)
                {
                    synchronized ( SHARED_INITIALIZATION_LOCK )
                    {
                        if ( sharedInitializationState != SharedInitializationState.IN_PROGRESS
                                || sharedInitializationGeneration
                                != expectedSharedInitializationGeneration )
                        {
                            return;
                        }

                        // Publish process-wide completion before checking this wrapper's lifecycle.
                        // A replacement wrapper can then finish even if this one was destroyed.
                        sharedSdkConfiguration = configuration;
                        sharedInitializationState = SharedInitializationState.COMPLETE;
                    }

                    runOnUiThread(
                            "complete SDK initialization",
                            expectedLifecycleGeneration,
                            new ActivityAction()
                            {
                                @Override
                                public void run(final Activity ignored)
                                {
                                    completeSdkInitialization(
                                            configuration,
                                            expectedLifecycleGeneration,
                                            expectedInitializationGeneration );
                                }
                            } );
                }
            } );
        }
        catch ( final Throwable throwable )
        {
            synchronized ( SHARED_INITIALIZATION_LOCK )
            {
                if ( sharedInitializationState == SharedInitializationState.IN_PROGRESS
                        && sharedInitializationGeneration
                        == expectedSharedInitializationGeneration )
                {
                    sharedInitializationState = SharedInitializationState.IDLE;
                    sharedSdkConfiguration = null;
                }
            }
            throw throwable;
        }
    }

    private void scheduleSharedInitializationWait(
            final AppLovinSdkInitializationConfiguration initializationConfiguration,
            final long expectedLifecycleGeneration,
            final long expectedInitializationGeneration)
    {
        synchronized ( lifecycleLock )
        {
            if ( destroyRequested
                    || state != State.INITIALIZING
                    || lifecycleGeneration != expectedLifecycleGeneration
                    || initializationGeneration != expectedInitializationGeneration )
            {
                return;
            }
        }

        mainHandler.postDelayed( new Runnable()
        {
            @Override
            public void run()
            {
                runOnUiThread(
                        "wait for shared SDK initialization",
                        expectedLifecycleGeneration,
                        new ActivityAction()
                        {
                            @Override
                            public void run(final Activity ignored)
                            {
                                synchronized ( lifecycleLock )
                                {
                                    if ( destroyRequested
                                            || state != State.INITIALIZING
                                            || lifecycleGeneration
                                            != expectedLifecycleGeneration
                                            || initializationGeneration
                                            != expectedInitializationGeneration )
                                    {
                                        return;
                                    }
                                }

                                try
                                {
                                    startOrJoinSdkInitialization(
                                            initializationConfiguration,
                                            expectedLifecycleGeneration,
                                            expectedInitializationGeneration );
                                }
                                catch ( final Throwable throwable )
                                {
                                    synchronized ( lifecycleLock )
                                    {
                                        if ( !destroyRequested
                                                && state == State.INITIALIZING
                                                && lifecycleGeneration
                                                == expectedLifecycleGeneration
                                                && initializationGeneration
                                                == expectedInitializationGeneration )
                                        {
                                            ++initializationGeneration;
                                            sdk = null;
                                            sdkConfiguration = null;
                                            state = State.NEW;
                                        }
                                    }
                                    e( "Failed to initialize AppLovin SDK: "
                                            + Log.getStackTraceString( throwable ) );
                                }
                            }
                        } );
            }
        }, SHARED_INITIALIZATION_WAIT_MILLIS );
    }

    private String resolveSdkKey(final String sdkKey, final Context context)
    {
        if ( !TextUtils.isEmpty( sdkKey ) )
        {
            return sdkKey;
        }

        try
        {
            final PackageManager packageManager = context.getPackageManager();
            final ApplicationInfo applicationInfo = packageManager.getApplicationInfo(
                    context.getPackageName(),
                    PackageManager.GET_META_DATA );
            final Bundle metaData = applicationInfo.metaData;
            return metaData != null ? metaData.getString( "applovin.sdk.key", "" ) : "";
        }
        catch ( final Throwable throwable )
        {
            e( "Unable to retrieve SDK key from AndroidManifest.xml: " + throwable );
            return "";
        }
    }

    private void applyCachedSettings(final AppLovinSdkSettings settings)
    {
        final AppLovinTermsAndPrivacyPolicyFlowSettings consentFlowSettings =
                settings.getTermsAndPrivacyPolicyFlowSettings();

        if ( termsAndPrivacyPolicyFlowEnabledToSet != null )
        {
            consentFlowSettings.setEnabled( termsAndPrivacyPolicyFlowEnabledToSet );
        }
        if ( privacyPolicyUriToSet != null )
        {
            consentFlowSettings.setPrivacyPolicyUri( privacyPolicyUriToSet );
        }
        if ( termsOfServiceUriToSet != null )
        {
            consentFlowSettings.setTermsOfServiceUri( termsOfServiceUriToSet );
        }
        if ( debugUserGeographyToSet != null )
        {
            consentFlowSettings.setDebugUserGeography(
                    getAppLovinConsentFlowUserGeography( debugUserGeographyToSet ) );
        }
        if ( userIdToSet != null )
        {
            settings.setUserIdentifier( userIdToSet );
        }
        if ( mutedToSet != null )
        {
            settings.setMuted( mutedToSet );
        }
        if ( verboseLoggingToSet != null )
        {
            settings.setVerboseLogging( verboseLoggingToSet );
        }
        if ( creativeDebuggerEnabledToSet != null )
        {
            settings.setCreativeDebuggerEnabled( creativeDebuggerEnabledToSet );
        }
    }

    private JSONObject getInitializationMessage()
    {
        final JSONObject message = new JSONObject();
        if ( sdkConfiguration != null )
        {
            put( message, "countryCode", emptyIfNull( sdkConfiguration.getCountryCode() ) );
            final ConsentFlowUserGeography geography = sdkConfiguration.getConsentFlowUserGeography();
            put( message, "consentFlowUserGeography", geography != null ? geography.ordinal() : 0 );
            put( message, "isTestModeEnabled", sdkConfiguration.isTestModeEnabled() );
        }
        return message;
    }

    public void showMediationDebugger()
    {
        runOnUiThread( "show mediation debugger", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                if ( !requireReady( "show mediation debugger" ) )
                {
                    return;
                }
                sdk.showMediationDebugger();
            }
        } );
    }

    /**
     * Releases all Java-side ad objects and listeners.
     *
     * JNI signature: destroy()V
     */
    public void destroy()
    {
        final FutureTask<Void> task;
        final boolean shouldSchedule;
        synchronized ( lifecycleLock )
        {
            if ( destroyTask == null )
            {
                destroyRequested = true;
                destroyTask = new FutureTask<>( new Callable<Void>()
                {
                    @Override
                    public Void call()
                    {
                        performDestroyOnUiThread();
                        return null;
                    }
                } );
                shouldSchedule = true;
            }
            else
            {
                shouldSchedule = false;
            }
            task = destroyTask;
        }

        if ( Looper.myLooper() == Looper.getMainLooper() )
        {
            task.run();
            return;
        }

        if ( shouldSchedule && !mainHandler.post( task ) )
        {
            // The main looper is already shutting down. Finish releasing Java references even
            // though window operations may no longer be serviced.
            task.run();
        }
        waitForDestroy( task );
    }

    private void performDestroyOnUiThread()
    {
        synchronized ( lifecycleLock )
        {
            state = State.DESTROYED;
            ++lifecycleGeneration;
            ++initializationGeneration;
        }

        final Activity activity = gameActivity.get();

        for ( final MaxInterstitialAd interstitial : new ArrayList<>( mInterstitials.values() ) )
        {
            try
            {
                interstitial.setListener( null );
                interstitial.setRevenueListener( null );
                interstitial.destroy();
            }
            catch ( final Throwable throwable )
            {
                e( "Failed to destroy interstitial: " + throwable );
            }
        }
        mInterstitials.clear();

        for ( final MaxRewardedAd rewardedAd : new ArrayList<>( mRewardedAds.values() ) )
        {
            try
            {
                rewardedAd.setListener( null );
                rewardedAd.setRevenueListener( null );
                rewardedAd.destroy();
            }
            catch ( final Throwable throwable )
            {
                e( "Failed to destroy rewarded ad: " + throwable );
            }
        }
        mRewardedAds.clear();

        for ( final MaxAdView adView : new ArrayList<>( mAdViews.values() ) )
        {
            try
            {
                removeAndDestroyAdView( adView, activity );
            }
            catch ( final Throwable throwable )
            {
                e( "Failed to destroy ad view: " + throwable );
            }
        }
        mAdViews.clear();
        mAdViewAdFormats.clear();
        mAdViewPlacements.clear();
        mAdViewExtraParameters.clear();
        mAdViewPositions.clear();
        mAdViewGenerations.clear();
        mAdUnitIdsToShowAfterCreate.clear();
        mAdUnitIdsWithStoppedAutoRefresh.clear();

        sdk = null;
        sdkConfiguration = null;
        userIdToSet = null;
        mutedToSet = null;
        testDeviceAdvertisingIdsToSet = null;
        verboseLoggingToSet = null;
        creativeDebuggerEnabledToSet = null;
        termsAndPrivacyPolicyFlowEnabledToSet = null;
        privacyPolicyUriToSet = null;
        termsOfServiceUriToSet = null;
        debugUserGeographyToSet = null;
        gameActivity.clear();
    }

    private void waitForDestroy(final FutureTask<Void> task)
    {
        boolean interrupted = false;
        while ( !task.isDone() )
        {
            try
            {
                task.get();
            }
            catch ( final InterruptedException exception )
            {
                interrupted = true;
            }
            catch ( final Throwable throwable )
            {
                e( "Failed to finish MAX teardown: " + throwable );
                break;
            }
        }
        if ( interrupted )
        {
            Thread.currentThread().interrupt();
        }
    }
    // endregion

    // region Privacy
    public void setHasUserConsent(final boolean hasUserConsent)
    {
        runOnUiThread( "set user consent", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                AppLovinPrivacySettings.setHasUserConsent( hasUserConsent );
            }
        } );
    }

    public boolean hasUserConsent()
    {
        return callOnUiThread( "get user consent", false, new ActivityCallable<Boolean>()
        {
            @Override
            public Boolean call(final Activity ignored)
            {
                return AppLovinPrivacySettings.hasUserConsent();
            }
        } );
    }

    public void setDoNotSell(final boolean doNotSell)
    {
        runOnUiThread( "set do-not-sell", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                AppLovinPrivacySettings.setDoNotSell( doNotSell );
            }
        } );
    }

    public boolean isDoNotSell()
    {
        return callOnUiThread( "get do-not-sell", false, new ActivityCallable<Boolean>()
        {
            @Override
            public Boolean call(final Activity ignored)
            {
                return AppLovinPrivacySettings.isDoNotSell();
            }
        } );
    }
    // endregion

    // region General
    public boolean isTablet()
    {
        return callOnUiThread( "check tablet form factor", false, new ActivityCallable<Boolean>()
        {
            @Override
            public Boolean call(final Activity activity)
            {
                return AppLovinSdkUtils.isTablet( activity );
            }
        } );
    }

    public void setUserId(final String userId)
    {
        runOnUiThread( "set user ID", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                userIdToSet = userId;
                if ( sdk != null )
                {
                    sdk.getSettings().setUserIdentifier( userId );
                }
            }
        } );
    }

    public void setMuted(final boolean muted)
    {
        runOnUiThread( "set muted", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                mutedToSet = muted;
                if ( sdk != null )
                {
                    sdk.getSettings().setMuted( muted );
                }
            }
        } );
    }

    public boolean isMuted()
    {
        return callOnUiThread( "get muted", false, new ActivityCallable<Boolean>()
        {
            @Override
            public Boolean call(final Activity ignored)
            {
                return sdk != null ? sdk.getSettings().isMuted() : mutedToSet != null && mutedToSet;
            }
        } );
    }

    public void setVerboseLoggingEnabled(final boolean enabled)
    {
        runOnUiThread( "set verbose logging", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                verboseLoggingToSet = enabled;
                if ( sdk != null )
                {
                    sdk.getSettings().setVerboseLogging( enabled );
                }
            }
        } );
    }

    public boolean isVerboseLoggingEnabled()
    {
        return callOnUiThread(
                "get verbose logging",
                false,
                new ActivityCallable<Boolean>()
                {
                    @Override
                    public Boolean call(final Activity ignored)
                    {
                        return sdk != null
                                ? sdk.getSettings().isVerboseLoggingEnabled()
                                : verboseLoggingToSet != null && verboseLoggingToSet;
                    }
                } );
    }

    public void setCreativeDebuggerEnabled(final boolean enabled)
    {
        runOnUiThread( "set creative debugger", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                creativeDebuggerEnabledToSet = enabled;
                if ( sdk != null )
                {
                    sdk.getSettings().setCreativeDebuggerEnabled( enabled );
                }
            }
        } );
    }

    public void setTestDeviceAdvertisingIds(final String[] advertisingIds)
    {
        final List<String> advertisingIdList = advertisingIds == null
                ? Collections.<String>emptyList()
                : new ArrayList<>( Arrays.asList( advertisingIds ) );

        runOnUiThread( "set test device advertising IDs", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                if ( state != State.NEW )
                {
                    e( "Test device advertising IDs must be set before initialize()" );
                    return;
                }
                testDeviceAdvertisingIdsToSet = advertisingIdList;
            }
        } );
    }
    // endregion

    // region Terms and Privacy Policy Flow
    public void setTermsAndPrivacyPolicyFlowEnabled(final boolean enabled)
    {
        runOnUiThread( "set terms and privacy policy flow", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                termsAndPrivacyPolicyFlowEnabledToSet = enabled;
                if ( sdk != null )
                {
                    sdk.getSettings().getTermsAndPrivacyPolicyFlowSettings().setEnabled( enabled );
                }
            }
        } );
    }

    public void setPrivacyPolicyUrl(final String urlString)
    {
        runOnUiThread( "set privacy policy URL", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                privacyPolicyUriToSet = Uri.parse( urlString );
                if ( sdk != null )
                {
                    sdk.getSettings().getTermsAndPrivacyPolicyFlowSettings()
                            .setPrivacyPolicyUri( privacyPolicyUriToSet );
                }
            }
        } );
    }

    public void setTermsOfServiceUrl(final String urlString)
    {
        runOnUiThread( "set terms of service URL", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                termsOfServiceUriToSet = Uri.parse( urlString );
                if ( sdk != null )
                {
                    sdk.getSettings().getTermsAndPrivacyPolicyFlowSettings()
                            .setTermsOfServiceUri( termsOfServiceUriToSet );
                }
            }
        } );
    }

    public void setConsentFlowDebugUserGeography(final String userGeography)
    {
        runOnUiThread( "set consent flow debug geography", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                debugUserGeographyToSet = userGeography;
                if ( sdk != null )
                {
                    sdk.getSettings().getTermsAndPrivacyPolicyFlowSettings().setDebugUserGeography(
                            getAppLovinConsentFlowUserGeography( userGeography ) );
                }
            }
        } );
    }

    public void showCmpForExistingUser()
    {
        runOnUiThread( "show CMP for existing user", new ActivityAction()
        {
            @Override
            public void run(final Activity activity)
            {
                if ( !requireReady( "show CMP for existing user" ) )
                {
                    return;
                }
                sdk.getCmpService().showCmpForExistingUser( activity, MaxDefoldPlugin.this );
            }
        } );
    }

    public boolean hasSupportedCmp()
    {
        return callOnUiThread( "check supported CMP", false, new ActivityCallable<Boolean>()
        {
            @Override
            public Boolean call(final Activity ignored)
            {
                return state == State.READY && sdk != null && sdk.getCmpService().hasSupportedCmp();
            }
        } );
    }

    @Override
    public void onCompleted(final AppLovinCmpError error)
    {
        if ( repostCallbackToUi( "CMP completion callback", new Runnable()
        {
            @Override
            public void run()
            {
                onCompleted( error );
            }
        } ) || !canHandleCallback() )
        {
            return;
        }

        handleCmpCompletion( error );
    }

    private void handleCmpCompletion(final AppLovinCmpError error)
    {
        if ( !canHandleCallback() )
        {
            return;
        }

        final JSONObject params = new JSONObject();
        if ( error != null )
        {
            put( params, "code", error.getCode().getValue() );
            put( params, "message", emptyIfNull( error.getMessage() ) );
            put( params, "cmpCode", error.getCmpCode() );
            put( params, "cmpMessage", emptyIfNull( error.getCmpMessage() ) );
        }
        sendDefoldEvent( "OnCmpCompletedEvent", params );
    }
    // endregion

    // region Event Tracking
    public void trackEvent(final String event, final String parameters)
    {
        final Map<String, Object> deserialized = deserialize( parameters );
        runOnUiThread( "track event", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                if ( requireReady( "track event" ) )
                {
                    sdk.getEventService().trackEvent( event, deserialized );
                }
            }
        } );
    }
    // endregion

    // region Interstitials
    public void loadInterstitial(final String adUnitId)
    {
        runOnUiThread( "load interstitial", new ActivityAction()
        {
            @Override
            public void run(final Activity activity)
            {
                if ( requireReady( "load interstitial" ) )
                {
                    retrieveInterstitial( adUnitId, activity ).loadAd();
                }
            }
        } );
    }

    public boolean isInterstitialReady(final String adUnitId)
    {
        return callOnUiThread( "check interstitial readiness", false, new ActivityCallable<Boolean>()
        {
            @Override
            public Boolean call(final Activity ignored)
            {
                final MaxInterstitialAd interstitial = mInterstitials.get( adUnitId );
                return state == State.READY && interstitial != null && interstitial.isReady();
            }
        } );
    }

    public void showInterstitial(final String adUnitId, final String placement)
    {
        runOnUiThread( "show interstitial", new ActivityAction()
        {
            @Override
            public void run(final Activity activity)
            {
                if ( requireReady( "show interstitial" ) )
                {
                    retrieveInterstitial( adUnitId, activity ).showAd( placement, activity );
                }
            }
        } );
    }

    public void setInterstitialExtraParameter(
            final String adUnitId,
            final String key,
            final String value)
    {
        runOnUiThread( "set interstitial extra parameter", new ActivityAction()
        {
            @Override
            public void run(final Activity activity)
            {
                if ( requireReady( "set interstitial extra parameter" ) )
                {
                    retrieveInterstitial( adUnitId, activity ).setExtraParameter( key, value );
                }
            }
        } );
    }
    // endregion

    // region Rewarded
    public void loadRewardedAd(final String adUnitId)
    {
        runOnUiThread( "load rewarded ad", new ActivityAction()
        {
            @Override
            public void run(final Activity activity)
            {
                if ( requireReady( "load rewarded ad" ) )
                {
                    retrieveRewardedAd( adUnitId, activity ).loadAd();
                }
            }
        } );
    }

    public boolean isRewardedAdReady(final String adUnitId)
    {
        return callOnUiThread( "check rewarded ad readiness", false, new ActivityCallable<Boolean>()
        {
            @Override
            public Boolean call(final Activity ignored)
            {
                final MaxRewardedAd rewardedAd = mRewardedAds.get( adUnitId );
                return state == State.READY && rewardedAd != null && rewardedAd.isReady();
            }
        } );
    }

    public void showRewardedAd(final String adUnitId, final String placement)
    {
        runOnUiThread( "show rewarded ad", new ActivityAction()
        {
            @Override
            public void run(final Activity activity)
            {
                if ( requireReady( "show rewarded ad" ) )
                {
                    retrieveRewardedAd( adUnitId, activity ).showAd( placement, activity );
                }
            }
        } );
    }

    public void setRewardedAdExtraParameter(
            final String adUnitId,
            final String key,
            final String value)
    {
        runOnUiThread( "set rewarded ad extra parameter", new ActivityAction()
        {
            @Override
            public void run(final Activity activity)
            {
                if ( requireReady( "set rewarded ad extra parameter" ) )
                {
                    retrieveRewardedAd( adUnitId, activity ).setExtraParameter( key, value );
                }
            }
        } );
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
        setAdViewExtraParameter( adUnitId, getDeviceSpecificBannerAdViewAdFormat(), key, value );
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

    // region MRECs
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
        setAdViewExtraParameter( adUnitId, MaxAdFormat.MREC, key, value );
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
    public void onAdLoaded(final MaxAd ad)
    {
        if ( repostCallbackToUi( "ad loaded callback", new Runnable()
        {
            @Override
            public void run()
            {
                onAdLoaded( ad );
            }
        } ) || !canHandleCallback() )
        {
            return;
        }

        final String name;
        final MaxAdFormat adFormat = ad.getFormat();
        if ( adFormat.isAdViewAd() )
        {
            name = MaxAdFormat.MREC == adFormat
                    ? "OnMRecAdLoadedEvent"
                    : "OnBannerAdLoadedEvent";

            if ( !TextUtils.isEmpty( mAdViewPositions.get( ad.getAdUnitId() ) ) )
            {
                positionAdView( ad.getAdUnitId(), adFormat, gameActivity.get() );
            }

            final MaxAdView adView = mAdViews.get( ad.getAdUnitId() );
            if ( adView != null && !isAdViewVisible( adView ) )
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
        if ( repostCallbackToUi( "ad load failed callback", new Runnable()
        {
            @Override
            public void run()
            {
                onAdLoadFailed( adUnitId, error );
            }
        } ) || !canHandleCallback() )
        {
            return;
        }

        if ( TextUtils.isEmpty( adUnitId ) )
        {
            logStackTrace( new IllegalArgumentException( "adUnitId cannot be null or empty" ) );
            return;
        }

        final String name;
        if ( mAdViews.containsKey( adUnitId ) )
        {
            name = MaxAdFormat.MREC == mAdViewAdFormats.get( adUnitId )
                    ? "OnMRecAdLoadFailedEvent"
                    : "OnBannerAdLoadFailedEvent";
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
            logStackTrace( new IllegalStateException( "Invalid ad unit ID: " + adUnitId ) );
            return;
        }

        final JSONObject params = getLoadErrorInfo( error );
        put( params, "adUnitIdentifier", adUnitId );
        sendDefoldEvent( name, params );
    }

    @Override
    public void onAdClicked(final MaxAd ad)
    {
        if ( repostCallbackToUi( "ad clicked callback", new Runnable()
        {
            @Override
            public void run()
            {
                onAdClicked( ad );
            }
        } ) || !canHandleCallback() )
        {
            return;
        }

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
        if ( repostCallbackToUi( "ad displayed callback", new Runnable()
        {
            @Override
            public void run()
            {
                onAdDisplayed( ad );
            }
        } ) || !canHandleCallback() )
        {
            return;
        }

        final MaxAdFormat adFormat = ad.getFormat();
        if ( adFormat == MaxAdFormat.INTERSTITIAL )
        {
            sendDefoldEvent( "OnInterstitialAdDisplayedEvent", getAdInfo( ad ) );
        }
        else if ( adFormat == MaxAdFormat.REWARDED )
        {
            sendDefoldEvent( "OnRewardedAdDisplayedEvent", getAdInfo( ad ) );
        }
    }

    @Override
    public void onAdDisplayFailed(final MaxAd ad, final MaxError error)
    {
        if ( repostCallbackToUi( "ad display failed callback", new Runnable()
        {
            @Override
            public void run()
            {
                onAdDisplayFailed( ad, error );
            }
        } ) || !canHandleCallback() )
        {
            return;
        }

        final MaxAdFormat adFormat = ad.getFormat();
        final String name;
        if ( adFormat == MaxAdFormat.INTERSTITIAL )
        {
            name = "OnInterstitialAdDisplayFailedEvent";
        }
        else if ( adFormat == MaxAdFormat.REWARDED )
        {
            name = "OnRewardedAdDisplayFailedEvent";
        }
        else
        {
            return;
        }

        final JSONObject params = getDisplayErrorInfo( error );
        merge( params, getAdInfo( ad ) );
        sendDefoldEvent( name, params );
    }

    @Override
    public void onAdHidden(final MaxAd ad)
    {
        if ( repostCallbackToUi( "ad hidden callback", new Runnable()
        {
            @Override
            public void run()
            {
                onAdHidden( ad );
            }
        } ) || !canHandleCallback() )
        {
            return;
        }

        final MaxAdFormat adFormat = ad.getFormat();
        if ( adFormat == MaxAdFormat.INTERSTITIAL )
        {
            sendDefoldEvent( "OnInterstitialAdHiddenEvent", getAdInfo( ad ) );
        }
        else if ( adFormat == MaxAdFormat.REWARDED )
        {
            sendDefoldEvent( "OnRewardedAdHiddenEvent", getAdInfo( ad ) );
        }
    }

    @Override
    public void onAdExpanded(final MaxAd ad)
    {
        if ( repostCallbackToUi( "ad expanded callback", new Runnable()
        {
            @Override
            public void run()
            {
                onAdExpanded( ad );
            }
        } ) || !canHandleCallback() )
        {
            return;
        }

        final MaxAdFormat adFormat = ad.getFormat();
        if ( !adFormat.isAdViewAd() )
        {
            logInvalidAdFormat( adFormat );
            return;
        }
        sendDefoldEvent(
                MaxAdFormat.MREC == adFormat
                        ? "OnMRecAdExpandedEvent"
                        : "OnBannerAdExpandedEvent",
                getAdInfo( ad ) );
    }

    @Override
    public void onAdCollapsed(final MaxAd ad)
    {
        if ( repostCallbackToUi( "ad collapsed callback", new Runnable()
        {
            @Override
            public void run()
            {
                onAdCollapsed( ad );
            }
        } ) || !canHandleCallback() )
        {
            return;
        }

        final MaxAdFormat adFormat = ad.getFormat();
        if ( !adFormat.isAdViewAd() )
        {
            logInvalidAdFormat( adFormat );
            return;
        }
        sendDefoldEvent(
                MaxAdFormat.MREC == adFormat
                        ? "OnMRecAdCollapsedEvent"
                        : "OnBannerAdCollapsedEvent",
                getAdInfo( ad ) );
    }

    @Override
    public void onUserRewarded(final MaxAd ad, final MaxReward reward)
    {
        if ( repostCallbackToUi( "user rewarded callback", new Runnable()
        {
            @Override
            public void run()
            {
                onUserRewarded( ad, reward );
            }
        } ) || !canHandleCallback() )
        {
            return;
        }

        if ( ad.getFormat() != MaxAdFormat.REWARDED )
        {
            logInvalidAdFormat( ad.getFormat() );
            return;
        }

        final JSONObject params = getAdInfo( ad );
        put( params, "label", reward != null ? emptyIfNull( reward.getLabel() ) : "" );
        put( params, "amount", reward != null ? reward.getAmount() : 0 );
        sendDefoldEvent( "OnRewardedAdReceivedRewardEvent", params );
    }

    @Override
    public void onAdRevenuePaid(final MaxAd ad)
    {
        if ( repostCallbackToUi( "ad revenue callback", new Runnable()
        {
            @Override
            public void run()
            {
                onAdRevenuePaid( ad );
            }
        } ) || !canHandleCallback() )
        {
            return;
        }

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
    // endregion

    // region Internal Ad Methods
    private void createAdView(
            final String adUnitId,
            final MaxAdFormat adFormat,
            final String adViewPosition)
    {
        runOnUiThread( "create " + adFormat.getLabel(), new ActivityAction()
        {
            @Override
            public void run(final Activity activity)
            {
                if ( !requireReady( "create " + adFormat.getLabel() ) )
                {
                    return;
                }

                d( "Creating " + adFormat.getLabel() + " with ad unit ID \"" + adUnitId
                        + "\" at position \"" + adViewPosition + "\"" );

                final MaxAdView existingAdView = mAdViews.get( adUnitId );
                if ( existingAdView != null )
                {
                    final String previousPosition = mAdViewPositions.get( adUnitId );
                    if ( !TextUtils.isEmpty( adViewPosition )
                            && !adViewPosition.equals( previousPosition ) )
                    {
                        mAdViewPositions.put( adUnitId, adViewPosition );
                        positionAdView(
                                adUnitId,
                                getEffectiveAdViewAdFormat( adUnitId, adFormat ),
                                activity );
                    }
                    return;
                }

                final MaxAdFormat creationAdFormat =
                        getAdViewAdFormatForCreation( adUnitId, adFormat, activity );
                final MaxAdView adView = retrieveAdView(
                        adUnitId,
                        creationAdFormat,
                        adViewPosition,
                        true );
                if ( adView == null )
                {
                    return;
                }

                final MaxAdFormat effectiveAdFormat =
                        getEffectiveAdViewAdFormat( adUnitId, creationAdFormat );
                final Long creationGeneration = mAdViewGenerations.get( adUnitId );
                try
                {
                    if ( adView.getParent() == null )
                    {
                        final RelativeLayout container = new RelativeLayout( activity );
                        container.setVisibility( View.GONE );
                        container.addView( adView );

                        final WindowManager.LayoutParams layoutParams =
                                new WindowManager.LayoutParams();
                        layoutParams.width = WindowManager.LayoutParams.WRAP_CONTENT;
                        layoutParams.height = WindowManager.LayoutParams.WRAP_CONTENT;
                        layoutParams.flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                                | WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
                        activity.getWindowManager().addView( container, layoutParams );

                        positionAdView( adUnitId, effectiveAdFormat, activity );
                    }
                }
                catch ( final Throwable throwable )
                {
                    rollbackCreatedAdView(
                            adUnitId,
                            adView,
                            creationGeneration,
                            activity );
                    throw throwable;
                }

                if ( mAdUnitIdsToShowAfterCreate.remove( adUnitId ) )
                {
                    showAdViewNow( adUnitId, effectiveAdFormat );
                }

                // Defer the first load by one UI turn so immediately following placement and
                // extra-parameter calls are applied to the request.
                postOnUiThread( "load " + effectiveAdFormat.getLabel(), new ActivityAction()
                {
                    @Override
                    public void run(final Activity ignored)
                    {
                        if ( requireReady( "load " + effectiveAdFormat.getLabel() )
                                && mAdViews.get( adUnitId ) == adView )
                        {
                            adView.loadAd();
                        }
                    }
                } );
            }
        } );
    }

    private void setAdViewPlacement(
            final String adUnitId,
            final MaxAdFormat adFormat,
            final String placement)
    {
        runOnUiThread( "set ad view placement", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                final MaxAdFormat effectiveAdFormat =
                        getEffectiveAdViewAdFormat( adUnitId, adFormat );
                mAdViewPlacements.put( adUnitId, placement );
                final MaxAdView adView = retrieveAdView(
                        adUnitId,
                        effectiveAdFormat,
                        null,
                        false );
                if ( adView == null )
                {
                    return;
                }
                adView.setPlacement( placement );
            }
        } );
    }

    private void updateAdViewPosition(
            final String adUnitId,
            final String adViewPosition,
            final MaxAdFormat adFormat)
    {
        runOnUiThread( "update ad view position", new ActivityAction()
        {
            @Override
            public void run(final Activity activity)
            {
                final MaxAdFormat effectiveAdFormat =
                        getEffectiveAdViewAdFormat( adUnitId, adFormat );
                final MaxAdView adView = retrieveAdView(
                        adUnitId,
                        effectiveAdFormat,
                        null,
                        false );
                if ( adView == null )
                {
                    logMissingAdView( adUnitId, effectiveAdFormat );
                    return;
                }

                final String previousPosition = mAdViewPositions.get( adUnitId );
                if ( adViewPosition == null || adViewPosition.equals( previousPosition ) )
                {
                    return;
                }

                mAdViewPositions.put( adUnitId, adViewPosition );
                positionAdView( adUnitId, effectiveAdFormat, activity );
            }
        } );
    }

    private void showAdView(final String adUnitId, final MaxAdFormat adFormat)
    {
        runOnUiThread( "show ad view", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                showAdViewNow( adUnitId, adFormat );
            }
        } );
    }

    private void showAdViewNow(final String adUnitId, final MaxAdFormat adFormat)
    {
        final MaxAdFormat effectiveAdFormat =
                getEffectiveAdViewAdFormat( adUnitId, adFormat );
        final MaxAdView adView = retrieveAdView(
                adUnitId,
                effectiveAdFormat,
                null,
                false );
        if ( adView == null )
        {
            mAdUnitIdsToShowAfterCreate.add( adUnitId );
            return;
        }

        adView.setVisibility( View.VISIBLE );
        final ViewParent parent = adView.getParent();
        if ( parent instanceof View )
        {
            ( (View) parent ).setVisibility( View.VISIBLE );
        }
        if ( !mAdUnitIdsWithStoppedAutoRefresh.contains( adUnitId ) )
        {
            adView.startAutoRefresh();
        }
    }

    private void hideAdView(final String adUnitId, final MaxAdFormat adFormat)
    {
        runOnUiThread( "hide ad view", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                mAdUnitIdsToShowAfterCreate.remove( adUnitId );
                final MaxAdFormat effectiveAdFormat =
                        getEffectiveAdViewAdFormat( adUnitId, adFormat );
                final MaxAdView adView = retrieveAdView(
                        adUnitId,
                        effectiveAdFormat,
                        null,
                        false );
                if ( adView == null )
                {
                    logMissingAdView( adUnitId, effectiveAdFormat );
                    return;
                }

                final ViewParent parent = adView.getParent();
                if ( parent instanceof View )
                {
                    ( (View) parent ).setVisibility( View.GONE );
                }
                adView.stopAutoRefresh();
            }
        } );
    }

    private void destroyAdView(final String adUnitId, final MaxAdFormat adFormat)
    {
        runOnUiThread( "destroy ad view", new ActivityAction()
        {
            @Override
            public void run(final Activity activity)
            {
                mAdUnitIdsToShowAfterCreate.remove( adUnitId );
                mAdUnitIdsWithStoppedAutoRefresh.remove( adUnitId );
                mAdViewPlacements.remove( adUnitId );
                mAdViewExtraParameters.remove( adUnitId );
                mAdViewGenerations.remove( adUnitId );
                final MaxAdFormat effectiveAdFormat =
                        getEffectiveAdViewAdFormat( adUnitId, adFormat );
                final MaxAdView adView = retrieveAdView(
                        adUnitId,
                        effectiveAdFormat,
                        null,
                        false );
                if ( adView == null )
                {
                    logMissingAdView( adUnitId, effectiveAdFormat );
                    return;
                }

                removeAndDestroyAdView( adView, activity );
                mAdViews.remove( adUnitId );
                mAdViewAdFormats.remove( adUnitId );
                mAdViewPositions.remove( adUnitId );
            }
        } );
    }

    private void removeAndDestroyAdView(final MaxAdView adView, final Activity activity)
    {
        try
        {
            final ViewParent parent = adView.getParent();
            if ( parent instanceof ViewGroup )
            {
                final View parentView = (View) parent;
                Activity windowActivity = activity;
                if ( windowActivity == null && parentView.getContext() instanceof Activity )
                {
                    windowActivity = (Activity) parentView.getContext();
                }

                if ( windowActivity != null )
                {
                    try
                    {
                        // The container can be registered with WindowManager before its first
                        // traversal assigns a window token, so removal must not depend on one.
                        windowActivity.getWindowManager().removeView( parentView );
                    }
                    catch ( final Throwable windowRemovalThrowable )
                    {
                        if ( !( windowRemovalThrowable instanceof IllegalArgumentException ) )
                        {
                            e( "Failed to remove ad view container from its window: "
                                    + windowRemovalThrowable );
                        }
                        ( (ViewGroup) parent ).removeView( adView );
                    }
                }
                else
                {
                    ( (ViewGroup) parent ).removeView( adView );
                }
            }
        }
        catch ( final Throwable throwable )
        {
            e( "Failed to remove ad view from its window: " + throwable );
        }
        finally
        {
            try
            {
                adView.setListener( null );
                adView.setRevenueListener( null );
                adView.destroy();
            }
            catch ( final Throwable throwable )
            {
                e( "Failed to destroy ad view: " + throwable );
            }
        }
    }

    private void rollbackCreatedAdView(
            final String adUnitId,
            final MaxAdView adView,
            final Long expectedGeneration,
            final Activity activity)
    {
        if ( mAdViews.get( adUnitId ) != adView
                || expectedGeneration == null
                || !expectedGeneration.equals( mAdViewGenerations.get( adUnitId ) ) )
        {
            return;
        }

        mAdViews.remove( adUnitId );
        mAdViewAdFormats.remove( adUnitId );
        mAdViewPositions.remove( adUnitId );
        mAdViewGenerations.remove( adUnitId );
        removeAndDestroyAdView( adView, activity );
    }

    private void setAdViewBackgroundColor(
            final String adUnitId,
            final MaxAdFormat adFormat,
            final String hexColorCode)
    {
        runOnUiThread( "set ad view background color", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                final MaxAdFormat effectiveAdFormat =
                        getEffectiveAdViewAdFormat( adUnitId, adFormat );
                final MaxAdView adView = retrieveAdView(
                        adUnitId,
                        effectiveAdFormat,
                        null,
                        false );
                if ( adView == null )
                {
                    logMissingAdView( adUnitId, effectiveAdFormat );
                    return;
                }

                try
                {
                    adView.setBackgroundColor( Color.parseColor( hexColorCode ) );
                }
                catch ( final IllegalArgumentException exception )
                {
                    e( "Invalid ad view color \"" + hexColorCode + "\": " + exception.getMessage() );
                }
            }
        } );
    }

    private void setAdViewExtraParameter(
            final String adUnitId,
            final MaxAdFormat adFormat,
            final String key,
            final String value)
    {
        runOnUiThread( "set ad view extra parameter", new ActivityAction()
        {
            @Override
            public void run(final Activity activity)
            {
                final MaxAdFormat effectiveAdFormat =
                        getEffectiveAdViewAdFormat( adUnitId, adFormat );
                cacheAdViewExtraParameter( adUnitId, key, value );
                final MaxAdView adView = retrieveAdView(
                        adUnitId,
                        effectiveAdFormat,
                        null,
                        false );
                if ( adView == null )
                {
                    return;
                }

                adView.setExtraParameter( key, value );
                if ( "force_banner".equalsIgnoreCase( key )
                        && MaxAdFormat.MREC != effectiveAdFormat )
                {
                    final MaxAdFormat forcedAdFormat = Boolean.parseBoolean( value )
                            ? MaxAdFormat.BANNER
                            : getDeviceSpecificBannerAdViewAdFormat( activity );
                    mAdViewAdFormats.put( adUnitId, forcedAdFormat );
                    positionAdView( adUnitId, forcedAdFormat, activity );
                }
            }
        } );
    }

    private void startAutoRefresh(final String adUnitId, final MaxAdFormat adFormat)
    {
        runOnUiThread( "start ad view auto-refresh", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                mAdUnitIdsWithStoppedAutoRefresh.remove( adUnitId );
                final MaxAdFormat effectiveAdFormat =
                        getEffectiveAdViewAdFormat( adUnitId, adFormat );
                final MaxAdView adView = retrieveAdView(
                        adUnitId,
                        effectiveAdFormat,
                        null,
                        false );
                if ( adView == null )
                {
                    logMissingAdView( adUnitId, effectiveAdFormat );
                    return;
                }
                if ( isAdViewVisible( adView ) )
                {
                    adView.startAutoRefresh();
                }
            }
        } );
    }

    private void stopAutoRefresh(final String adUnitId, final MaxAdFormat adFormat)
    {
        runOnUiThread( "stop ad view auto-refresh", new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                mAdUnitIdsWithStoppedAutoRefresh.add( adUnitId );
                final MaxAdFormat effectiveAdFormat =
                        getEffectiveAdViewAdFormat( adUnitId, adFormat );
                final MaxAdView adView = retrieveAdView(
                        adUnitId,
                        effectiveAdFormat,
                        null,
                        false );
                if ( adView == null )
                {
                    logMissingAdView( adUnitId, effectiveAdFormat );
                    return;
                }
                adView.stopAutoRefresh();
            }
        } );
    }

    private MaxInterstitialAd retrieveInterstitial(
            final String adUnitId,
            final Activity activity)
    {
        MaxInterstitialAd result = mInterstitials.get( adUnitId );
        if ( result == null )
        {
            result = new MaxInterstitialAd( adUnitId );
            result.setListener( this );
            result.setRevenueListener( this );
            mInterstitials.put( adUnitId, result );
        }
        return result;
    }

    private MaxRewardedAd retrieveRewardedAd(
            final String adUnitId,
            final Activity activity)
    {
        MaxRewardedAd result = mRewardedAds.get( adUnitId );
        if ( result == null )
        {
            result = MaxRewardedAd.getInstance( adUnitId );
            result.setListener( this );
            result.setRevenueListener( this );
            mRewardedAds.put( adUnitId, result );
        }
        return result;
    }

    private MaxAdView retrieveAdView(
            final String adUnitId,
            final MaxAdFormat adFormat,
            final String adViewPosition,
            final boolean createIfMissing)
    {
        MaxAdView result = mAdViews.get( adUnitId );
        if ( result == null && createIfMissing )
        {
            result = new MaxAdView( adUnitId, adFormat );
            final long generation = ++nextAdViewGeneration;
            final AdViewListener listener = new AdViewListener( adUnitId, generation );
            result.setListener( listener );
            result.setRevenueListener( listener );
            result.setExtraParameter( "allow_pause_auto_refresh_immediately", "true" );
            final Map<String, String> extraParameters = mAdViewExtraParameters.get( adUnitId );
            if ( extraParameters != null )
            {
                for ( final Map.Entry<String, String> entry : extraParameters.entrySet() )
                {
                    result.setExtraParameter( entry.getKey(), entry.getValue() );
                }
            }
            result.setBackgroundColor( Color.TRANSPARENT );
            final String placement = mAdViewPlacements.get( adUnitId );
            if ( placement != null )
            {
                result.setPlacement( placement );
            }
            mAdViews.put( adUnitId, result );
            mAdViewAdFormats.put( adUnitId, adFormat );
            mAdViewPositions.put( adUnitId, adViewPosition );
            mAdViewGenerations.put( adUnitId, generation );
        }
        return result;
    }

    private MaxAdFormat getEffectiveAdViewAdFormat(
            final String adUnitId,
            final MaxAdFormat requestedAdFormat)
    {
        final MaxAdFormat effectiveAdFormat = mAdViewAdFormats.get( adUnitId );
        return effectiveAdFormat != null ? effectiveAdFormat : requestedAdFormat;
    }

    private MaxAdFormat getAdViewAdFormatForCreation(
            final String adUnitId,
            final MaxAdFormat requestedAdFormat,
            final Activity activity)
    {
        if ( MaxAdFormat.MREC == requestedAdFormat )
        {
            return requestedAdFormat;
        }

        final String forceBanner = getCachedAdViewExtraParameter( adUnitId, "force_banner" );
        if ( forceBanner == null )
        {
            return requestedAdFormat;
        }
        return Boolean.parseBoolean( forceBanner )
                ? MaxAdFormat.BANNER
                : getDeviceSpecificBannerAdViewAdFormat( activity );
    }

    private void cacheAdViewExtraParameter(
            final String adUnitId,
            final String key,
            final String value)
    {
        Map<String, String> extraParameters = mAdViewExtraParameters.get( adUnitId );
        if ( extraParameters == null )
        {
            extraParameters = new HashMap<>( 2 );
            mAdViewExtraParameters.put( adUnitId, extraParameters );
        }

        if ( "force_banner".equalsIgnoreCase( key ) )
        {
            String previousKey = null;
            for ( final String existingKey : extraParameters.keySet() )
            {
                if ( "force_banner".equalsIgnoreCase( existingKey ) )
                {
                    previousKey = existingKey;
                    break;
                }
            }
            if ( previousKey != null )
            {
                extraParameters.remove( previousKey );
            }
        }
        extraParameters.put( key, value );
    }

    private String getCachedAdViewExtraParameter(
            final String adUnitId,
            final String requestedKey)
    {
        final Map<String, String> extraParameters = mAdViewExtraParameters.get( adUnitId );
        if ( extraParameters == null )
        {
            return null;
        }
        for ( final Map.Entry<String, String> entry : extraParameters.entrySet() )
        {
            if ( requestedKey.equalsIgnoreCase( entry.getKey() ) )
            {
                return entry.getValue();
            }
        }
        return null;
    }

    private void positionAdView(
            final String adUnitId,
            final MaxAdFormat adFormat,
            final Activity activity)
    {
        final MaxAdFormat effectiveAdFormat =
                getEffectiveAdViewAdFormat( adUnitId, adFormat );
        if ( activity == null )
        {
            e( "Unable to position " + effectiveAdFormat.getLabel()
                    + ": Activity is no longer available" );
            return;
        }

        final MaxAdView adView = retrieveAdView(
                adUnitId,
                effectiveAdFormat,
                null,
                false );
        if ( adView == null )
        {
            logMissingAdView( adUnitId, effectiveAdFormat );
            return;
        }

        final ViewParent parent = adView.getParent();
        if ( !( parent instanceof RelativeLayout ) )
        {
            e( "Unable to position " + effectiveAdFormat.getLabel() + ": container is missing" );
            return;
        }

        final RelativeLayout container = (RelativeLayout) parent;
        final String adViewPosition = mAdViewPositions.get( adUnitId );
        if ( TextUtils.isEmpty( adViewPosition ) )
        {
            e( "Unable to position " + effectiveAdFormat.getLabel() + ": position is missing" );
            return;
        }

        final AdViewSize adViewSize = getAdViewSize( effectiveAdFormat );
        final int width = AppLovinSdkUtils.dpToPx( activity, adViewSize.widthDp );
        final int height = AppLovinSdkUtils.dpToPx( activity, adViewSize.heightDp );
        final RelativeLayout.LayoutParams params =
                (RelativeLayout.LayoutParams) adView.getLayoutParams();

        params.height = height;
        params.width = MaxAdFormat.MREC == effectiveAdFormat
                ? width
                : RelativeLayout.LayoutParams.MATCH_PARENT;
        params.setMargins( 0, 0, 0, 0 );
        adView.setRotation( 0 );
        adView.setTranslationX( 0 );
        adView.setTranslationY( 0 );
        adView.setLayoutParams( params );

        int gravity;
        if ( "centered".equalsIgnoreCase( adViewPosition ) )
        {
            gravity = Gravity.CENTER;
        }
        else
        {
            gravity = adViewPosition.toLowerCase().contains( "bottom" )
                    ? Gravity.BOTTOM
                    : Gravity.TOP;

            if ( adViewPosition.toLowerCase().contains( "left" ) )
            {
                gravity |= Gravity.LEFT;
                params.width = width;
            }
            else if ( adViewPosition.toLowerCase().contains( "right" ) )
            {
                gravity |= Gravity.RIGHT;
                params.width = width;
            }
            else
            {
                gravity |= Gravity.CENTER_HORIZONTAL;
            }
            adView.setLayoutParams( params );
        }

        final ViewGroup.LayoutParams rawLayoutParams = container.getLayoutParams();
        if ( !( rawLayoutParams instanceof WindowManager.LayoutParams ) )
        {
            e( "Unable to position " + effectiveAdFormat.getLabel()
                    + ": invalid window layout parameters" );
            return;
        }

        final WindowManager.LayoutParams windowLayoutParams =
                (WindowManager.LayoutParams) rawLayoutParams;
        windowLayoutParams.gravity = gravity;
        activity.getWindowManager().updateViewLayout( container, windowLayoutParams );
    }
    // endregion

    // region Utility Methods
    private void runOnUiThread(final String operation, final ActivityAction action)
    {
        final long expectedLifecycleGeneration;
        synchronized ( lifecycleLock )
        {
            if ( destroyRequested || state == State.DESTROYED )
            {
                return;
            }
            expectedLifecycleGeneration = lifecycleGeneration;
        }

        runOnUiThread( operation, expectedLifecycleGeneration, action );
    }

    private void runOnUiThread(
            final String operation,
            final long expectedLifecycleGeneration,
            final ActivityAction action)
    {
        synchronized ( lifecycleLock )
        {
            if ( destroyRequested
                    || state == State.DESTROYED
                    || lifecycleGeneration != expectedLifecycleGeneration )
            {
                return;
            }
        }

        final Runnable task = createGuardedUiTask(
                operation,
                expectedLifecycleGeneration,
                action );
        if ( Looper.myLooper() == Looper.getMainLooper() )
        {
            task.run();
        }
        else
        {
            mainHandler.post( task );
        }
    }

    private void postOnUiThread(final String operation, final ActivityAction action)
    {
        final long expectedLifecycleGeneration;
        synchronized ( lifecycleLock )
        {
            if ( destroyRequested || state == State.DESTROYED )
            {
                return;
            }
            expectedLifecycleGeneration = lifecycleGeneration;
        }

        mainHandler.post( createGuardedUiTask(
                operation,
                expectedLifecycleGeneration,
                action ) );
    }

    private Runnable createGuardedUiTask(
            final String operation,
            final long expectedLifecycleGeneration,
            final ActivityAction action)
    {
        return new Runnable()
        {
            @Override
            public void run()
            {
                final Activity activity = gameActivity.get();
                synchronized ( lifecycleLock )
                {
                    if ( destroyRequested
                            || state == State.DESTROYED
                            || lifecycleGeneration != expectedLifecycleGeneration )
                    {
                        return;
                    }
                }

                if ( !isActivityUsable( activity ) )
                {
                    e( "Unable to " + operation + ": Activity is no longer available" );
                    return;
                }

                try
                {
                    action.run( activity );
                }
                catch ( final Throwable throwable )
                {
                    e( "Unable to " + operation + ": " + Log.getStackTraceString( throwable ) );
                }
            }
        };
    }

    private <T> T callOnUiThread(
            final String operation,
            final T fallback,
            final ActivityCallable<T> callable)
    {
        final long expectedLifecycleGeneration;
        synchronized ( lifecycleLock )
        {
            if ( destroyRequested || state == State.DESTROYED )
            {
                return fallback;
            }
            expectedLifecycleGeneration = lifecycleGeneration;
        }

        if ( Looper.myLooper() == Looper.getMainLooper() )
        {
            synchronized ( lifecycleLock )
            {
                if ( destroyRequested
                        || state == State.DESTROYED
                        || lifecycleGeneration != expectedLifecycleGeneration )
                {
                    return fallback;
                }
            }

            final Activity activity = gameActivity.get();
            if ( !isActivityUsable( activity ) )
            {
                e( "Unable to " + operation + ": Activity is no longer available" );
                return fallback;
            }

            try
            {
                return callable.call( activity );
            }
            catch ( final Throwable throwable )
            {
                e( "Unable to " + operation + ": " + Log.getStackTraceString( throwable ) );
                return fallback;
            }
        }

        final Callable<T> guardedCallable = new Callable<T>()
        {
            @Override
            public T call() throws Exception
            {
                synchronized ( lifecycleLock )
                {
                    if ( destroyRequested
                            || state == State.DESTROYED
                            || lifecycleGeneration != expectedLifecycleGeneration )
                    {
                        return fallback;
                    }
                }

                final Activity activity = gameActivity.get();
                if ( !isActivityUsable( activity ) )
                {
                    e( "Unable to " + operation + ": Activity is no longer available" );
                    return fallback;
                }
                return callable.call( activity );
            }
        };
        final FutureTask<T> task = new FutureTask<>( guardedCallable );
        mainHandler.post( task );

        try
        {
            return task.get( UI_CALL_TIMEOUT_SECONDS, TimeUnit.SECONDS );
        }
        catch ( final Throwable throwable )
        {
            task.cancel( false );
            e( "Unable to " + operation + " on the UI thread: " + throwable );
            return fallback;
        }
    }

    private boolean repostCallbackToUi(final String operation, final Runnable callback)
    {
        if ( Looper.myLooper() == Looper.getMainLooper() && callbackDispatchInProgress )
        {
            return false;
        }

        runOnUiThread( operation, new ActivityAction()
        {
            @Override
            public void run(final Activity ignored)
            {
                callbackDispatchInProgress = true;
                try
                {
                    callback.run();
                }
                finally
                {
                    callbackDispatchInProgress = false;
                }
            }
        } );
        return true;
    }

    private void dispatchAdViewCallback(
            final String operation,
            final String adUnitId,
            final long generation,
            final Runnable callback)
    {
        if ( repostCallbackToUi( operation, new Runnable()
        {
            @Override
            public void run()
            {
                dispatchAdViewCallback( operation, adUnitId, generation, callback );
            }
        } ) )
        {
            return;
        }

        if ( !canHandleCallback()
                || !Long.valueOf( generation ).equals( mAdViewGenerations.get( adUnitId ) ) )
        {
            return;
        }
        callback.run();
    }

    private boolean canHandleCallback()
    {
        synchronized ( lifecycleLock )
        {
            if ( destroyRequested || state == State.DESTROYED )
            {
                return false;
            }
            if ( !isActivityUsable( gameActivity.get() ) )
            {
                e( "Dropping MAX callback because Activity is no longer available" );
                return false;
            }
            return true;
        }
    }

    private boolean requireReady(final String operation)
    {
        if ( destroyRequested || state != State.READY || sdk == null )
        {
            e( "Unable to " + operation + ": initialize AppLovin MAX first" );
            return false;
        }
        return true;
    }

    private MaxAdFormat getDeviceSpecificBannerAdViewAdFormat()
    {
        final Activity activity = gameActivity.get();
        return isActivityUsable( activity )
                ? getDeviceSpecificBannerAdViewAdFormat( activity )
                : MaxAdFormat.BANNER;
    }

    public static MaxAdFormat getDeviceSpecificBannerAdViewAdFormat(final Context context)
    {
        return context != null && AppLovinSdkUtils.isTablet( context )
                ? MaxAdFormat.LEADER
                : MaxAdFormat.BANNER;
    }

    private static boolean isActivityUsable(final Activity activity)
    {
        return activity != null && !activity.isFinishing() && !activity.isDestroyed();
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
        if ( MaxAdFormat.BANNER == format )
        {
            return new AdViewSize( 320, 50 );
        }
        if ( MaxAdFormat.MREC == format )
        {
            return new AdViewSize( 300, 250 );
        }
        throw new IllegalArgumentException( "Invalid ad format: " + format );
    }

    private JSONObject getAdInfo(final MaxAd ad)
    {
        final JSONObject adInfo = new JSONObject();
        put( adInfo, "adUnitIdentifier", emptyIfNull( ad.getAdUnitId() ) );
        put( adInfo, "creativeIdentifier", emptyIfNull( ad.getCreativeId() ) );
        put( adInfo, "networkName", emptyIfNull( ad.getNetworkName() ) );
        put( adInfo, "placement", emptyIfNull( ad.getPlacement() ) );
        put( adInfo, "revenue", ad.getRevenue() );
        put( adInfo, "format", ad.getFormat() != null ? ad.getFormat().getLabel() : "" );
        put( adInfo, "networkPlacement", emptyIfNull( ad.getNetworkPlacement() ) );
        put( adInfo, "revenuePrecision", emptyIfNull( ad.getRevenuePrecision() ) );
        put( adInfo, "requestLatencyMillis", ad.getRequestLatencyMillis() );
        put( adInfo, "dspName", emptyIfNull( ad.getDspName() ) );
        put( adInfo, "dspIdentifier", emptyIfNull( ad.getDspId() ) );
        return adInfo;
    }

    private JSONObject getLoadErrorInfo(final MaxError error)
    {
        final JSONObject errorInfo = new JSONObject();
        if ( error != null )
        {
            put( errorInfo, "code", error.getCode() );
            put( errorInfo, "message", emptyIfNull( error.getMessage() ) );
            put( errorInfo, "requestLatencyMillis", error.getRequestLatencyMillis() );
        }
        return errorInfo;
    }

    private JSONObject getDisplayErrorInfo(final MaxError error)
    {
        final JSONObject errorInfo = new JSONObject();
        if ( error != null )
        {
            put( errorInfo, "code", error.getCode() );
            put( errorInfo, "message", emptyIfNull( error.getMessage() ) );
            put( errorInfo, "mediatedNetworkErrorCode", error.getMediatedNetworkErrorCode() );
            put(
                    errorInfo,
                    "mediatedNetworkErrorMessage",
                    emptyIfNull( error.getMediatedNetworkErrorMessage() ) );
        }
        return errorInfo;
    }

    private static Map<String, Object> deserialize(final String serialized)
    {
        if ( TextUtils.isEmpty( serialized ) )
        {
            return Collections.emptyMap();
        }

        try
        {
            return jsonObjectToMap( new JSONObject( serialized ) );
        }
        catch ( final JSONException exception )
        {
            e( "Failed to deserialize event parameters: " + exception.getMessage() );
            return Collections.emptyMap();
        }
    }

    private static Map<String, Object> jsonObjectToMap(final JSONObject json)
            throws JSONException
    {
        final Map<String, Object> result = new HashMap<>();
        final Iterator<String> keys = json.keys();
        while ( keys.hasNext() )
        {
            final String key = keys.next();
            result.put( key, jsonValueToJava( json.get( key ) ) );
        }
        return result;
    }

    private static List<Object> jsonArrayToList(final JSONArray json)
            throws JSONException
    {
        final List<Object> result = new ArrayList<>( json.length() );
        for ( int index = 0; index < json.length(); ++index )
        {
            result.add( jsonValueToJava( json.get( index ) ) );
        }
        return result;
    }

    private static Object jsonValueToJava(final Object value)
            throws JSONException
    {
        if ( value == JSONObject.NULL )
        {
            return null;
        }
        if ( value instanceof JSONObject )
        {
            return jsonObjectToMap( (JSONObject)value );
        }
        if ( value instanceof JSONArray )
        {
            return jsonArrayToList( (JSONArray)value );
        }
        return value;
    }

    private static ConsentFlowUserGeography getAppLovinConsentFlowUserGeography(
            final String userGeography)
    {
        if ( "GDPR".equalsIgnoreCase( userGeography ) )
        {
            return ConsentFlowUserGeography.GDPR;
        }
        if ( "OTHER".equalsIgnoreCase( userGeography ) )
        {
            return ConsentFlowUserGeography.OTHER;
        }
        return ConsentFlowUserGeography.UNKNOWN;
    }

    private static boolean isAdViewVisible(final MaxAdView adView)
    {
        if ( adView.getVisibility() != View.VISIBLE )
        {
            return false;
        }
        final ViewParent parent = adView.getParent();
        return !( parent instanceof View ) || ( (View) parent ).getVisibility() == View.VISIBLE;
    }

    private static void put(final JSONObject object, final String key, final Object value)
    {
        try
        {
            object.put( key, value );
        }
        catch ( final JSONException exception )
        {
            e( "Unable to add JSON field \"" + key + "\": " + exception.getMessage() );
        }
    }

    private static void merge(final JSONObject destination, final JSONObject source)
    {
        final Iterator<String> keys = source.keys();
        while ( keys.hasNext() )
        {
            final String key = keys.next();
            put( destination, key, source.opt( key ) );
        }
    }

    private static String emptyIfNull(final String value)
    {
        return value != null ? value : "";
    }

    private static void logMissingAdView(final String adUnitId, final MaxAdFormat adFormat)
    {
        e( adFormat.getLabel() + " does not exist for ad unit ID \"" + adUnitId + "\"" );
    }

    private void logInvalidAdFormat(final MaxAdFormat adFormat)
    {
        logStackTrace( new IllegalStateException( "Invalid ad format: " + adFormat ) );
    }

    private void logStackTrace(final Exception exception)
    {
        e( Log.getStackTraceString( exception ) );
    }

    public static void d(final String message)
    {
        Log.d( SDK_TAG, "[" + TAG + "] " + message );
    }

    public static void e(final String message)
    {
        Log.e( SDK_TAG, "[" + TAG + "] " + message );
    }
    // endregion

    // region Defold Bridge
    private void sendDefoldEvent(final String name, final JSONObject params)
    {
        synchronized ( lifecycleLock )
        {
            if ( !destroyRequested && state != State.DESTROYED )
            {
                appLovinAddToQueue( name, params.toString() );
            }
        }
    }
    // endregion
}
