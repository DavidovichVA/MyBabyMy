//
//  MBMusic.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 1/24/17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import RealmSwift

class MBMusic: Object
{
   dynamic var id = 0
   
   dynamic var title = ""
   dynamic var songLink = ""
   dynamic var songFileType : String? = nil
   dynamic var imageLink = ""
   
   dynamic var imageLoaded = false
   dynamic var songLoaded = false
   
   override class func primaryKey() -> String? {
      return "id"
   }
   
   var songUrl : URL
   {
      if songLoaded {
         return songFileURL
      }
      else if let url = URL(string: songLink) {
         return url
      }
      else {
         dlog("error in song url", songLink)
         return URL(string: "http://185.47.62.107:8080/downloadFile/d028833fd76347daa5c3ad8c2bfc9b89")!
      }
   }
   
   var songFileName : String
   {
      var name = "music_\(id)"
      if let fileType = songFileType, !fileType.isEmpty {
         name += ".\(fileType)"
      }
      return name
   }
   var songFilePath : String {
      return documentsDirectory.appendingPathComponent(songFileName)
   }
   var songFileURL : URL {
      return URL(fileURLWithPath: songFilePath)
   }
   
   
   var thumbnailName : String {
      return "music_\(id)_thumbnail.png"
   }
   var thumbnailPath : String {
      return documentsDirectory.appendingPathComponent(thumbnailName)
   }
   var thumbnailURL : URL {
      return URL(fileURLWithPath: thumbnailPath)
   }
   
   @discardableResult
   func checkSongFile() -> Bool
   {
      guard songLoaded else { return false }
      if FileManager.default.isReadableFile(atPath: songFilePath) {
         return true
      }
      else {
         modifyWithTransactionIfNeeded {
            songLoaded = false
         }
         return false
      }
   }
   
   
   @discardableResult
   func save(image : UIImage, url : URL? = nil) -> String?
   {
      let thumbnail = image.constrained(to: musicThumbnailSize, mode: .scaleAspectFill)
      
      guard let imageData = UIImagePNGRepresentation(thumbnail) else { return "Error generating image data" }
      let fileUrl = url ?? thumbnailURL
      
      do {
         try imageData.write(to: fileUrl)
         exlcudeFromBackup(fileUrl)
         return nil
      }
      catch let error {
         return error.localizedDescription
      }
   }
   
   func deleteMusicFiles()
   {
      let cacheKey = imageLink as NSString
      MBMusic.thumbnailCache.removeObject(forKey: cacheKey)
      
      try? FileManager.default.removeItem(at: songFileURL)
      try? FileManager.default.removeItem(at: thumbnailURL)
      modifyWithTransactionIfNeeded
      {
         songLoaded = false
         imageLoaded = false
      }
   }
   
   private static let thumbnailCache : NSCache<NSString, UIImage> = NSCache()
   
   class func clearThumbnailCache() {
      MBMusic.thumbnailCache.removeAllObjects()
   }
   
   func getThumbnail() -> UIImage?
   {
      guard imageLoaded else { return nil }
      guard !imageLink.isEmpty else { return nil }
      
      let cacheKey = imageLink as NSString
      
      if let image = MBMusic.thumbnailCache.object(forKey: cacheKey) {
         return image
      }
      else
      {
         if let image = UIImage(contentsOfFile: thumbnailPath)
         {
            MBMusic.thumbnailCache.setObject(image, forKey: cacheKey, cost: Int(image.size.width * image.size.height))
            return image
         }
         else {
            return nil
         }
      }
   }
   
   func getThumbnail(_ callback : @escaping (UIImage?) -> Void)
   {
      guard imageLoaded else { callback(nil); return }
      guard !imageLink.isEmpty else { callback(nil); return }
      
      let cacheKey = imageLink as NSString
      
      if let image = MBMusic.thumbnailCache.object(forKey: cacheKey) {
         callback(image)
         return
      }
      
      let path = thumbnailPath
      
      UserInitiatedQueue.async
      {
         if let image = UIImage(contentsOfFile: path)
         {
            MBMusic.thumbnailCache.setObject(image, forKey: cacheKey, cost: Int(image.size.width * image.size.height))
            MainQueue.async { callback(image) }
         }
         else {
            MainQueue.async { callback(nil) }
         }
      }
   }
   
