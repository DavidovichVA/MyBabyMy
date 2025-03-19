//
//  SocialManager.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/26/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit
import WebKit
import VK_ios_sdk
import FacebookCore
import FacebookLogin
import InstagramKit

enum SocialNetwork
{
   case instagram
   case facebook
   case vk
   
   static let allValues = [instagram, facebook, vk]
}

fileprivate let vkAppId = "5795289"
fileprivate let vkPermissions = [VK_PER_EMAIL]
fileprivate let facebookPermissions : [FacebookCore.ReadPermission] = [.publicProfile, .email]

final class SocialManager
{
   fileprivate static let manager = SocialManagerInternal()
   
   private static var authSuccessCallback : UserCallback?
   private static var authFailureCallback : FailureCallback?
   
   private static var userWaitingSocialData : [SocialNetwork : (userId : Int?, name : String?, email : String?)] = [:]
   
   private static var connectingToCurrentUser = false
   
   // MARK: - Public
   
   public class func setup()
   {
      let vksdk = manager.vksdk
      vksdk.register(manager)
      vksdk.uiDelegate = manager
   }
   
   public class func login(_ network : SocialNetwork, presentingController : UIViewController, success: @escaping UserCallback, failure : @escaping FailureCallback)
   {
      start(network, presentingController: presentingController, connecting: false, success: success, failure: failure)
   }
   
   public class func connect(_ network : SocialNetwork, presentingController : UIViewController, success: @escaping UserCallback, failure : @escaping FailureCallback)
   {
      guard User.authorized else { failure("No authorized user"); return }
      logout(network)
      start(network, presentingController: presentingController, connecting: true, success: success, failure: failure)
   }
   
   public class func disconnect(_ network : SocialNetwork, presentingController : UIViewController, success: @escaping SuccessCallback, failure : @escaping FailureCallback)
   {
      showAppSpinner(addedTo: presentingController.view, animated: true)
      
      RequestManager.editSocialAuthData([network : ("", nil, nil)],
      success:
      {
         if let currentUser = User.current
         {
            currentUser.modifyWithTransactionIfNeeded
            {
               switch network
               {
                  case .instagram: currentUser.instagramConnected = false
                  case .facebook: currentUser.facebookConnected = false
                  case .vk: currentUser.vkConnected = false
               }
            }
         }
         logout(network)
         
         hideAppSpinner(for: presentingController.view, animated: true)
         success()
      },
      failure:
      {
         errorDescription in
         hideAppSpinner(for: presentingController.view, animated: true)
         failure(errorDescription)
      })
   }
   
   public class func logout(_ network : SocialNetwork)
   {
      switch network {
         case .instagram: InstagramEngine.shared().logout()
         case .facebook: manager.fbLoginManager.logOut()
         case .vk: VKSdk.forceLogout()
      }
   }
   
   // MARK: - Private
   
   private class func start(_ network : SocialNetwork, presentingController : UIViewController, connecting : Bool, success: @escaping UserCallback, failure : @escaping FailureCallback)
   {
      connectingToCurrentUser = connecting
      
      authSuccessCallback = success
      authFailureCallback = failure
      manager.presentingController = presentingController
      
      showAppSpinner(addedTo: presentingController.view, animated: true)
      
      userWaitingSocialData[network] = ((connecting ? User.current!.id : nil), nil, nil)
      
      switch network {
         case .instagram: manager.loginWithInstagram()
         case .facebook: manager.loginWithFacebook()
         case .vk: manager.loginWithVk()
      }
   }
   
