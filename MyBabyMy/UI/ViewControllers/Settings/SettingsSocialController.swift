//
//  SettingsSocialController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/27/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit

class SettingsSocialController: UIViewController
{
   @IBOutlet weak var instagramUsernameLabel: UILabel!
   @IBOutlet weak var facebookUsernameLabel: UILabel!
   @IBOutlet weak var vkUsernameLabel: UILabel!
   
   @IBOutlet weak var instagramBackView: UIView!
   @IBOutlet weak var facebookBackView: UIView!
   @IBOutlet weak var vkBackView: UIView!
   
   @IBOutlet weak var instagramButtonLabel: UILabel!
   @IBOutlet weak var facebookButtonLabel: UILabel!
   @IBOutlet weak var vkButtonLabel: UILabel!
   
   @IBOutlet weak var instagramButton: UIButton!
   @IBOutlet weak var facebookButton: UIButton!
   @IBOutlet weak var vkButton: UIButton!
   
   let disconnectColor = rgb(137, 141, 152)
   
   override func viewDidLoad()
   {
      super.viewDidLoad()
      updateButtons()
   }
   
   override func viewWillAppear(_ animated: Bool)
   {
      super.viewWillAppear(animated)
      navigationController?.navigationBar.isTranslucent = false;
      navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: rgb(255, 120, 154),
                                            NSFontAttributeName : UIFont.systemFont(ofSize: 12, weight: UIFontWeightMedium)]
      navigationController?.setNavigationBarHidden(false, animated: animated)
   }
   
   func updateButtons()
   {
      guard let user = User.current else { return }
      
      instagramButton.removeTarget(nil, action: nil, for: .allEvents)
      if user.instagramConnected
      {
         instagramBackView.backgroundColor = disconnectColor
         instagramButtonLabel.text = loc("Disconnect Instagram")
         instagramUsernameLabel.text = user.instagramAccDisplayedName
         instagramUsernameLabel.alpha = 1
         instagramButton.addTarget(self, action: #selector(instagramDisconnectTap), for: .touchUpInside)
      }
      else
      {
         instagramBackView.backgroundColor = rgb(63, 114, 155)
         instagramButtonLabel.text = loc("Login with Instagram")
         instagramUsernameLabel.text = loc("No connection")
         instagramUsernameLabel.alpha = 0.4
         instagramButton.addTarget(self, action: #selector(instagramConnectTap), for: .touchUpInside)
      }
      
      facebookButton.removeTarget(nil, action: nil, for: .allEvents)
      if user.facebookConnected
      {
         facebookBackView.backgroundColor = disconnectColor
         facebookButtonLabel.text = loc("Disconnect Facebook")
         facebookUsernameLabel.text = user.facebookAccDisplayedName
         facebookUsernameLabel.alpha = 1
         facebookButton.addTarget(self, action: #selector(facebookDisconnectTap), for: .touchUpInside)
      }
      else
      {
         facebookBackView.backgroundColor = rgb(59, 89, 152)
         facebookButtonLabel.text = loc("Login with Facebook")
         facebookUsernameLabel.text = loc("No connection")
         facebookUsernameLabel.alpha = 0.4
         facebookButton.addTarget(self, action: #selector(facebookConnectTap), for: .touchUpInside)
      }
      
      vkButton.removeTarget(nil, action: nil, for: .allEvents)
      if user.vkConnected
      {
         vkBackView.backgroundColor = disconnectColor
         vkButtonLabel.text = loc("Disconnect Vkontakte")
         vkUsernameLabel.text = user.vkAccDisplayedName
         vkUsernameLabel.alpha = 1
         vkButton.addTarget(self, action: #selector(vkDisconnectTap), for: .touchUpInside)
      }
      else
      {
         vkBackView.backgroundColor = rgb(63, 114, 155)
         vkButtonLabel.text = loc("Login with Vkontakte")
         vkUsernameLabel.text = loc("No connection")
         vkUsernameLabel.alpha = 0.4
         vkButton.addTarget(self, action: #selector(vkConnectTap), for: .touchUpInside)
      }
   }
   
   private func connect(_ network : SocialNetwork)
   {
      SocialManager.connect(network, presentingController: self,
      success:
      {
         user in
         self.updateButtons()
      },
      failure:
      {
         errorDescription in
         self.updateButtons()
         AlertManager.showAlert(errorDescription)
      })
   }
   
   private func disconnect(_ network : SocialNetwork)
   {
      let user = User.current!
      
      var otherAuthorizeWaysCount = 0
      if user.authorizationWithEmail { otherAuthorizeWaysCount += 1 }
      if user.instagramConnected && (network != .instagram) { otherAuthorizeWaysCount += 1 }
      if user.facebookConnected && (network != .facebook) { otherAuthorizeWaysCount += 1 }
      if user.vkConnected && (network != .vk) { otherAuthorizeWaysCount += 1 }
      
      if otherAuthorizeWaysCount == 0
      {
         AlertManager.showAlert(loc("Can not remove your only authorization way"))
         return
      }
      
      SocialManager.disconnect(network, presentingController: self,
      success: {
         self.updateButtons()
      },
      failure:
      {
         errorDescription in
         self.updateButtons()
         AlertManager.showAlert(errorDescription)
      })
   }
   
   // MARK: - Actions
   
   @objc func instagramConnectTap() {
      connect(.instagram)
   }
   
   @objc func instagramDisconnectTap() {
      disconnect(.instagram)
   }
   
   @objc func facebookConnectTap() {
      connect(.facebook)
   }
   
   @objc func facebookDisconnectTap() {
      disconnect(.facebook)
   }
   
   @objc func vkConnectTap() {
      connect(.vk)
   }
   
   @objc func vkDisconnectTap() {
      disconnect(.vk)
   }
   
   @IBAction func backTap(_ sender: UIBarButtonItem) {
      _ = navigationController?.popViewController(animated: true)
   }
   

}