   class func loadMusicFiles()
   {
      loadMusicThumbnails()
      loadMusicSongs()
   }
   
   private static var canLoadSongs : Bool
   {
      if let userId = User.currentUserId, userId != 0, let user = Realm.main.object(ofType: User.self, forPrimaryKey: userId) {
         return user.syncSongs && (!user.syncSongsWiFiOnly || isServerWiFiConnection)
      }
      else {
         return isServerWiFiConnection
      }
   }
   
   private static var loadingThumbnails = false
   private static var needLoadThumbnailsAgain = false
   
   private class func loadMusicThumbnails()
   {
      let allMusic = Realm.main.objects(MBMusic.self)
      
      if loadingThumbnails {
         needLoadThumbnailsAgain = true
      }
      else
      {
         let musicWithoutThumbnail = allMusic.filter("imageLoaded == false").toArray()
         if !musicWithoutThumbnail.isEmpty
         {
            loadingThumbnails = true
            loadMusicThumbnails(musicWithoutThumbnail)
         }
      }
   }
   
   private class func loadMusicThumbnails(_ musicList : [MBMusic])
   {
      if needLoadThumbnailsAgain
      {
         needLoadThumbnailsAgain = false
         loadingThumbnails = false
         loadMusicThumbnails()
         return
      }
      
      guard let music = musicList.first(where: {!$0.isInvalidated && !$0.imageLoaded}) else { loadingThumbnails = false; return }
      
      let continueLoading =
      {
         var musicList = musicList
         musicList.removeFirst()
         loadMusicThumbnails(musicList)
      }
      
      let link = music.imageLink
      guard !link.isEmpty else { continueLoading(); return }
      
      dlog("loading image for music ", music.id)
      
      RequestManager.downloadImage(link,
      success:
      {
         image in
         guard !music.isInvalidated, music.imageLink == link else { continueLoading(); return }
         
         if let errorSaving = music.save(image: image) {
            dlog(errorSaving)
         }
         else {
            dlog("saved image for music ", music.id)
            music.modifyWithTransactionIfNeeded {
               music.imageLoaded = true
            }
         }
         continueLoading()
      },
      failure:
      {
         errorDescription in
         dlog(errorDescription)
         continueLoading()
      })
   }
   
   
   private static var loadingSongs = false
   private static var needLoadSongsAgain = false
   
   private class func loadMusicSongs()
   {
      guard canLoadSongs else { return }
      
      let allMusic = Realm.main.objects(MBMusic.self)
      if loadingSongs {
         needLoadSongsAgain = true
      }
      else
      {
         let musicWithoutSong = allMusic.filter("songLoaded == false").toArray()
         if !musicWithoutSong.isEmpty
         {
            loadingSongs = true
            loadMusicSongs(musicWithoutSong)
         }
      }
   }
   
   private class func loadMusicSongs(_ musicList : [MBMusic])
   {
      guard canLoadSongs else
      {
         loadingSongs = false
         needLoadSongsAgain = false
         return
      }
      
      if needLoadSongsAgain
      {
         needLoadSongsAgain = false
         loadingSongs = false
         loadMusicSongs()
         return
      }
      
      guard let music = musicList.first(where: {!$0.isInvalidated && !$0.checkSongFile()}) else { loadingSongs = false; return }
      
      let continueLoading =
      {
         var musicList = musicList
         musicList.removeFirst()
         loadMusicSongs(musicList)
      }
      
      let link = music.songLink
      guard !link.isEmpty else { continueLoading(); return }
      
      dlog("loading song for music ", music.id)
      
      RequestManager.downloadData(link, to: music.songFileURL, success:
      {
         guard !music.isInvalidated, music.songLink == link else { continueLoading(); return }
         dlog("saved song for music ", music.id)
         music.modifyWithTransactionIfNeeded {
            music.songLoaded = true
         }
         continueLoading()
      },
      failure:
      {
         errorDescription in
         dlog(errorDescription)
         continueLoading()
      })
   }
}
