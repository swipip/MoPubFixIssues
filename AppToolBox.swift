//
//  AppToolBox.swift
//  Frigo
//
//  Created by Gautier Billard on 16/11/2020.
//

import Foundation
import Amplitude
import Adjust
import FBSDKCoreKit
import Firebase
import FirebaseRemoteConfig
import MoPubSDK
import AppLovinSDK
import AppTrackingTransparency
import MoPub_UnityAds_Adapters
import GoogleMobileAds
import FBAudienceNetwork

///Class responsible for setting up all the tools related to monetization, tracking and testing.
class AppToolBox: NSObject, AdjustDelegate  {
    
    private override init() {
        amplitudeInstance = Amplitude.instance()
    }
    
    static let shared = AppToolBox()
    
    // MARK: Tools instances
    
    private (set) var remoteConfig: RemoteConfig?
    private (set) var amplitudeInstance: Amplitude
    
    var adjustInstance: Adjust?
    
    // MARK: Setup
    
    ///This method initializes every tools used by the app. Namely, Amplitude, Adjust, MoPub, Firebase
    func setUpToolBox(_ application: UIApplication, options: [UIApplication.LaunchOptionsKey: Any]?) {
        
        setUpUnity()
        setUpAdjust()
        setUpAmplitude()
        setUpMoPub()
        setUpFireBase()
        setUpFacebook(application,options: options)
//        setUpFacebookNetwork()
        setUpRemoteConfig()

    }
    private func setUpUnity() {
//        UnityAds.initialize("3908224")
    }
    private func setUpFacebookNetwork() {
        FBAudienceNetworkAds.initialize(with: nil, completionHandler: nil)
    }
    
    private func setUpGoogleAds() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }
    
    private func setUpAmplitude() {
        
        Amplitude.instance().trackingSessionEvents = true
        
        if let userId = UserDefaults.standard.value(forKey: "com.youmiam.adjustID") as? String {
            Amplitude.instance().setUserId(userId)
            let identify = AMPIdentify()
                .add(TrackingManager.events.params.userId, value: userId as NSObject)
            Amplitude.instance().identify(identify ??  AMPIdentify())
        }
        
        Amplitude.instance().initializeApiKey(K.toolBox.amplitudeProdKey)
        Amplitude.instance().logEvent(TrackingManager.events.session.appStart)
        
    }
    
    private func setUpAdjust() {
        adjustInstance = Adjust()
        let environment = ADJEnvironmentProduction
        let appToken = K.toolBox.adjustAppToken
    
        let config = ADJConfig(appToken: appToken, environment: environment)
        config?.logLevel = ADJLogLevelVerbose
        config?.delegate = self
        config?.delayStart = 2
        
        adjustInstance?.addSessionPartnerParameter(AmplitudeIDParams().abTestVersion, value: RCManager.shared.getStringFor(.onboarding, shouldSave: true))
        adjustInstance?.appDidLaunch(config)
    }
    private func setUpVungle() {
        do {
            try VungleSDK.shared().start(withAppId: "kVungleTestAppID");
        }
        catch let error as NSError {
            print("Error while starting VungleSDK : \(error.domain)")
            return;
        }
    }
    private func setUpMoPub(_ completion: (()->Void)? = nil) {
                
        let moPubConfig = MPMoPubConfiguration(adUnitIdForAppInitialization: K.toolBox.moPubIntersticialProd)
        moPubConfig.loggingLevel = .debug

//        let facebookConfig = ["native_banner":true]
        let ironSourceConfig = ["applicationKey":"e03bb709"]
        
        let networkConfigs: NSMutableDictionary = [:]
//        networkConfigs["FacebookAdapterConfiguration"] = facebookConfig
        networkConfigs["IronSourceAdapterConfiguration"] = ironSourceConfig
        
        moPubConfig.mediatedNetworkConfigurations = networkConfigs
        
        MoPub.sharedInstance().initializeSdk(with: moPubConfig) {
            completion?()
            print("[MoPub] initialized")
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onImpressionTracked(_:)),
            name: NSNotification.Name.mpImpressionTracked,
            object: nil)
        
    }
    
    private func setUpFireBase() {
        FirebaseApp.configure()
    }
    
    private func setUpFacebook(_ application: UIApplication, options: [UIApplication.LaunchOptionsKey: Any]?) {
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: options
        )
//        FBAudienceNetworkAds.initialize(with: nil) { (result) in
//            print("init: \(result.isSuccess)")
//        }
        
    }
    
    private func setUpRemoteConfig() {
        
        remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig?.configSettings = settings
        
        remoteConfig?.setDefaults(RCParams().config)
        
        RCManager.shared.fetchConfig()
        
    }
    
    // MARK: Selectors
    
    func adjustTrackImpressionDate(_ impressionData: Data) {
        guard (adjustInstance?.isEnabled() ?? false) else {
            assert(false == true)
            return}
        assert(adjustInstance != nil)
        assert(Adjust.isEnabled())
        adjustInstance?.trackAdRevenue(ADJAdRevenueSourceMopub, payload: impressionData)
        Adjust.trackAdRevenue(ADJAdRevenueSourceMopub, payload: impressionData)
    }
    
    @objc private func onImpressionTracked(_ notification:Notification) {

        guard let userInfo = notification.userInfo as? [String: Any] else {
                return}
        
        guard let impressionData = (userInfo[kMPImpressionTrackedInfoImpressionDataKey] as? MPImpressionData)?
                .jsonRepresentation else {return}
        
        adjustTrackImpressionDate(impressionData)
        
    }
    
    // MARK: Adjust delegate
    
    func adjustAttributionChanged(_ attribution: ADJAttribution?) {
        print(attribution?.adid ?? "")
        if let id = attribution?.adid {
            UserDefaults.standard.setValue(id, forKey: "com.youmiam.adjustID")
            setUpAmplitude()
        }
    }
    
}
