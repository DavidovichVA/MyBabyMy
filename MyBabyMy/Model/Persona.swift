//
//  Persona.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/14/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import RealmSwift
import Realm

enum PersonaStatus : String {
   case baby = "Baby"
   case pregnant = "Pregnant"
}

class Persona: Object
{
   dynamic var id = 0
   
   dynamic var user: User!
   
   dynamic var statusString : String = ""
   var status : PersonaStatus
   {
      get {
         if let status = PersonaStatus(rawValue: statusString) {
            return status
         }
         dlog("statusString \(statusString) incorrect")
         return .baby
      }
      set {
         modifyWithTransactionIfNeeded {
            statusString = newValue.rawValue
         }
      }
   }
   
   dynamic var name = ""
   
   dynamic var birthday : DMYDate? = nil
   
   dynamic var pregnancyStartDate : DMYDate? = nil
   
   let photosBaby = List<Media>()
   let videosBaby = List<Media>()
   let photosInDynamicsBaby = List<Media>()
   
   let photosPregnant = List<Media>()
   let videosPregnant = List<Media>()
   let photosInDynamicsPregnant = List<Media>()
   
   let deletedMedias = List<Media>()
   
   override class func primaryKey() -> String? {
      return "id"
   }
   
   override class func ignoredProperties() -> [String] {
      return ["status"]
   }
   
   public func medias(_ status : PersonaStatus, _ type : BabyMediaType) -> List<Media>
   {
      switch (status, type)
      {
         case (.baby, .photo): return photosBaby
         case (.baby, .video): return videosBaby
         case (.baby, .photoInDynamics): return photosInDynamicsBaby
         case (.pregnant, .photo): return photosPregnant
         case (.pregnant, .video): return videosPregnant
         case (.pregnant, .photoInDynamics): return photosInDynamicsPregnant
      }
   }
   
   var lastMedia : Media?
   {
      if !photosBaby.isEmpty || !videosBaby.isEmpty || !photosInDynamicsBaby.isEmpty
      {
         let areInIncreasingOrderBaby : (Media, Media) -> Bool = {m1, m2 in m1.date < m2.date}
         
         let lastBabyPhoto = photosBaby.max(by: areInIncreasingOrderBaby)
         let lastBabyVideo = videosBaby.max(by: areInIncreasingOrderBaby)
         let lastBabyPhotoInDynamics = photosInDynamicsBaby.max(by: areInIncreasingOrderBaby)
         
         var lastBabyMedias : [Media] = []
         for lastBabyMedia in [lastBabyPhoto, lastBabyVideo, lastBabyPhotoInDynamics] {
            if let media = lastBabyMedia {
               lastBabyMedias.append(media)
            }
         }
         return lastBabyMedias.max(by: {m1, m2 in m1.date == m2.date ? (m1.timestamp < m2.timestamp) : (m1.date < m2.date)})
      }
      else if !photosPregnant.isEmpty || !videosPregnant.isEmpty || !photosInDynamicsPregnant.isEmpty
      {
         let areInIncreasingOrderPregnant : (Media, Media) -> Bool = {m1, m2 in m1.pregnancyWeek < m2.pregnancyWeek}
         
         let lastPregnantPhoto = photosPregnant.max(by: areInIncreasingOrderPregnant)
         let lastPregnantVideo = videosPregnant.max(by: areInIncreasingOrderPregnant)
         let lastPregnantPhotoInDynamics = photosInDynamicsPregnant.max(by: areInIncreasingOrderPregnant)
         
         var lastPregnantMedias : [Media] = []
         for lastPregnantMedia in [lastPregnantPhoto, lastPregnantVideo, lastPregnantPhotoInDynamics] {
            if let media = lastPregnantMedia {
               lastPregnantMedias.append(media)
            }
         }         
         return lastPregnantMedias.max(by: {m1, m2 in m1.pregnancyWeek == m2.pregnancyWeek ? (m1.timestamp < m2.timestamp) : (m1.pregnancyWeek < m2.pregnancyWeek)})
      }
      else
      {
         return nil
      }
   }
   
