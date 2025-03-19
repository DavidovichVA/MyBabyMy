//
//  RequestModelHelper.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/15/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import SwiftyJSON
import RealmSwift

final class RequestModelHelper
{
   class func userFromAuthData(_ data : [String : JSON]) -> User?
   {
      let userId = data["userId"]?.intValue ?? 0
      if userId == 0 {return nil}
      
      let token = data["token"]?.stringValue ?? ""
      if isNilOrEmpty(token) {return nil}
      
      let pro = data["pro"]?.bool ?? true
      var proExpirationDate : Date? = nil
      if pro
      {
         let proExpirationString = data["proExpirationTime"]?.stringValue ?? ""
         proExpirationDate = DMYDate.dateFromString(proExpirationString)?.getDate()
      }
      
      let acceptedUserAgreements = data["acceptUserAgreements"]?.bool ?? false
      
      if let user = User.user(userId)
      {
         user.modifyWithTransactionIfNeeded
         {
            user.token = token
            user.acceptedUserAgreements = acceptedUserAgreements
            if let expirationDate = proExpirationDate {
               user.setPro(expirationDate)
            }
            else if !pro {
               user.setPro(nil)
            }
         }
         return user
      }
      else {
         return nil
      }
   }
   
   class func createPersonaWithData(_ data : [String : JSON], status : PersonaStatus) -> Persona?
   {
      guard let user = User.current else { return nil }
      
      let personId = data["id"]?.intValue ?? 0
      if personId == 0 {return nil}
      
      let defaultRealm = Realm.main
      if defaultRealm.object(ofType: Persona.self, forPrimaryKey: personId) != nil
      {
         AlertManager.showAlert("Persona already exists")
         return nil
      }
      let persona = Persona()
      persona.id = personId
      
      guard let name = data["name"]?.string else { return nil }
      persona.name = name
      
      switch status
      {
      case .baby:
         guard let birthdayString = data["birthday"]?.stringValue, let birthday = DMYDate.dateFromString(birthdayString) else { return nil }
         persona.birthday = birthday
         
      case .pregnant:
         guard let pregnancyString = data["pregnancyStartDate"]?.stringValue, let pregnancyStartDate = DMYDate.dateFromString(pregnancyString) else { return nil }
         persona.pregnancyStartDate = pregnancyStartDate
      }
      persona.status = status
      
      defaultRealm.writeWithTransactionIfNeeded {
         persona.user = user
         user.mainPersona = persona
      }
      
      return persona
   }
   
   class func updateUserData(_ data : [String : JSON]) -> Bool
   {
      guard let user = User.current else { return false }
      
      guard let nativeAuthExist = data["nativeAuthExist"]?.bool else { return false }
      
      guard let instagramExist = data["instagramIdExist"]?.bool else { return false }
      let instagramEmail = data["instaEmail"]?.string
      let instagramName = data["instaName"]?.string
      
      guard let facebookExist = data["facebookIdExist"]?.bool else { return false }
      let facebookEmail = data["fbEmail"]?.string
      let facebookName = data["fbName"]?.string
      
      guard let vkExist = data["vkIdExist"]?.bool else { return false }
      let vkEmail = data["vkEmail"]?.string
      let vkName = data["vkName"]?.string
      
      let pro = data["pro"]?.bool ?? true
      var proExpirationDate : Date? = nil
      if pro
      {
         let proExpirationString = data["proExpirationTime"]?.stringValue ?? ""
         proExpirationDate = DMYDate.dateFromString(proExpirationString)?.getDate()
      }
      
      guard let personaList = data["babyList"]?.array else { return false }
      
      var dataPersonas : [Persona] = []
      for personaData in personaList
      {
         guard let data = personaData.dictionary else { continue }
         if let persona = personaFromData(data) {
            dataPersonas.append(persona)
         }
         else {
            dlog("Wrong persona data")
         }
      }
      
      let realm : Realm = user.realm ?? Realm.main
      
