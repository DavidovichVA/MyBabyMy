//
//  Media.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/14/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import RealmSwift

enum BabyMediaType : Int
{
   case photo = 0
   case video = 1
   case photoInDynamics = 2
   
   static let allValues = [photo, video, photoInDynamics]
}

class Media: Object
{
   dynamic var id = 0
   
   dynamic var typeInt = 0
   var type : BabyMediaType
   {
      get {
         if let type = BabyMediaType(rawValue: typeInt) {
            return type
         }
         dlog("typeInt \(typeInt) incorrect")
         return .photo
      }
      set {
         modifyWithTransactionIfNeeded {
            typeInt = newValue.rawValue
         }
      }
   }
   
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
   
   /// Время последнего изменения, в секундах
   dynamic var timestamp : Int64 = 0
   
   dynamic var place = ""
   
   dynamic var personaId : Int = 0
   
   var persona : Persona?
   {
      get
      {
         if personaId == 0 { return nil }
         return (realm ?? Realm.main).object(ofType: Persona.self, forPrimaryKey: personaId)
      }
      set
      {
         modifyWithTransactionIfNeeded {
            personaId = newValue?.id ?? 0
         }
      }
   }
   
   var user : User? {
      return persona?.user
   }
   
   dynamic var isBestMoment = false
   
   dynamic var weather = ""
   
   dynamic var date : DMYDate!
   dynamic var pregnancyWeek : Int = 0
   
   dynamic var mirrored = false
   
   dynamic var videoDuration : Double = 0
   
   dynamic var link: String? = nil
   
   dynamic var fileLoaded = false
   
   //old variant images
   dynamic var isPNG = false
   
   override class func ignoredProperties() -> [String] {
      return ["type", "status", "persona", "user", "getCurrentPositionKey"]
   }
   
   var isCurrent : Bool
   {
      switch status
      {
      case .baby: return (date == DMYDate.currentDate())
      case .pregnant: return (pregnancyWeek == persona?.getCurrentPregnancyStats()?.pregnancyWeek)
      }
   }
   
   /// комбинация пользователя, персоны, типа и даты/недели
   var equalityValue : String {
      return fileNameWithoutExtension
   }
   
   private var fileNameWithoutExtension : String
   {
      switch status
      {
         case .baby: return "baby_\(personaId)_\(typeInt)_\(date.hash)"
         case .pregnant: return "pregnancy_\(personaId)_\(typeInt)_\(pregnancyWeek)"
      }
   }
   var fileName : String
   {
      switch type {
         case .photo, .photoInDynamics: return fileNameWithoutExtension + (isPNG ? ".png" : ".jpg")
         case .video: return fileNameWithoutExtension + ".mp4"
      }
   }
   var filePath : String {
      return documentsDirectory.appendingPathComponent(fileName)
   }
   var fileURL : URL {
      return URL(fileURLWithPath: filePath)
   }
   
   var thumbnailName : String {
      return fileNameWithoutExtension + "_thumbnail.png"
   }
   var thumbnailPath : String {
      return documentsDirectory.appendingPathComponent(thumbnailName)
   }
   var thumbnailURL : URL {
      return URL(fileURLWithPath: thumbnailPath)
   }
   
   
   @discardableResult
   func checkLoadedFile() -> Bool
   {
      guard fileLoaded else { return false }
      if FileManager.default.isReadableFile(atPath: filePath)
      {
         if type == .video && videoDuration == 0
         {
            let duration = getVideoDuration(fileURL)
            if duration > 0
            {
               modifyWithTransactionIfNeeded {
                  videoDuration = duration
               }
            }
         }
         return true
      }
      else {
         modifyWithTransactionIfNeeded
         {
            let cacheKey = equalityValue as NSString
            Media.thumbnailCache.removeObject(forKey: cacheKey)
            fileLoaded = false
            videoDuration = 0
         }
         return false
      }
   }
   
   @discardableResult
   func save(image : UIImage) -> String?
   {
      guard type != .video else { return "Wrong media type" }
      let normalizedImage = image.normalizingOrientation()
      guard let imageData = UIImageJPEGRepresentation(normalizedImage, 0.8) else { return "Error generating image data" }
      
      let url = fileURL
      let cacheKey = equalityValue as NSString
      
      do {
         try imageData.write(to: url)
         
         modifyWithTransactionIfNeeded {
            fileLoaded = true
            link = nil
            isPNG = false
         }
         exlcudeFromBackup(url)
         
         Media.thumbnailCache.removeObject(forKey: cacheKey)
         if FileManager.default.fileExists(atPath: thumbnailPath) {
             try FileManager.default.removeItem(at: thumbnailURL)
         }
         return nil
      }
      catch let error {
         return error.localizedDescription
      }
   }
   