   fileprivate class func gotSocialToken(_ network : SocialNetwork, token : String, socialId : String)
   {
      let presentingController = manager.presentingController
      if presentingController?.presentedViewController != nil {
         presentingController?.dismiss(animated: true, completion: nil)
      }      
      
      if !connectingToCurrentUser
      {
         RequestManager.authorize(socialNetwork: network, socialId: socialId,
         success:
         {
            user in
            
            user.modifyWithTransactionIfNeeded
            {
               switch network
               {
                  case .instagram: user.instagramConnected = true
                  case .facebook: user.facebookConnected = true
                  case .vk: user.vkConnected = true
               }
            }
            
            if let controller = presentingController {
               hideAppSpinner(for: controller.view, animated: true)
            }
            if let callback = authSuccessCallback {
               callback(user)
            }
            authSuccessCallback = nil
            authFailureCallback = nil
            manager.presentingController = nil
            
            if var waitingUser = userWaitingSocialData[network]
            {
               if waitingUser.name == nil {
                  waitingUser.userId = user.id
                  userWaitingSocialData[network] = waitingUser
               }
               else
               {
                  if user.id != 0, let currentUser = User.current, user.id == currentUser.id
                  {
                     RequestManager.editSocialAuthData([network : (socialId, waitingUser.name, waitingUser.email)])
                     user.modifyWithTransactionIfNeeded
                     {
                        switch network
                        {
                        case .instagram:
                           user.instagramName = waitingUser.name ?? ""
                           user.instagramEmail = waitingUser.email ?? ""
                        case .facebook:
                           user.facebookName = waitingUser.name ?? ""
                           user.facebookEmail = waitingUser.email ?? ""
                        case .vk:
                           user.vkName = waitingUser.name ?? ""
                           user.vkEmail = waitingUser.email ?? ""
                        }
                     }
                  }
                  userWaitingSocialData[network] = nil
               }
            }
         },
         failure:
         {
            errorDescription in
            
            userWaitingSocialData[network] = nil
            
            if let controller = presentingController {
               hideAppSpinner(for: controller.view, animated: true)
            }
            if let callback = authFailureCallback, !isNilOrEmpty(errorDescription) {
               callback(errorDescription)
            }
            authSuccessCallback = nil
            authFailureCallback = nil
            manager.presentingController = nil
         })
      }
   }
   
   fileprivate class func socialAuthFailed(_ network : SocialNetwork, _ errorDescription : String?)
   {
      userWaitingSocialData[network] = nil
      
      if let controller = manager.presentingController {
         hideAppSpinner(for: controller.view, animated: true)
      }
      
      let failAndClean =
      {
         if let callback = authFailureCallback, !isNilOrEmpty(errorDescription) {
            callback(errorDescription!)
         }         
         authSuccessCallback = nil
         authFailureCallback = nil
         manager.presentingController = nil
      }
      
      if manager.presentingController?.presentedViewController != nil {
         manager.presentingController?.dismiss(animated: true, completion: failAndClean)
      }
      else {
         failAndClean()
      }
   }
   
   fileprivate class func receivedSocialData(_ network : SocialNetwork, token : String, socialId : String, name : String, email : String?)
   {
      guard var waitingUser = userWaitingSocialData[network] else { return }
      
      if let userId = waitingUser.userId
      {
         if userId != 0, let currentUser = User.current, userId == currentUser.id
         {
            var successBlock : SuccessCallback = {}
            var failureBlock : FailureCallback = { errorDescription in dlog(errorDescription) }
            if connectingToCurrentUser
            {
               successBlock =
               {
                  if let currentUser = User.current
                  {
                     currentUser.modifyWithTransactionIfNeeded
                     {
                        switch network
                        {
                           case .instagram:
                              currentUser.instagramConnected = true
                              currentUser.instagramName = name
                              currentUser.instagramEmail = email ?? ""
                           case .facebook:
                              currentUser.facebookConnected = true
                              currentUser.facebookName = name
                              currentUser.facebookEmail = email ?? ""
                           case .vk:
                              currentUser.vkConnected = true
                              currentUser.vkName = name
                              currentUser.vkEmail = email ?? ""
                        }
                     }
                  }
                  
                  if let controller = manager.presentingController {
                     hideAppSpinner(for: controller.view, animated: true)
                  }
                  if let callback = authSuccessCallback {
                     callback(User.current!)
                  }
                  authSuccessCallback = nil
                  authFailureCallback = nil
                  manager.presentingController = nil
               }
               
               failureBlock =
               {
                  errorDescription in
                  
                  if let controller = manager.presentingController {
                     hideAppSpinner(for: controller.view, animated: true)
                  }
                  if let callback = authFailureCallback, !isNilOrEmpty(errorDescription) {
                     callback(errorDescription)
                  }
                  authSuccessCallback = nil
                  authFailureCallback = nil
                  manager.presentingController = nil
               }
            }
            
            RequestManager.editSocialAuthData([network : (socialId, name, email)], success: successBlock, failure: failureBlock)
         }
         userWaitingSocialData[network] = nil
      }
      else
      {
         waitingUser.name = name
         waitingUser.email = email
         userWaitingSocialData[network] = waitingUser
      }
   }
   
