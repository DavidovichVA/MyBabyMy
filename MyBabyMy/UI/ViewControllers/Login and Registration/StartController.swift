//
//  StartController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 11/29/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit

class StartController: UIViewController
{
   override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)
      navigationController?.setNavigationBarHidden(true, animated: animated)
   }
   
   func socialLogin(_ network : SocialNetwork)
   {
      SocialManager.login(network, presentingController: self,
      success:
      {
         user in         
         User.current = user
         
         if user.acceptedUserAgreements
         {
            showAppSpinner()
            RequestManager.updateUserData(
            success:
            {
               hideAppSpinner()
               
               if user.personas.isEmpty {
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
         else
         {
            self.performSegue(withIdentifier: "ShowTerms", sender: self)
         }
      },
      failure:
      {
         errorDescription in
         AlertManager.showAlert(title: loc("Error"), message: errorDescription)
      })
   }
   
   @IBAction func instagramTap() {
      socialLogin(.instagram)
   }
   
   @IBAction func facebookTap() {
      socialLogin(.facebook)
   }
   
   @IBAction func vkTap() {
      socialLogin(.vk)
   }
}