   func medias(status : PersonaStatus, date : DMYDate? = nil, week : Int? = nil) -> [Media]
   {
      var medias : [Media] = []
      switch status
      {
      case .baby:
         if let date = date
         {
            for type in BabyMediaType.allValues
            {
               if let media = mediaBaby(date: date, type: type) {
                  medias.append(media)
               }
            }
         }
         else { return [] }
         
      case .pregnant:
         if let week = week
         {
            for type in BabyMediaType.allValues
            {
               if let media = mediaPregnant(week: week, type: type) {
                  medias.append(media)
               }
            }
         }
         else { return [] }
      }
      return medias
   }
   
   func media(status : PersonaStatus, type : BabyMediaType, date : DMYDate? = nil, week : Int? = nil) -> Media?
   {
      switch status
      {
         case .baby:
            if let date = date { return mediaBaby(date: date, type: type)}
            else { return nil }
         case .pregnant:
            if let week = week { return mediaPregnant(week: week, type: type)}
            else { return nil }
      }
   }
   
   func mediaBaby(date : DMYDate, type : BabyMediaType) -> Media?
   {
      var mediaOfType : List<Media>
      switch type
      {
         case .photo: mediaOfType = photosBaby
         case .video: mediaOfType = videosBaby
         case .photoInDynamics: mediaOfType = photosInDynamicsBaby
      }
      
      let media = mediaOfType.first { m in m.date == date}
      
      return media
   }
   
   func mediaPregnant(week : Int, type : BabyMediaType) -> Media?
   {
      var mediaOfType : List<Media>
      switch type
      {
         case .photo: mediaOfType = photosPregnant
         case .video: mediaOfType = videosPregnant
         case .photoInDynamics: mediaOfType = photosInDynamicsPregnant
      }
      
      let media = mediaOfType.first { m in m.pregnancyWeek == week}
      
      return media
   }
   
   func bestMomentMedias(status : PersonaStatus, type : BabyMediaType) -> Results<Media>
   {
      let mediasList = medias(status, type)
      return mediasList.filter("isBestMoment == true")
   }
   
   @discardableResult
   func addOrUpdate(_ media : Media) -> Media
   {
      if let existedMedia = self.media(status: media.status, type: media.type, date: media.date, week: media.pregnancyWeek)
      {
         existedMedia.modifyWithTransactionIfNeeded
         {            
            existedMedia.timestamp = media.timestamp
            existedMedia.date = media.date
            existedMedia.place = media.place
            existedMedia.weather = media.weather
            existedMedia.isBestMoment = media.isBestMoment
            existedMedia.mirrored = media.mirrored
            existedMedia.link = media.link
            existedMedia.fileLoaded = media.fileLoaded
            existedMedia.checkLoadedFile()
            
            if let realm = self.realm {
               realm.delete(deletedMedias.filter("id == %d", existedMedia.id))
            }
            else {
               while let index = deletedMedias.index(where: { media in media.id == existedMedia.id }) {
                  deletedMedias.remove(objectAtIndex: index)
               }
            }
         }
         
         return existedMedia
      }
      else
      {
         let newMedia = Media(value: media)
         
         modifyWithTransactionIfNeeded
         {
            newMedia.personaId = id
            self.medias(newMedia.status, newMedia.type).append(newMedia)
            
            if let realm = self.realm {
               realm.delete(deletedMedias.filter("id == %d", newMedia.id))
            }
            else {
               while let index = deletedMedias.index(where: { deletedMedia in deletedMedia.id == newMedia.id }) {
                  deletedMedias.remove(objectAtIndex: index)
               }
            }
         }
         
         return newMedia
      }
   }
   
   func getCurrentPregnancyStats() -> (pregnancyWeek : Int, pregnancyBeginWeekDay : Int)?
   {
      guard status == .pregnant, let startDate = pregnancyStartDate?.getDate() else { return nil }
      
      let currentDate = Date()
      let components : Set<Calendar.Component> = [.day]
      let dateComponents = calendar.dateComponents(components, from: startDate, to: currentDate)
      
      guard let pregnancyDays = dateComponents.day else { return nil }
      
      let pregnancyWeek: Int = minmax(5, Int(ceil(Double(pregnancyDays) / 7)), 39)
      
      //Sunday 1, Monday 2, Tuesday 3, Wednesday 4, Thursday 5, Friday 6, Saturday 7
      let weekday = calendar.component(.weekday, from: startDate)
      
      return (pregnancyWeek, weekday)
   }
}