   @discardableResult
   func save(video videoURL : URL) -> String?
   {
      guard type == .video else { return "Wrong media type" }
      guard videoURL.isFileURL else { return "Media URL is not local file" }
      
      let url = fileURL
      let cacheKey = equalityValue as NSString
      
      do {
         let tempFileURL = URL(fileURLWithPath: tempDirectory).appendingPathComponent(NSUUID().uuidString, isDirectory: false)
         try FileManager.default.copyItem(at: videoURL, to: tempFileURL)
         try _ = FileManager.default.replaceItemAt(url, withItemAt: tempFileURL)
         
         let duration = getVideoDuration(url)
         modifyWithTransactionIfNeeded {
            fileLoaded = true
            link = nil
            videoDuration = duration
         }
         
         exlcudeFromBackup(url)
         
         Media.thumbnailCache.removeObject(forKey: cacheKey)
         if FileManager.default.fileExists(atPath: thumbnailPath) {
            try FileManager.default.removeItem(at: thumbnailURL)
         }
         return nil
      }
      catch let error {
         return error.localizedDescription
      }
   }
   
   private var getCurrentPositionKey : String? = nil
   func autoFillCurrentPlace(_ completion : @escaping (Bool) -> () = {_ in})
   {
      guard !isInvalidated, place.isEmpty else {
         completion(false)
         return
      }
      
      if geolocationPermission != .forbidden && isInternetConnection
      {
         getCurrentPositionKey = LocationManager.getCurrentPosition(
         {
            location in
            
            self.getCurrentPositionKey = nil
            RequestManager.googleGetCityName(location.coordinate,
            success:
            {
               cityName in
               guard !self.isInvalidated else { completion(false); return }
               self.modifyWithTransactionIfNeeded {
                  self.place = cityName
               }
               completion(true)
            },
            failure:
            {
               errorDescription in
               dlog(errorDescription)
               guard !self.isInvalidated else { completion(false); return }
               let setFromHistory = self.autoFillPlaceFromHistory()
               completion(setFromHistory)
            })
         })
         
         if getCurrentPositionKey == nil
         {
            let setFromHistory = autoFillPlaceFromHistory()
            completion(setFromHistory)
         }
      }
      else
      {
         let setFromHistory = autoFillPlaceFromHistory()
         completion(setFromHistory)
      }
   }
   
   func autoFillPlaceFromHistory() -> Bool
   {
      guard !isInvalidated else { return false }
      if let personLastMediaWithPlace = Realm.main.objects(Media.self).filter("personaId == %@ AND place != ''", personaId).sorted(byKeyPath: "timestamp", ascending: false).first
      {
         modifyWithTransactionIfNeeded {
            place = personLastMediaWithPlace.place
         }
         return true
      }
      else {
         return false
      }
   }
   
   func autoFillCurrentWeather(_ completion : @escaping (Bool) -> () = {_ in})
   {
      guard !isInvalidated, weather.isEmpty else {
         completion(false)
         return
      }
      
      let fillFromWeather : (Weather) -> () =
      {
         weather in
         
         guard !self.isInvalidated else { completion(false); return }
         
         let typeString = weather.type.rawValue
         let temperature = Int(round(weather.temperature))
         var temperatureString = String(temperature)
         if temperature > 0 {
            temperatureString = "+" + temperatureString
         }
         else if temperature < 0 {
            temperatureString = "-" + temperatureString
         }
         
         self.modifyWithTransactionIfNeeded {
            self.weather = "\(typeString) \(temperatureString)"
         }
         completion(true)
      }
      
      if let lastWeather = Weather.lastKnown, lastWeather.isMoreOrLessActual {
         fillFromWeather(lastWeather)
      }
      else
      {
         Weather.getCurrentWeatherTime(
         {
            _ in
            if let lastWeather = Weather.lastKnown, lastWeather.isMoreOrLessActual {
               fillFromWeather(lastWeather)
            }
            else {
               completion(false)
            }
         })
      }
   }
   
   func delete()
   {
      let cacheKey = equalityValue as NSString
      Media.thumbnailCache.removeObject(forKey: cacheKey)
      
      try? FileManager.default.removeItem(at: fileURL)
      try? FileManager.default.removeItem(at: thumbnailURL)
      if let realm = self.realm
      {
         realm.writeWithTransactionIfNeeded
         {
            if let person = persona, id != 0, !person.deletedMedias.contains(where: { $0.id == id })
            {
               let media = Media(value: self)
               media.personaId = 0
               media.fileLoaded = false
               media.videoDuration = 0
               media.timestamp = Int64(Date().timeIntervalSince1970)
               person.deletedMedias.append(media)
            }
            realm.delete(self)
         }
      }
      else {
         fileLoaded = false
      }
   }
   
