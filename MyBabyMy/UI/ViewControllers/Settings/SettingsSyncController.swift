//
//  SettingsSyncController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 1/26/17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import UIKit

class SettingsSyncController: UIViewController
{
   @IBOutlet weak var syncMediaSwitch: UISwitch!
   @IBOutlet weak var syncMediaWiFiSwitch: UISwitch!
   @IBOutlet var syncMediaWifiHideConstraint: NSLayoutConstraint!
   @IBOutlet weak var syncMusicSwitch: UISwitch!
   @IBOutlet weak var syncMusicWiFiSwitch: UISwitch!
   @IBOutlet var syncMusicWifiHideConstraint: NSLayoutConstraint!
   @IBOutlet weak var bottomSyncView: UIView!
   @IBOutlet var currentSynchronizationHideConstraint: NSLayoutConstraint!
   @IBOutlet weak var syncSpinnerArrows: UIImageView!
   @IBOutlet weak var syncProgressView: UIProgressView!
   @IBOutlet weak var syncNowView: UIView!
   @IBOutlet weak var cancelView: UIView!
   
   private var displayLink : CADisplayLink?
   
   private let pinkColor = rgb(255, 120, 154)
   private let grayColor = rgb(137, 141, 152)
   
   override func viewDidLoad()
   {
      super.viewDidLoad()
      setupUserProObserver()
   }
   
   override func viewWillAppear(_ animated: Bool)
   {
      super.viewWillAppear(animated)

      navigationController?.setNavigationBarHidden(false, animated: true)
      if let navigationBar = navigationController?.navigationBar
      {
//         navigationBar.isTranslucent = true
//         navigationBar.shadowImage = UIImage()
//         navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
         navigationBar.isTranslucent = false
         navigationBar.barTintColor = pinkColor
         
         if let bottomLine = navigationBar.findSubview(criteria: {
            view in
            return view is UIImageView && view.bounds.height <= 1
         }) {
            bottomLine.isHidden = true
         }
         
         navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white,
                                               NSFontAttributeName : UIFont.systemFont(ofSize: 12, weight: UIFontWeightMedium)]
      }
      
      
      update()
      createDisplayLink()
   }

   override var preferredStatusBarStyle: UIStatusBarStyle {
      return .lightContent
   }
   
   func update()
   {
      guard let user = User.current else { return }
      
      let isPro = user.isPro
      
      syncMediaSwitch.isOn = user.syncMedias
      syncMediaWifiHideConstraint.isActive = !user.syncMedias || !isPro
      syncMediaWiFiSwitch.isOn = user.syncMediasWiFiOnly
      
      let switchColor = isPro ? pinkColor : grayColor
      syncMediaSwitch.isEnabled = isPro
      syncMediaSwitch.onTintColor = switchColor.withAlphaComponent(0.2)
      syncMediaSwitch.thumbTintColor = switchColor
      syncMediaWiFiSwitch.isEnabled = syncMediaSwitch.isEnabled
      syncMediaWiFiSwitch.onTintColor = syncMediaSwitch.onTintColor
      syncMediaWiFiSwitch.thumbTintColor = syncMediaSwitch.thumbTintColor
      
      syncMusicSwitch.isOn = user.syncSongs
      syncMusicWifiHideConstraint.isActive = !user.syncSongs
      syncMusicWiFiSwitch.isOn = user.syncSongsWiFiOnly
      
      bottomSyncView.isHidden = !isPro
      
      view.layoutIfNeeded()
   }
   
   func createDisplayLink()
   {
      if let dLink = displayLink {
         dLink.invalidate()
      }
      displayLink = CADisplayLink(target: self, selector: #selector(updateSync(sender:)))
      displayLink?.add(to: RunLoop.main, forMode: .commonModes)
   }
   
   @objc func updateSync(sender : CADisplayLink)
   {
      if case .idle = Synchronization.state
      {
         if !currentSynchronizationHideConstraint.isActive
         {
            currentSynchronizationHideConstraint.isActive = true
            UIView.animateIgnoringInherited(withDuration: 0.3) {
               self.view.layoutIfNeeded()
            }
            
            syncSpinnerArrows.layer.removeAllAnimations()
            syncSpinnerArrows.transform = .identity
            
            syncNowView.isHidden = false
            cancelView.isHidden = true
         }
      }
      else
      {
         if currentSynchronizationHideConstraint.isActive
         {
            currentSynchronizationHideConstraint.isActive = false
            UIView.animateIgnoringInherited(withDuration: 0.3) {
               self.view.layoutIfNeeded()
            }
            
            UIView.animateIgnoringInherited(withDuration: 0.5, delay: 0, options: [.curveLinear, .repeat], animations:
            {
               let angle = -(CGFloat.pi - CGFloat(0.0001))
               self.syncSpinnerArrows.transform = CGAffineTransform(rotationAngle: angle)
            }, completion: nil)
            
            syncNowView.isHidden = true
            cancelView.isHidden = false
         }
      }
      
      syncProgressView.progress = Synchronization.progress ?? 0
   }
   
   //MARK: - Pro Observer
   
   private var userProObserver : NSObjectProtocol?
   
   private func setupUserProObserver()
   {
      userProObserver = NotificationCenter.default.addObserver(forName: .MBUserProChanged, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         if let currentUser = User.current, let user = notification.object as? User, user.id == currentUser.id,
            let proStatusChanged = notification.userInfo?[kUserProChangedStatus] as? Bool, proStatusChanged
         {
            self.update()
         }
      }
   }
   
   deinit
   {
      if userProObserver != nil {
         NotificationCenter.default.removeObserver(userProObserver!)
      }
   }
   
   // MARK: - Actions
   
   @IBAction func syncMediaSwitched(_ sender: UISwitch)
   {
      guard let user = User.current else { return }
      let syncMedias = sender.isOn
      
      syncMediaWifiHideConstraint.isActive = !syncMedias
      UIView.animateIgnoringInherited(withDuration: 0.3) {
         self.view.layoutIfNeeded()
      }
      
      user.modifyWithTransactionIfNeeded {
         user.syncMedias = syncMedias
      }
   }
   
   @IBAction func syncMediaWiFiSwitched(_ sender: UISwitch)
   {
      guard let user = User.current else { return }
      
      user.modifyWithTransactionIfNeeded {
         user.syncMediasWiFiOnly = sender.isOn
      }
   }

   @IBAction func syncMusicSwitched(_ sender: UISwitch)
   {
      guard let user = User.current else { return }
      let syncSongs = sender.isOn
      
      syncMusicWifiHideConstraint.isActive = !syncSongs
      UIView.animateIgnoringInherited(withDuration: 0.3) {
         self.view.layoutIfNeeded()
      }
      
      user.modifyWithTransactionIfNeeded {
         user.syncSongs = syncSongs
      }
   }
   
   @IBAction func syncMusicWiFiSwitched(_ sender: UISwitch)
   {
      guard let user = User.current else { return }
      
      user.modifyWithTransactionIfNeeded {
         user.syncSongsWiFiOnly = sender.isOn
      }
   }
   
   @IBAction func backTap(_ sender: UIBarButtonItem)
   {
      if let dLink = displayLink {
         dLink.invalidate()
      }
      _ = navigationController?.popViewController(animated: true)
   }
   
   @IBAction func syncNowTap() {
      Synchronization.start(ignoreUserSyncOptions: true)
   }
   
   @IBAction func cancelTap() {
      Synchronization.cancel()
   }
}