   fileprivate class func failedToGetSocialData(_ network : SocialNetwork, _ errorDescription : String?)
   {
      userWaitingSocialData[network] = nil
      if connectingToCurrentUser
      {
         if let controller = manager.presentingController {
            hideAppSpinner(for: controller.view, animated: true)
         }
         
         let failAndClean =
         {
            if let callback = authFailureCallback, !isNilOrEmpty(errorDescription) {
               callback(errorDescription!)
            }
            authSuccessCallback = nil
            authFailureCallback = nil
            manager.presentingController = nil
         }
         
         if manager.presentingController?.presentedViewController != nil {
            manager.presentingController?.dismiss(animated: true, completion: failAndClean)
         }
         else {
            failAndClean()
         }
      }
   }
}

// MARK: - Internal manager

fileprivate class SocialManagerInternal : NSObject, VKSdkDelegate, VKSdkUIDelegate, InstagramDelegate
{
   let vksdk : VKSdk = VKSdk.initialize(withAppId: vkAppId)!
   
   let fbLoginManager : FacebookLogin.LoginManager =
   {
      let manager = FacebookLogin.LoginManager()
      manager.loginBehavior = .web
      return manager
   }()
   
   weak var presentingController : UIViewController?
   var presController : UIViewController
   {
      if let controller = presentingController {
         return controller
      }
      
      var controller = AppWindow.rootViewController!
      while let presentedController = controller.presentedViewController {
         controller = presentedController
      }
      
      return controller
   }
   
   // MARK: - Facebook
   
   func loginWithFacebook()
   {
      fbLoginManager.logOut()
      fbLoginManager.logIn(facebookPermissions, viewController: presController)
      {
         result in
         switch result
         {
         case .success( let grantedPermissions, _, let accessToken):
            let token = accessToken.authenticationToken //changes each time
            let userId = accessToken.userId ?? ""
            guard !userId.isEmpty else {
               SocialManager.socialAuthFailed(.facebook, loc("Did not receive Facebook auth token"))
               return
            }
            
            SocialManager.gotSocialToken(.facebook, token: token, socialId: userId)
            
            if grantedPermissions.contains("email") || grantedPermissions.contains("public_profile") {
               self.getFacebookUserData(accessToken: accessToken, authenticationToken: token, socialId: userId)
            }
            
         case .cancelled:
            dlog("Facebook auth cancelled")
            SocialManager.socialAuthFailed(.facebook, nil)
            
         case .failed(let error):
            SocialManager.socialAuthFailed(.facebook, error.localizedDescription)
         }
      }
   }
   
   func getFacebookUserData(accessToken : AccessToken, authenticationToken : String, socialId : String)
   {
      let graphRequest = GraphRequest(graphPath: "me", parameters: ["fields": "email,name"], accessToken: accessToken)
      graphRequest.start(
      {
         (_, graphResult) in
         switch graphResult
         {
         case .success(let response):
            guard let dictionary = response.dictionaryValue else {
               SocialManager.failedToGetSocialData(.facebook, loc("Did not receive Facebook user data"))
               return
            }
            
            let emailOptional = dictionary["email"] as? String
            let id = dictionary["id"] as? String
            var name = dictionary["name"] as? String ?? ""
            
            if name.isEmpty && isNilOrEmpty(emailOptional) && !isNilOrEmpty(id) {
               name = "id\(id!)"
            }
            
            SocialManager.receivedSocialData(.facebook, token : authenticationToken, socialId : socialId, name : name, email : emailOptional)
            
         case .failed(let error):
            SocialManager.failedToGetSocialData(.facebook, error.localizedDescription)
         }
      })
   }
   
   // MARK: - VK
   
   func loginWithVk()
   {
      VKSdk.forceLogout()
      VKSdk.wakeUpSession(vkPermissions)
      {
         (state, error) in
         switch state
         {
            case .authorized:
               let userId = VKSdk.accessToken()?.userId ?? ""
               let token = VKSdk.accessToken()?.accessToken ?? ""
               if VKSdk.isLoggedIn() && !userId.isEmpty {
                  SocialManager.gotSocialToken(.vk, token: token, socialId: userId)
               }
               else {
                  VKSdk.authorize(vkPermissions)
               }
            
            default: VKSdk.authorize(vkPermissions)
         }
      }
   }
   
   /**
    Notifies about authorization was completed, and returns authorization result with new token or error.
    
    @param result contains new token or error, retrieved after VK authorization.
    */
   public func vkSdkAccessAuthorizationFinished(with result: VKAuthorizationResult!)
   {
      let token = result?.token?.accessToken ?? ""
      let userId = result?.token?.userId ?? ""
      
      if !userId.isEmpty {
         SocialManager.gotSocialToken(.vk, token: token, socialId: userId)
      }
      else if let error = result?.error {
         SocialManager.socialAuthFailed(.vk, error.localizedDescription)
      }
      else {
         SocialManager.socialAuthFailed(.vk, loc("Did not receive Vkontakte auth token"))
      }
   }

   public func vkSdkAuthorizationStateUpdated(with result: VKAuthorizationResult!)
   {
      if let user = result?.user, let token = result?.token?.accessToken, !token.isEmpty
      {
         let emailOptional = result?.token?.email
         let firstName = user.first_name ?? ""
         let lastName = user.last_name ?? ""
         let nickName = user.nickname ?? ""
         let id = user.id ?? NSNumber(integerLiteral: 0)
         
         var name = ""
         
         if !firstName.isEmpty && !lastName.isEmpty { name = firstName + " " + lastName }
         else if !nickName.isEmpty { name = nickName }
         else if !firstName.isEmpty { name = firstName }
         else if !lastName.isEmpty { name = lastName }
         
         if name.isEmpty && isNilOrEmpty(emailOptional) && id.intValue != 0 {
            name = "id\(id.intValue)"
         }

         SocialManager.receivedSocialData(.vk, token : token, socialId : user.id.stringValue, name : name, email : emailOptional)
      }
   }
   
   /**
    Notifies about access error. For example, this may occurs when user rejected app permissions through VK.com
    */
   public func vkSdkUserAuthorizationFailed() {
      SocialManager.socialAuthFailed(.vk, loc("VKontakte access error"))
   }
   
   /**
    Pass view controller that should be presented to user. Usually, it's an authorization window.
    */
   public func vkSdkShouldPresent(_ controller: UIViewController!) {
      presController.present(controller, animated: true, completion: nil)
   }
   
   
   /**
    Calls when user must perform captcha-check.
    */
   public func vkSdkNeedCaptchaEnter(_ captchaError: VKError!)
   {
      let captchaViewController = VKCaptchaViewController.captchaControllerWithError(captchaError)
      captchaViewController?.present(in: presController)
   }
   
   // MARK: - Instagram
   
   func loginWithInstagram()
   {
      if let accessToken = InstagramEngine.shared().accessToken, !accessToken.isEmpty
      {
         InstagramEngine.shared().getSelfUserDetails(
         success:
         {
            user in
            SocialManager.gotSocialToken(.instagram, token: accessToken, socialId: user.username)
            SocialManager.receivedSocialData(.instagram, token : accessToken, socialId : user.username, name : user.username, email : user.website?.absoluteString)
         },
         failure:
         {
            (error, code) in
            SocialManager.socialAuthFailed(.instagram, error.localizedDescription)
         })
      }
      else
      {
         let loginController = InstagramLoginWebController()
         loginController.delegate = self
         let navController = UINavigationController(rootViewController: loginController)
         
         let navTitleAttributes = [NSForegroundColorAttributeName : rgb(255, 120, 154),
                                   NSFontAttributeName : UIFont.systemFont(ofSize: 14, weight: UIFontWeightMedium)]
         navController.navigationBar.titleTextAttributes = navTitleAttributes
         navController.navigationBar.tintColor = UIColor.lightGray
         navController.navigationBar.barTintColor = UIColor.white
         navController.navigationBar.isTranslucent = false
         
         presController.present(navController, animated: true, completion: nil)
      }
   }
   
   func instagramAuthorizationSucceed(accessToken : String)
   {
      InstagramEngine.shared().getSelfUserDetails(
      success:
      {
         user in
         SocialManager.gotSocialToken(.instagram, token: accessToken, socialId: user.username)
         SocialManager.receivedSocialData(.instagram, token : accessToken, socialId: user.username, name : user.username, email : user.website?.absoluteString)
      },
      failure:
      {
         (error, code) in
         SocialManager.socialAuthFailed(.instagram, error.localizedDescription)
      })
   }
   
   func instagramAuthorizationFailed(errorDescription : String)
   {
      InstagramEngine.shared().logout()
      SocialManager.socialAuthFailed(.instagram, errorDescription)
   }
   
   func instagramAuthorizationCancelled()
   {
      SocialManager.socialAuthFailed(.instagram, nil)
   }
}


