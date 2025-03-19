//
//  User.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/12/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import RealmSwift

extension Notification.Name
{
   static let MBUserProChanged = Notification.Name("MBUserProChangedNotificationName")
}
let kUserProChangedStatus = "UserProChangedStatus"
let kUserProChangedTime = "UserProChangedTime"

/// пользователь приложения
class User: Object
{
   /// id
   dynamic var id = 0
	
   /// токен API
   dynamic var token = ""
   
   dynamic var proExpirationTime : Date?
	let purchasesQueue = List<Purchase>()
   
   var isPro : Bool
   {
      if let expirationDate = proExpirationTime, expirationDate > Date() {
         return true
      }
      else {
         return false
      }
   }
   
   func setPro(_ newExpirationDate : Date?)
   {
      let wasPro = isPro
      let oldExpirationTime = proExpirationTime
      
      if let newExpirationDate = newExpirationDate
      {
         var newDate = newExpirationDate
         if !purchasesQueue.isEmpty, let expirationDate = proExpirationTime {
            newDate = max(expirationDate, newExpirationDate)
         }
         
         modifyWithTransactionIfNeeded {
            proExpirationTime = newDate
         }
      }
      else if purchasesQueue.isEmpty
      {
         modifyWithTransactionIfNeeded {
            proExpirationTime = nil
         }
      }
      
      let statusChanged = (wasPro != isPro)
      let expirationTimeChanged =
         (oldExpirationTime == nil && proExpirationTime != nil) ||
         (oldExpirationTime != nil && proExpirationTime == nil) ||
         (oldExpirationTime != nil && proExpirationTime != nil && oldExpirationTime! != proExpirationTime!)
      let info = [kUserProChangedStatus : statusChanged, kUserProChangedTime : expirationTimeChanged]
      
      MainQueue.async {
         NotificationCenter.default.post(name: .MBUserProChanged, object: self, userInfo: info)
      }
   }
   
   dynamic var acceptedUserAgreements = false
   
   /// есть ли у пользователя авторизация по логину с паролем
   dynamic var authorizationWithEmail = false
   dynamic var email = ""
   
   /// подключен ли аккаунт в Instagram
   dynamic var instagramConnected = false
   /// email в Instagram
   dynamic var instagramEmail = ""
   /// имя в Instagram
   dynamic var instagramName = ""
   
   var instagramAccDisplayedName : String
   {
      var displayedName = loc("No connection")
      if instagramConnected
      {
         if !instagramEmail.isEmpty
         {
            if !instagramName.isEmpty {
               displayedName = "\(instagramName) (\(instagramEmail))"
            }
            else {
               displayedName = instagramEmail
            }
         }
         else {
            displayedName = instagramName.isEmpty ? " " : instagramName
         }
      }
      return displayedName
   }
   
   
   /// подключен ли аккаунт в Facebook
   dynamic var facebookConnected = false
   /// email в Facebook
   dynamic var facebookEmail = ""
   /// имя в Facebook
   dynamic var facebookName = ""
   
   var facebookAccDisplayedName : String
   {
      var displayedName = loc("No connection")
      if facebookConnected
      {
         if !facebookEmail.isEmpty
         {
            if !facebookName.isEmpty {
               displayedName = "\(facebookName) (\(facebookEmail))"
            }
            else {
               displayedName = facebookEmail
            }
         }
         else {
            displayedName = facebookName.isEmpty ? " " : facebookName
         }
      }
      return displayedName
   }
   
   
   /// подключен ли аккаунт Вконтакте
   dynamic var vkConnected = false
   /// email Вконтакте
   dynamic var vkEmail = ""
   /// имя в Вконтакте
   dynamic var vkName = ""
   
   var vkAccDisplayedName : String
   {
      var displayedName = loc("No connection")
      if vkConnected
      {
         if !vkEmail.isEmpty
         {
            if !vkName.isEmpty {
               displayedName = "\(vkName) (\(vkEmail))"
            }
            else {
               displayedName = vkEmail
            }
         }
         else {
            displayedName = vkName.isEmpty ? " " : vkName
         }
      }
      return displayedName
   }
   
   
   /// персонажи, в порядке расположения: center, left, right
   let personas = List<Persona>()
   
   var welcomeAnimationShown = false
   
   var mainPersona : Persona
   {
      get {
         return personas.first!
      }
      
      set(newMain)
      {
         let transactionNeeded = {
            return !(self.realm?.isInWriteTransaction ?? true)
         }
         var commitNeeded = false
         
         if !personas.contains(newMain)
         {
            if personas.count >= 3 {return}
            else {
               if transactionNeeded() { realm?.beginWrite(); commitNeeded = true }
               personas.append(newMain)
            }
         }
         
         let index = personas.index(of: newMain)!
         if index != 0 {
            if transactionNeeded() { realm?.beginWrite(); commitNeeded = true }
            personas.swap(index1: 0, index)
         }
         if commitNeeded { try? realm?.commitWrite() }
      }
   }
   
   dynamic var syncMedias = true
   dynamic var syncMediasWiFiOnly = false
   
   dynamic var syncSongs = true
   dynamic var syncSongsWiFiOnly = false
   
   override class func primaryKey() -> String? {
      return "id"
   }
   
   override class func ignoredProperties() -> [String] {
      return ["mainPersona", "welcomeAnimationShown"]
   }
   
   /// создает или получает существующего пользователя
   class func user(_ userId: Int?) -> User?
   {
      guard let id = userId, id != 0 else {
         return nil
      }
      
      let defaultRealm = Realm.main
      
      if let user = defaultRealm.object(ofType: User.self, forPrimaryKey: id) {
         return user
      }
      
      let user = User()
      user.id = id
      defaultRealm.writeWithTransactionIfNeeded {
         defaultRealm.add(user)
      }
      return user
   }
   
   /// текущий пользователь, main thread
   public static var current : User? =
   {
      let userId = UserDefaults.standard.integer(forKey: "lastUserId")
      if userId == 0 { return nil }
      
      if let user = Realm.main.object(ofType: User.self, forPrimaryKey: userId), !user.token.isEmpty {
         currentUserId = user.id
         currentUserToken = user.token
         return user
      }
      else {
         return nil
      }
   }()
   {
      didSet {
         UserDefaults.standard.set(current?.id ?? 0, forKey: "lastUserId")
         currentUserId = current?.id
         currentUserToken = current?.token
      }
   }
   
   public static var currentUserId : Int? = nil
   public static var currentUserToken : String? = nil
   
   public static var authorized : Bool {
      return currentUserId != nil
   }
}
