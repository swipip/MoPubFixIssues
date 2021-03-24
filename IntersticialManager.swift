//
//  IntersticialManager.swift
//  Frigo
//
//  Created by Gautier Billard on 05/02/2021.
//

import Foundation
import MoPubSDK

class IntersticialManager: NSObject {
    
    static let shared = IntersticialManager()
    
    private override init() {
        super.init()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            try? self.loadIntersticialIfPossible()
        }
    }
    
    static fileprivate (set) var lastLoaded: TimeInterval = 0
    private var canLoadNewAdd = true
    private (set) var intersticial: MPInterstitialAdController?
    var addFinished:(()->Void)?
    private var canCallCompletion = true
    
    private func loadIntersticialIfPossible() throws {
        guard canLoadNewAdd else {
            return}
        
        let currentTime = Date().timeIntervalSince1970
        let timeElapsed = currentTime - IntersticialManager.lastLoaded
        if timeElapsed > 10 {
            canLoadNewAdd = false
            intersticial = nil
            intersticial = MPInterstitialAdController(forAdUnitId: K.toolBox.moPubIntersticialProd)
            intersticial?.delegate = self
            intersticial?.loadAd()
        }else{
            DispatchQueue.main.asyncAfter(deadline: .now() + (10-timeElapsed) + 1) {
                try? self.loadIntersticialIfPossible()
            }
            throw NSError(domain: "Could not load intersticial", code: 123, userInfo: nil)
        }
    }
    
    func presentIntersticial(from controller: UIViewController, _ addFinished: @escaping()->Void) {
        self.addFinished = { [weak self] in
            self?.intersticial = nil
            addFinished()
        }
        if (intersticial?.ready ?? false) == false{
            self.intersticial = nil
            addFinished()
            try? loadIntersticialIfPossible()
        }
        intersticial?.show(from: controller)
    }

}

extension IntersticialManager: MPInterstitialAdControllerDelegate {
    func interstitialDidReceiveTapEvent(_ interstitial: MPInterstitialAdController!) {
        //
    }
    func interstitialDidExpire(_ interstitial: MPInterstitialAdController!) {
        print("Add expired")
    }
    func interstitialDidLoadAd(_ interstitial: MPInterstitialAdController!) {
        IntersticialManager.lastLoaded = Date().timeIntervalSince1970
    }
    func interstitialDidDismiss(_ interstitial: MPInterstitialAdController!) {
        guard canCallCompletion else {return}
        canLoadNewAdd = true
        addFinished?()
        DispatchQueue.main.async {
            try? self.loadIntersticialIfPossible()
        }
    }
    func interstitialDidFail(toLoadAd interstitial: MPInterstitialAdController!, withError error: Error!) {
        self.intersticial = nil
        canLoadNewAdd = true
        print("[MoPub] Add error. \(error.localizedDescription)")
    }
    func interstitialWillAppear(_ interstitial: MPInterstitialAdController!) {
        canCallCompletion = true
        print("Add will show")
    }
}