fileprivate protocol InstagramDelegate : AnyObject
{
   func instagramAuthorizationSucceed(accessToken : String)
   func instagramAuthorizationFailed(errorDescription : String)
   func instagramAuthorizationCancelled()
}

// MARK: - Instagram Web Controller

fileprivate class InstagramLoginWebController: UIViewController, WKNavigationDelegate
{
   var webView : WKWebView!
   weak var delegate : InstagramDelegate!
   
   override func viewDidLoad()
   {
      super.viewDidLoad()
      
      title = loc("LOGIN")
      navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(closeTap))
      
      view.backgroundColor = UIColor.white
      
      webView = WKWebView(frame: view.bounds)
      webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      view.addSubview(webView)
      webView.navigationDelegate = self
      
      let authUrl = InstagramEngine.shared().authorizationURL()
      webView.load(URLRequest(url: authUrl))
   }
   
   @objc func closeTap()
   {
      delegate.instagramAuthorizationCancelled()
   }
   
   public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
   {
      if let url = navigationAction.request.url
      {
         let urlString = url.absoluteString
         let engine = InstagramEngine.shared()
         
         if urlString.hasPrefix(engine.appRedirectURL)
         {
            do {
               try engine.receivedValidAccessToken(from: url)
            }
            catch let error {
               delegate.instagramAuthorizationFailed(errorDescription: error.localizedDescription)
               decisionHandler(.cancel)
               return
            }
            
            decisionHandler(.cancel)
            
            if let accessToken = engine.accessToken, !accessToken.isEmpty {
               delegate.instagramAuthorizationSucceed(accessToken: accessToken)
            }
            else {
               delegate.instagramAuthorizationFailed(errorDescription: loc("Did not receive Instagram auth token"))
            }
            
            return
         }
         
         if let host = url.host, !host.contains("instagram")
         {
            decisionHandler(.cancel)
            UIApplication.shared.openURL(url)
            return
         }
         
         if urlString.localizedCaseInsensitiveContains("password") //forgot password page
         {
            decisionHandler(.cancel)
            UIApplication.shared.openURL(url)
            return
         }
      }
      
      decisionHandler(.allow)
   }
   
   public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
   {
      webView.evaluateJavaScript("document.body.innerHTML")
      {
         (html, error) in
         guard let htmlString = html as? String else { return }
         
         if let range = htmlString.range(of: "\"error_message\"")
         {
            let failBlock : (String) -> Void  =
            {
               errorDescription in
               
               webView.alpha = 0
               self.delegate.instagramAuthorizationFailed(errorDescription: loc(errorDescription))
            }
            
            let quote = CharacterSet(charactersIn : "\"")

            guard let firstQuoteRange = htmlString.rangeOfCharacter(from: quote, range: range.upperBound..<htmlString.endIndex) else
            {
               failBlock("Instagram authorization failed")
               return
            }
            
            guard let secondQuoteRange = htmlString.rangeOfCharacter(from: quote, range: firstQuoteRange.upperBound..<htmlString.endIndex) else
            {
               failBlock("Instagram authorization failed")
               return
            }
            
            let errorMessage = htmlString.substring(with: firstQuoteRange.upperBound..<secondQuoteRange.lowerBound)
            failBlock(errorMessage)
         }

      }
   }
}