      realm.writeWithTransactionIfNeeded
      {
         if let expirationDate = proExpirationDate {
            user.setPro(expirationDate)
         }
         else if !pro {
            user.setPro(nil)
         }
         
         if nativeAuthExist {
            user.authorizationWithEmail = true
         }
         else if !user.authorizationWithEmail {
            user.email = ""
         }
         
         if instagramExist
         {
            user.instagramConnected = true
            if !isNilOrEmpty(instagramEmail) { user.instagramEmail = instagramEmail! }
            if !isNilOrEmpty(instagramName) { user.instagramName = instagramName! }
         }
         else
         {
            user.instagramConnected = false
            user.instagramName = ""
            user.instagramEmail = ""
         }
         
         if facebookExist
         {
            user.facebookConnected = true
            if !isNilOrEmpty(facebookEmail) { user.facebookEmail = facebookEmail! }
            if !isNilOrEmpty(facebookName) { user.facebookName = facebookName! }
         }
         else
         {
            user.facebookConnected = false
            user.facebookName = ""
            user.facebookEmail = ""
         }
         
         if vkExist
         {
            user.vkConnected = true
            if !isNilOrEmpty(vkEmail) { user.vkEmail = vkEmail! }
            if !isNilOrEmpty(vkName) { user.vkName = vkName! }
         }
         else
         {
            user.vkConnected = false
            user.vkName = ""
            user.vkEmail = ""
         }
         
         var userPersonas = Array<Persona>(user.personas)
         
         for dataPersona in dataPersonas
         {
            if let userPersona = user.personas.first(where: { $0.id == dataPersona.id})
            {
               userPersona.name = dataPersona.name
               userPersona.birthday = dataPersona.birthday
               userPersona.statusString = dataPersona.statusString
               userPersona.pregnancyStartDate = dataPersona.pregnancyStartDate
               
               userPersonas.removeObject(userPersona)
               
               userPersona.user = user
            }
            else {
               realm.add(dataPersona, update: true)
               user.personas.append(dataPersona)
               dataPersona.user = user
            }
         }
         
         for oldPersonaLeft in userPersonas {
            deletePersona(oldPersonaLeft)
         }
      }
      
      return true
   }
   
   /// returns new, unpersisted persona
   class func personaFromData(_ data : [String : JSON]) -> Persona?
   {
      let personId = data["id"]?.intValue ?? 0
      if personId == 0 {return nil}
      
      guard let name = data["name"]?.string else { return nil }
      
      guard let birthdayString = data["birthday"]?.stringValue else { return nil }
      let birthday = DMYDate.dateFromString(birthdayString)
      
      guard let statusString = data["babyStatus"]?.string,
            PersonaStatus(rawValue: statusString) != nil else { return nil }
      
      guard let pregnancyDateString = data["pregnancyStartDate"]?.stringValue else { return nil }
      let pregnancyStartDate = DMYDate.dateFromString(pregnancyDateString)
      
      let persona = Persona()
      persona.id = personId
      persona.name = name
      persona.birthday = birthday
      persona.statusString = statusString
      persona.pregnancyStartDate = pregnancyStartDate
      
      return persona
   }
   
   class func deletePersona(_ persona : Persona)
   {
      let realm = persona.realm ?? Realm.main
      
      realm.writeWithTransactionIfNeeded
      {
         if let birthday = persona.birthday {
            birthday.realm?.delete(birthday)
         }
         if let pregnancyStartDate = persona.pregnancyStartDate {
            pregnancyStartDate.realm?.delete(pregnancyStartDate)
         }
 
         let personaMedias = realm.objects(Media.self).filter("personaId == %d", persona.id)
         for media in personaMedias
         {
            let fileURL = media.fileURL
            let thumbnailURL = media.thumbnailURL
            BackgroundQueue.async
            {
               try? FileManager.default.removeItem(at: fileURL)
               try? FileManager.default.removeItem(at: thumbnailURL)
            }
            media.realm?.delete(media)
         }
         
         persona.realm?.delete(persona.deletedMedias)
         
         persona.realm?.delete(persona)
      }
   }
   
