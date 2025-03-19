//
//  MBMAppDelegate.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 11/16/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit
import RealmSwift
import Alamofire
import Fabric
import Crashlytics
import VK_ios_sdk
import FacebookCore

let Storyboard = UIStoryboard(name: "Main", bundle: nil)
fileprivate(set) var Application : UIApplication!

@UIApplicationMain
class MBMAppDelegate: UIResponder, UIApplicationDelegate
{
   var window: UIWindow?
   var allowLandscapeOrientation = false
   
   //MARK: - Application delegate

   func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool
   {
      Application = application
      
      Fabric.with([Crashlytics.self])
      
      RequestManager.startReachability()
      updateRealm()
      
      SocialManager.setup()
      
      UITableView.appearance().tableFooterView = UIView(frame: .zero)
      
      let tabItemColorNormal = rgb(166, 153, 156)
      let tabItemColorSelected = rgb(255, 120, 154)
      let tabItemFont = UIFont.systemFont(ofSize: 11, weight: UIFontWeightMedium)
      
      let attributesNormal = [NSForegroundColorAttributeName : tabItemColorNormal, NSFontAttributeName : tabItemFont]
      let attributesSelected = [NSForegroundColorAttributeName : tabItemColorSelected, NSFontAttributeName : tabItemFont]
      
      UITabBarItem.appearance().setTitleTextAttributes(attributesNormal, for: .normal)
      UITabBarItem.appearance().setTitleTextAttributes(attributesSelected, for: .selected)
      
      if let user = User.current, !user.token.isEmpty, !user.personas.isEmpty, user.acceptedUserAgreements
      {
         window?.rootViewController = Storyboard.instantiateViewController(withIdentifier: "MainTabBarController")
      }
      
      FacebookCore.SDKApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

//      // for music loading testing
//      let allMusic = Realm.main.objects(MBMusic.self)
//      for music in allMusic {
//         music.deleteMusicFiles()
//      }
      
      _ = appSpinnerImage
      
      UtilityQueue.async
      {
         self.updateMusic()
      }
      
      return true
   }

   func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask
   {
      if allowLandscapeOrientation {
         return .allButUpsideDown
      }
      else {
         return .portrait
      }
   }
   
   func applicationWillResignActive(_ application: UIApplication) {
      // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
      // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
   }

   func applicationDidEnterBackground(_ application: UIApplication) {
      // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
      // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
   }

   func applicationWillEnterForeground(_ application: UIApplication) {
      // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
   }

   func applicationDidBecomeActive(_ application: UIApplication)
   {
      FacebookCore.AppEventsLogger.activate(application)
		sendPendingPurchases()
      updateUserData()
      // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
   }

   func applicationWillTerminate(_ application: UIApplication) {
      // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
   }


   //MARK: - Functions
   
   func logout()
   {
      RequestManager.logout()
      User.current = nil
      updateUserDataRequest?.cancel()
      Synchronization.cancel()
      AppWindow.rootViewController = Storyboard.instantiateInitialViewController()
      for network in SocialNetwork.allValues {
         SocialManager.logout(network)
      }
   }
   
   func sendPendingPurchases()
   {
      guard let user = User.current else { return }
      sendPendingPurchases(Array<Purchase>(user.purchasesQueue), userId : user.id)
   }
   
   private func sendPendingPurchases(_ pendingPurchases : [Purchase], userId : Int)
   {
      guard let purchase = pendingPurchases.first else { return }
      
      RequestManager.purchasePro(purchase,
      success:
      {
         [weak self] in
         dlog("purchased")
         if let user = User.current, user.id == userId
         {
            var pendingPurchases = pendingPurchases
            pendingPurchases.removeFirst()
            self?.sendPendingPurchases(pendingPurchases, userId: userId)
         }
      },
      failure:
      {
         [weak self]
         errorDescription in
         dlog(errorDescription)
         if let user = User.current, user.id == userId
         {
            var pendingPurchases = pendingPurchases
            pendingPurchases.removeFirst()
            self?.sendPendingPurchases(pendingPurchases, userId: userId)
         }
      })      
   }
   
   func updateMusic()
   {
      RequestManager.updateMusicList(
      success:
      {
         let allMusic = Realm.main.objects(MBMusic.self)
         for music in allMusic {
            music.checkSongFile()
         }
         MBMusic.loadMusicFiles()
      })
   }
   
   private var updateUserDataRequest : DataRequest?
   func updateUserData()
   {
      guard User.authorized, updateUserDataRequest == nil else { return }
      
      var request : DataRequest? = nil
      
      request = RequestManager.updateUserData(
      success:
      {
         if request === self.updateUserDataRequest {
            self.updateUserDataRequest = nil
         }
         Synchronization.start()
      },
      failure:
      {
         errorDescription in
         dlog(errorDescription)
         if request === self.updateUserDataRequest {
            self.updateUserDataRequest = nil
         }
      })
   }
   
   //MARK: - Realm
   
   private func updateRealm()
   {
      var version : UInt64 = 0
      
      let config = Realm.Configuration(
         schemaVersion: 38,
         migrationBlock:
         {
            migration, oldSchemaVersion in
            
            version = oldSchemaVersion
            if oldSchemaVersion < 27
            {
               migration.enumerateObjects(ofType: DMYDate.className())
               {
                  oldDate, newDate in
                  let day = oldDate!["day"] as! Int
                  let month = oldDate!["month"] as! Int
                  let year = oldDate!["year"] as! Int
                  newDate!["id"] = year * 10000 + month * 100 + day
               }
            }
            if oldSchemaVersion < 33
            {
               migration.deleteData(forType: DisplayedMonth.className())
            }
            if oldSchemaVersion < 38
            {
               migration.enumerateObjects(ofType: Media.className())
               {
                  oldMedia, newMedia in
                  let isImage = (oldMedia!["typeInt"] as! Int) != 1
                  newMedia!["isPNG"] = isImage
               }
            }
         }
      )
      
      Realm.Configuration.defaultConfiguration = config
      _ = Realm.main
      
      
      if version > 0 && version < 35
      {         
         delay(2) {
            AlertManager.showAlert(title: "Требуется переустановка", message: "Для корректной работы удалите и установите приложение заново", completion: { exit(0) })
         }
      }
   }
   
   //MARK: - Social
   
   func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool
   {
      let sourceApplication = options[.sourceApplication] as? String ?? ""
      
      if VKSdk.processOpen(url, fromApplication: sourceApplication) {
         return true
      }
      else if FacebookCore.SDKApplicationDelegate.shared.application(app, open: url, options: options) {
         return true
      }
      
      return false
   }
}