   func deleteMediaFiles()
   {
      let cacheKey = equalityValue as NSString
      Media.thumbnailCache.removeObject(forKey: cacheKey)
      
      try? FileManager.default.removeItem(at: fileURL)
      try? FileManager.default.removeItem(at: thumbnailURL)
      modifyWithTransactionIfNeeded {
         fileLoaded = false
         videoDuration = 0
      }
   }
   
   func getImage() -> UIImage?
   {
      guard type != .video else { return nil }
      let image = UIImage(contentsOfFile: filePath)
      return image
   }
   
   func getImage(_ callback : @escaping (UIImage?) -> Void)
   {
      guard type != .video else { callback(nil); return }
      let path = filePath
      UserInitiatedQueue.async
      {
         let image = UIImage(contentsOfFile: path)
         MainQueue.async { callback(image) }
      }
   }
}


import AVFoundation

fileprivate let thumbnailSize : CGSize = CGSize.square(ceil(48 * WidthRatio))

func getVideoDuration(_ videoFileURL : URL) -> Double
{
   let asset = AVURLAsset(url: videoFileURL)
   return asset.duration.seconds
}

extension Media
{
   fileprivate static let thumbnailCache : NSCache<NSString, UIImage> = NSCache()
   
   func getThumbnailImage(_ callback : @escaping (UIImage?) -> Void)
   {
      guard fileLoaded else { callback(nil); return }
      
      let cacheKey = equalityValue as NSString
      if let thumbnail = Media.thumbnailCache.object(forKey: cacheKey) {
//         dlog("using cached thumbnail")
         callback(thumbnail)
         return
      }
      
      let thumbnailPath = self.thumbnailPath
      if let thumbnail = UIImage(contentsOfFile: thumbnailPath)
      {
//         dlog("using existed thumbnail")
         Media.thumbnailCache.setObject(thumbnail, forKey: cacheKey, cost: Int(thumbnail.size.width * thumbnail.size.height))
         callback(thumbnail)
         return
      }
      
      let mediaType = self.type
      let filePath = self.filePath
      let fileURL = URL(fileURLWithPath: filePath)
      let thumbnailURL = URL(fileURLWithPath: thumbnailPath)
      
      UserInitiatedQueue.async
      {
         switch mediaType
         {
         case .photo, .photoInDynamics :
            guard let image = UIImage(contentsOfFile: filePath) else {
               MainQueue.async{ callback(nil) }
               return
            }
            
//            dlog("generating photo thumbnail")
            
            let thumbnail = image.constrained(to: thumbnailSize, mode: .scaleAspectFill)
            Media.thumbnailCache.setObject(thumbnail, forKey: cacheKey, cost: Int(thumbnail.size.width * thumbnail.size.height))
            MainQueue.async { callback(thumbnail) }
            
            if let imageData = UIImagePNGRepresentation(thumbnail) {
               try? imageData.write(to: thumbnailURL)
            }
            
         case .video :
            guard FileManager.default.isReadableFile(atPath: filePath) else {
               MainQueue.async { callback(nil) }
               return
            }
            
//            dlog("generating video thumbnail")
            
            let asset = AVURLAsset(url: fileURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            
            let durationInSeconds = asset.duration.seconds
            let thumbTime = CMTime(seconds: durationInSeconds / 2, preferredTimescale: 600)
            
            var image : UIImage? = nil
            
            let tryCount = 5
            for i in 0..<tryCount
            {
               var imageRef : CGImage? = nil
               do {
                  imageRef = try generator.copyCGImage(at: thumbTime, actualTime: nil)
               }
               catch let error as NSError
               {
                  if (error.code == -11800)
                  {
                     if (i < tryCount - 1) {
                        dlog("retry to generate video thumbnail")
                        continue
                     }
                     else {
                        dlog("failed to generate video thumbnail")
                        break
                     }
                  }
               }
               
               if let ref = imageRef {
                  image = UIImage(cgImage: ref)
               }
               
               if image != nil { break }
            }

            if let thumbnail = image?.constrained(to: thumbnailSize, mode: .scaleAspectFill)
            {
               Media.thumbnailCache.setObject(thumbnail, forKey: cacheKey, cost: Int(thumbnail.size.width * thumbnail.size.height))
               
               MainQueue.async { callback(thumbnail) }
               
               if let imageData = UIImagePNGRepresentation(thumbnail) {
                  try? imageData.write(to: thumbnailURL)
               }
            }
            else
            {
               MainQueue.async { callback(nil) }
            }
         }
      }
   }
}