   /// returns new, unpersisted medias
   class func mediasFromData(_ datas : [JSON]) -> [Media]
   {
      var medias : [Media] = []
      
      for data in datas
      {
         if let dataDict = data.dictionary, let media = mediaFromData(dataDict) {
            medias.append(media)
         }
      }
      
      return medias
   }
   
   /// returns new, unpersisted media
   class func mediaFromData(_ data : [String : JSON]) -> Media?
   {
      let mediaId = data["id"]?.intValue ?? 0
      if mediaId == 0 {return nil}
      
      let personId = data["babyId"]?.intValue ?? 0
      if personId == 0 {return nil}
      
      guard let mediaTypeString = data["mediaType"]?.stringValue else { return nil }
      let mediaType : BabyMediaType
      switch mediaTypeString
      {
         case "Photo": mediaType = .photo
         case "Video": mediaType = .video
         case "PhotoDynamic": mediaType = .photoInDynamics
         default: return nil
      }
      
      let place = data["place"]?.stringValue ?? ""
      let bestMoment = data["bestMoment"]?.bool ?? false
      let weather = data["weather"]?.stringValue ?? ""
      
      let status : PersonaStatus
      var date : DMYDate? = nil
      var week : Int = 0
      if let babyDateString = data["dateString"]?.stringValue, let babyDate = DMYDate.dateFromString(babyDateString)
      {
         status = .baby
         date = babyDate
      }
      else if let pregnancyWeek = data["pregnancyWeek"]?.intValue, 5...39 ~= pregnancyWeek
      {
         status = .pregnant
         week = pregnancyWeek
      }
      else { return nil }
      
      let link = data["url"]?.string
      let mirrored = data["mirrored"]?.boolValue ?? false
      let lastUpdate : Int64 = data["lastUpdate"]?.int64Value ?? 0
      
      let media = Media()
      media.id = mediaId
      media.personaId = personId
      media.type = mediaType
      media.place = place
      media.isBestMoment = bestMoment
      media.weather = weather
      media.status = status
      media.date = date
      media.pregnancyWeek = week
      media.link = link
      media.mirrored = mirrored
      media.timestamp = lastUpdate
      
      return media
   }
   
   class func updateMusicList(_ data : [JSON]) -> Bool
   {
      var songs : [(id : Int, name : String, imageLink : String, songLink : String, songFileType : String?)] = []
      
      for songData in data
      {
         guard songData.type == .dictionary else { return false }
         guard let id = songData["id"].int, id != 0 else { return false }
         guard let name = songData["name"].string else { return false }
         guard let songLink = songData["fileUrl"].string, !songLink.isEmpty else { return false }
         let songFileType = songData["fileType"].string
         let imageLink = songData["imageUrl"].stringValue
         
         songs.append((id, name, imageLink, songLink, songFileType))
      }
      
      let realm = Realm.main
      realm.writeWithTransactionIfNeeded
      {
         var oldSongs = Array<MBMusic>(realm.objects(MBMusic.self))
         
         for songData in songs
         {
            var song : MBMusic
            if let existingSong = realm.object(ofType: MBMusic.self, forPrimaryKey: songData.id) {
               song = existingSong
               oldSongs.removeObject(existingSong)
            }
            else {
               song = MBMusic()
               song.id = songData.id
            }
            
            if song.title != songData.name {
               song.title = songData.name
            }
            
            if song.imageLink != songData.imageLink
            {
               song.imageLink = songData.imageLink
               song.imageLoaded = false
            }
            if song.songLink != songData.songLink
            {
               song.songLink = songData.songLink
               song.songLoaded = false
            }
            if song.songFileType != songData.songFileType
            {
               song.songFileType = songData.songFileType
               song.songLoaded = false
            }
            
            if song.realm == nil { realm.add(song, update: true)}
         }
         
         for oldSong in oldSongs
         {
            oldSong.deleteMusicFiles()
            realm.delete(oldSong)            
         }
      }
      
      return true
   }
}
