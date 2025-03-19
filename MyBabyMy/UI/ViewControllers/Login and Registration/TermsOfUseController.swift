//
//  TermsOfUseController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/2/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit
import WebKit

class TermsOfUseController: UIViewController, WKNavigationDelegate
{
   @IBOutlet weak var bottomView: UIView!
   @IBOutlet weak var declineButton: UIButton!
   @IBOutlet weak var acceptButton: UIButton!
   @IBOutlet weak var webContainer: UIView!
   var webView : WKWebView!
   
   override func viewDidLoad()
   {
      super.viewDidLoad()
      
      webView = WKWebView(frame: webContainer.bounds)
      webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      webContainer.addSubview(webView)
      webView.navigationDelegate = self
      
      var filePath = locBundle.path(forResource: "UserAgreement", ofType: "docx")
      if isNilOrEmpty(filePath) {
         filePath = Bundle.main.path(forResource: "UserAgreement", ofType: "docx")
      }
      
      if let path = filePath
      {
         let url = URL(fileURLWithPath: path)
         webView.loadFileURL(url, allowingReadAccessTo: url)
      }
   }

   override func viewWillAppear(_ animated: Bool)
   {
      super.viewWillAppear(animated)
      navigationController?.setNavigationBarHidden(false, animated: animated)
   }
   
   override func viewDidLayoutSubviews()
   {
      super.viewDidLayoutSubviews()
      declineButton.invalidateIntrinsicContentSize()
      acceptButton.invalidateIntrinsicContentSize()
      bottomView.layoutIfNeeded()
   }
   
   //MARK: - Actions
   
   @IBAction func declineTap()
   {
      RequestManager.logout()
      User.current = nil
      dismiss(animated: true, completion: nil)
   }
   
   @IBAction func acceptTap()
   {
      showAppSpinner()
      
      RequestManager.acceptUserAgreements()
      
      let user = User.current!
      user.modifyWithTransactionIfNeeded {
         user.acceptedUserAgreements = true
      }
      
      RequestManager.updateUserData(
      success:
      {
         hideAppSpinner()
         
         if User.current!.personas.isEmpty {
            AppWindow.rootViewController = Storyboard.instantiateViewController(withIdentifier: "PersonaEditController")
         }
         else {
            AppWindow.rootViewController = Storyboard.instantiateViewController(withIdentifier: "MainTabBarController")
         }
      },
      failure:
      {
         errorDescription in
         hideAppSpinner()
         AlertManager.showAlert(title: loc("Error"), message: errorDescription)
      })
   }
   
   //MARK: - WebView
   
   public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
   {
      if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url
      {
         decisionHandler(.cancel)
         UIApplication.shared.openURL(url)
      }
      else
      {
         decisionHandler(.allow)
      }
   }
}
