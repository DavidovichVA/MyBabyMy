//
//  Synchronization.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 2/24/17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import RealmSwift

class Synchronization : NSObject
{
   // MARK: - Public
   
   public enum SynchronizationState
   {
      case idle
      case starting
      case loadingMediaList
      case downloadingFiles(current : Int, count : Int)
      case addingMedia(current : Int, count : Int)
      case uploadingChangedMediaFiles(current : Int, count : Int)
      case sendingMediaChanges(current : Int, count : Int)
      case deletingMedias
   }
   
   public static var forbidden : Bool = false
   {
      didSet
      {
         if forbidden {
            cancel()
         }
      }
   }
   
   public static var state : SynchronizationState {
      return currentSynchronization?.state ?? ( starting ? .starting : .idle)
   }
   
   public private(set) static var lastSyncTime : Date?
   
   public static var progress : Float?
   {
      guard let currentSync = currentSynchronization else { return nil }
      
      var currentCount = 0
      let totalCount = 2 + currentSync.mediasToDownloadCount + currentSync.mediasToAddCount + currentSync.mediasToUploadFileCount + currentSync.mediasToEditCount
      
      switch currentSync.state
      {
      case .idle, .starting, .loadingMediaList: return 0
         
      case .downloadingFiles(let current, _):
         currentCount = 1 + current
         
      case .addingMedia(let current, _):
         currentCount = 1 + currentSync.mediasToDownloadCount + current
         
      case .uploadingChangedMediaFiles(let current, _):
         currentCount = 1 + currentSync.mediasToDownloadCount + currentSync.mediasToAddCount + current
         
      case .sendingMediaChanges(let current, _):
         currentCount = 1 + currentSync.mediasToDownloadCount + currentSync.mediasToAddCount + currentSync.mediasToUploadFileCount + current
         
      case .deletingMedias:
         currentCount = totalCount - 1
      }
      
      return Float(currentCount) / Float(totalCount)
   }
   
//   public static var status : String {
//      return ""
//   }
   
   public private(set) static var mediasDownloadingFileIds : Set<Int> = []
   
   public class func start(ignoreUserSyncOptions : Bool = false, operationQueue : OperationQueue? = nil)
   {
      print("Attempting to start synchronization...")
      guard case .idle = state else { return }
      starting = true
      
      let sync = Synchronization()
      guard let user = sync.currentUser else { starting = false; return }
      sync.ignoreUserSyncOptions = ignoreUserSyncOptions
      guard sync.canSynchronize else { starting = false; return }
      
//      if let operationQueue = operationQueue {
//         sync.operationQueue = operationQueue
//      }
//      else {
//         sync.operationQueue = OperationQueue()
//         sync.operationQueue.qualityOfService = .utility
//      }
      sync.operationQueue = OperationQueue.main
      sync.operationQueue.maxConcurrentOperationCount = 1
      
      sync.state = .starting
      currentSynchronization = sync
      starting = false
      print("----------------------------------\nSynchronization started")
      
      sync.currentUserId = user.id
      sync.operationQueue.addOperation {
         sync.proceedToNextPersona()
      }
   }
   
   public class func cancel()
   {
      if let sync = currentSynchronization
      {
         print("Synchronization set to cancel")
         sync.canceled = true
         currentSynchronization = nil
         mediasDownloadingFileIds.removeAll()
      }
   }
   
   // MARK: - Private
   
   private static var currentSynchronization : Synchronization?
   private static var starting = false
   
   var state : SynchronizationState = .idle
   var canSynchronize : Bool
   {
      guard !Synchronization.forbidden, isServerConnection else { return false }
      if let user = currentUser {
         return user.isPro && (ignoreUserSyncOptions || (user.syncMedias && (!user.syncMediasWiFiOnly || isServerWiFiConnection)))
      }
      else {
         return false
      }
   }
   
   var operationQueue = OperationQueue()
   
   var ignoreUserSyncOptions = false
   var canceled = false
   
   // MARK: Processed user & persona
   
   private var currentUserId : Int?
   private var currentUser : User?
   {
      if !canceled, let userId = User.currentUserId
      {
         if let currentId = currentUserId, currentId != userId { return nil }
         return Realm.main.object(ofType: User.self, forPrimaryKey: userId)
      }
      return nil
   }
   
   private var currentPersonaId : Int?
   private var currentPersona: Persona?
   {
      if !canceled, let personId = currentPersonaId, let user = currentUser {
         return user.personas.first(where: { persona in persona.id == personId })
      }
      return nil
   }
   
   private var completedPersonasIds : [Int] = []
   
   private func nextPersona() -> Persona?
   {
      guard !canceled, let user = currentUser, canSynchronize else { return nil }
      
      if let personId = currentPersonaId {
         completedPersonasIds.append(personId)
      }
      
      if let persona = user.personas.first(where: { persona in !completedPersonasIds.contains(persona.id) })
      {
         currentPersonaId = persona.id
         return persona
      }
      return nil
   }
   
   // MARK: Methods
   
   private var mediasToDownloadFile : [Media] = []
   private var mediasDownloadedCount : Int = 0
   private var mediasToDownloadCount : Int = 0
   
   private var mediasToAdd : [Media] = []
   private var mediasAddedCount : Int = 0
   private var mediasToAddCount : Int = 0
   
   private var mediasToUploadFile : [Media] = []
   private var mediasUploadedCount : Int = 0
   private var mediasToUploadFileCount : Int = 0
   
   private var mediasToEditSendChanges : [Media] = []
   private var mediasEditedCount : Int = 0
   private var mediasToEditCount : Int = 0
   
   private var mediasToSendForDeletion : [Int] = []
   
   private func checkIfProceed() -> Bool
   {
      if canceled || currentUser == nil || !canSynchronize
      {
         print(String(format: "Synchronization can't proceed, canceled: %@, getCurrentUserFailed: %@, canSynchronize %@", (canceled ? "true" : "false"), (currentUser == nil ? "true" : "false"), (canSynchronize ? "true" : "false")))
         finish()
         return false
      }
      if currentPersona == nil {
         proceedToNextPersona()
         return false
      }
      return true
   }
   
   private func proceedToNextPersona()
   {
      if let persona = nextPersona()
      {
         print("Synchronization: proceedToNextPersona")
         let personaId = persona.id
         operationQueue.addOperation
         {
            self.loadMediaList(personaId)
         }
      }
      else {
         print("Synchronization: no next persona")
         finish(completed: (currentPersona != nil && canSynchronize))
      }
   }
   
   private func proceedToNextState()
   {
      guard checkIfProceed() else { return }
      
      print("Synchronization: proceedToNextState")
      
      self.operationQueue.addOperation
      {
         switch self.state
         {
         case .idle, .starting: break
            
         case .loadingMediaList:
            if self.mediasToDownloadCount > 0 { self.downloadMediaFiles() }
            else if self.mediasToAddCount > 0 { self.addMedias() }
            else if self.mediasToUploadFileCount > 0 { self.uploadChangedMediaFiles() }
            else if self.mediasToEditCount > 0 { self.sendMediaEditChanges() }
            else if !self.mediasToSendForDeletion.isEmpty { self.deleteMedias() }
            else { self.proceedToNextPersona() }
            
         case .downloadingFiles:
            if self.mediasToAddCount > 0 { self.addMedias() }
            else if self.mediasToUploadFileCount > 0 { self.uploadChangedMediaFiles() }
            else if self.mediasToEditCount > 0 { self.sendMediaEditChanges() }
            else if !self.mediasToSendForDeletion.isEmpty { self.deleteMedias() }
            else { self.proceedToNextPersona() }
            
         case .addingMedia:
            if self.mediasToUploadFileCount > 0 { self.uploadChangedMediaFiles() }
            else if self.mediasToEditCount > 0 { self.sendMediaEditChanges() }
            else if !self.mediasToSendForDeletion.isEmpty { self.deleteMedias() }
            else { self.proceedToNextPersona() }
            
         case .uploadingChangedMediaFiles:
            if self.mediasToEditCount > 0 { self.sendMediaEditChanges() }
            else if !self.mediasToSendForDeletion.isEmpty { self.deleteMedias() }
            else { self.proceedToNextPersona() }
            
         case .sendingMediaChanges:
            if !self.mediasToSendForDeletion.isEmpty { self.deleteMedias() }
            else { self.proceedToNextPersona() }
            
         case .deletingMedias:
            self.proceedToNextPersona()
         }
      }
   }
   
   private func loadMediaList(_ personaId : Int)
   {
      if canceled || currentUser == nil || !canSynchronize {
         finish()
         return
      }
      
      print("Synchronization: loadingMediaList for persona #\(personaId)")
      state = .loadingMediaList
      
      RequestManager.getMediaList(personaId: personaId,
      success:
      {
         mediaList in
         print("Synchronization: load media list success")
         guard self.checkIfProceed() else { return }
         self.operationQueue.addOperation
         {
            if let persona = self.currentPersona {
               self.processMediaList(mediaList, persona: persona)
            }
            else {
               self.proceedToNextPersona()
            }
         }
      },
      failure:
      {
         errorDescription in
         print("Synchronization: load media list failure")
         dlog(errorDescription)
         guard self.checkIfProceed() else { return }
         self.proceedToNextPersona()
      })
   }
   
   private func processMediaList(_ mediaList : [Media], persona : Persona)
   {
      print("Synchronization: processMediaList")
      
      let realm = Realm.main

      let personaMedias = realm.objects(Media.self).filter("personaId == %d", persona.id)
      var personaMediasDict : [String : Media] = [:]
      for media in personaMedias {
         personaMediasDict[media.equalityValue] = media
      }
      
      realm.writeWithTransactionIfNeeded
      {
         mediasToSendForDeletion.removeAll()
         mediasToDownloadFile.removeAll()
         Synchronization.mediasDownloadingFileIds.removeAll()
         mediasToUploadFile.removeAll()
         mediasToEditSendChanges.removeAll()
         mediasToAdd.removeAll()       
         
         var serverMedias = mediaList
         
         //removing deleted medias from processing
         var deletedMedias = persona.deletedMedias.toArray()
         if !deletedMedias.isEmpty
         {
            var i = 0
            while i < deletedMedias.count
            {
               let deletedMedia = deletedMedias[i]
               if let index = serverMedias.index(where:
                  { media in media.id == deletedMedia.id && media.timestamp <= deletedMedia.timestamp} )
               {
                  serverMedias.remove(at: index)
                  mediasToSendForDeletion.append(deletedMedia.id)
                  i += 1
               }
               else {
                  deletedMedias.remove(at: i)
               }
            }
            persona.deletedMedias.removeAll()
            persona.deletedMedias.append(objectsIn: deletedMedias)
         }
         
         //loop for all undeleted server medias to determine what to do with each
         for serverMedia in serverMedias
         {
            let mediaEqualityValue = serverMedia.equalityValue
            
            if let personaMedia = personaMediasDict[mediaEqualityValue] // existing media
            {
               personaMediasDict.removeValue(forKey: mediaEqualityValue)
               
               let fileLoaded = personaMedia.fileLoaded
               serverMedia.fileLoaded = fileLoaded // to not overwrite when persona.addOrUpdate(serverMedia)
               
               if !fileLoaded && isNilOrEmpty(serverMedia.link)
               {
                  mediasToSendForDeletion.append(serverMedia.id)
                  personaMedia.delete()
                  continue
               }
               
               if personaMedia.timestamp <= serverMedia.timestamp // updating self from server media
               {
                  if isNilOrEmpty(serverMedia.link)
                  {
                     if (personaMedia.timestamp < serverMedia.timestamp)
                     {
                        serverMedia.link = personaMedia.link
                        persona.addOrUpdate(serverMedia)
                     }
                  }
                  else
                  {
                     let needDownloadFile : Bool = !fileLoaded || (personaMedia.link != serverMedia.link)
                     let updatedMedia = persona.addOrUpdate(serverMedia)
                     
                     if needDownloadFile
                     {
                        updatedMedia.deleteMediaFiles()
                        mediasToDownloadFile.append(updatedMedia)
                        Synchronization.mediasDownloadingFileIds.insert(updatedMedia.id)
                     }
                  }
               }
               else // updating server from self
               {
                  if fileLoaded
                  {
                     if isNilOrEmpty(personaMedia.link) || (personaMedia.link != serverMedia.link) {
                        mediasToUploadFile.append(personaMedia)
                     }
                     else {
                        mediasToEditSendChanges.append(personaMedia)
                     }
                  }
                  else if !isNilOrEmpty(serverMedia.link)
                  {
                     personaMedia.link = serverMedia.link
                     personaMedia.deleteMediaFiles()
                     mediasToDownloadFile.append(personaMedia)
                     Synchronization.mediasDownloadingFileIds.insert(personaMedia.id)
                     mediasToEditSendChanges.append(personaMedia)
                  }
               }
            }
            else if !isNilOrEmpty(serverMedia.link) //got new media from server
            {
               serverMedia.deleteMediaFiles() // in case of old files left on disk
               let newMedia = persona.addOrUpdate(serverMedia)
               mediasToDownloadFile.append(newMedia)
               Synchronization.mediasDownloadingFileIds.insert(newMedia.id)
            }
         }
         
         for leftMedia in personaMediasDict.values // self medias that server does not know about
         {
            if isNilOrEmpty(leftMedia.link) && leftMedia.checkLoadedFile() {
               mediasToAdd.append(leftMedia)
            }
            else {
               leftMedia.delete()
            }
         }
         
         mediasToDownloadCount = mediasToDownloadFile.count
         mediasDownloadedCount = 0
         mediasToAddCount = mediasToAdd.count
         mediasAddedCount = 0
         mediasToUploadFileCount = mediasToUploadFile.count
         mediasUploadedCount = 0
         mediasToEditCount = mediasToEditSendChanges.count
         mediasEditedCount = 0
         print("Synchronization: mediasToDownload \(mediasToDownloadCount), mediasToAdd \(mediasToAddCount), mediasToUploadFile \(mediasToUploadFileCount), mediasToEdit \(mediasToEditCount), mediasToSendForDeletion \(mediasToSendForDeletion.count)")
      }
      
      MainQueue.async {
         mainController?.updateAvatars()
      }
      
      proceedToNextState()
   }
   
   private func downloadMediaFiles()
   {
      print("Synchronization: downloadMediaFiles started, downloaded \(mediasDownloadedCount) of \(mediasToDownloadCount)")
      state = .downloadingFiles(current: mediasDownloadedCount, count: mediasToDownloadCount)
      var isMedia = false
      
      Realm.main.writeWithTransactionIfNeeded
      {
         mediasDownloadedCount += 1
         
         if let index = mediasToDownloadFile.index(where: { !$0.isInvalidated && !isNilOrEmpty($0.link) })
         {
            let media = mediasToDownloadFile[index]
            isMedia = true
            state = .downloadingFiles(current: mediasDownloadedCount, count: mediasToDownloadCount)
            print("Synchronization: downloading #\(index) of \(mediasToDownloadFile.count) total")
            
            let mediaId = media.id
            
            RequestManager.downloadData(media.link!, to: media.fileURL,
            success:
            {
               print("Synchronization: download file success")
               self.operationQueue.addOperation
               {
                  if !media.isInvalidated
                  {
                     var videoDuration : Double? = nil
                     if media.type == .video {
                        videoDuration = getVideoDuration(media.fileURL)
                     }
                     
                     media.modifyWithTransactionIfNeeded
                     {
                        if let duration = videoDuration
                        {
                           media.videoDuration = duration
                           if duration > 0 {
                              media.fileLoaded = true
                              media.checkLoadedFile()
                           }
                           else {
                              dlog("invalid video file: \(media.link!)")
                              media.fileLoaded = false
                              media.link = nil
                           }
                        }
                        else
                        {
                           media.fileLoaded = true
                           media.checkLoadedFile()
                        }
                     }
                  }
                  
                  guard self.checkIfProceed() else { return }
                  
                  self.mediasToDownloadFile.remove(at: index)
                  Synchronization.mediasDownloadingFileIds.remove(mediaId)
                  self.downloadMediaFiles()
               }
            },
            failure:
            {
               errorDescription in
               print("Synchronization: download file failure")
               dlog(errorDescription)
               guard self.checkIfProceed() else { return }
               self.operationQueue.addOperation
               {
                  self.mediasToDownloadFile.remove(at: index)
                  Synchronization.mediasDownloadingFileIds.remove(mediaId)
                  self.downloadMediaFiles()
               }
            })
         }
         else
         {
            isMedia = false
            state = .downloadingFiles(current: mediasToDownloadCount, count: mediasToDownloadCount)
         }
      }
      
      if !isMedia {
         print("Synchronization: downloadMediaFiles finished")
         MainQueue.async {
            mainController?.updateAvatars()
         }
         proceedToNextState()
      }
   }
   
   private func addMedias()
   {
      print("Synchronization: addMedias started, added \(mediasAddedCount) of \(mediasToAddCount)")
      state = .addingMedia(current: mediasAddedCount, count: mediasToAddCount)
      var isMedia = false
      
      Realm.main.writeWithTransactionIfNeeded
      {
         mediasAddedCount += 1
         
         if let index = mediasToAdd.index(where: { !$0.isInvalidated && $0.fileLoaded })
         {
            let media = mediasToAdd[index]
            isMedia = true
            state = .addingMedia(current: mediasAddedCount, count: mediasToAddCount)
            print("Synchronization: adding #\(index) of \(mediasToAdd.count) total")
            
            RequestManager.addMedia(media,
            success:
            {
               print("Synchronization: add media success")
               guard self.checkIfProceed() else { return }
               self.operationQueue.addOperation
               {
                  self.mediasToAdd.remove(at: index)
                  self.addMedias()
               }
            },
            failure:
            {
               errorDescription in
               print("Synchronization: add media failure")
               dlog(errorDescription)
               guard self.checkIfProceed() else { return }
               self.operationQueue.addOperation
               {
                  self.mediasToAdd.remove(at: index)
                  self.addMedias()
               }
            })
         }
         else
         {
            isMedia = false
            state = .addingMedia(current: mediasToAddCount, count: mediasToAddCount)
         }
      }
      
      if !isMedia {
         print("Synchronization: addMedias finished")
         proceedToNextState()
      }
   }
   
   private func uploadChangedMediaFiles()
   {
      print("Synchronization: uploadChangedMediaFiles started, uploaded \(mediasUploadedCount) of \(mediasToUploadFileCount)")
      state = .uploadingChangedMediaFiles(current: mediasUploadedCount, count: mediasToUploadFileCount)
      var isMedia = false
      
      Realm.main.writeWithTransactionIfNeeded
      {
         mediasUploadedCount += 1
         
         if let index = mediasToUploadFile.index(where: { !$0.isInvalidated && $0.fileLoaded })
         {
            let media = mediasToUploadFile[index]
            isMedia = true
            state = .uploadingChangedMediaFiles(current: mediasUploadedCount, count: mediasToUploadFileCount)
            print("Synchronization: uploading #\(index) of \(mediasToUploadFile.count) total")
            
            RequestManager.editMedia(media, loadMediaFile: true,
            success:
            {
               print("Synchronization: upload media file success")
               guard self.checkIfProceed() else { return }
               self.operationQueue.addOperation
               {
                  self.mediasToUploadFile.remove(at: index)
                  self.uploadChangedMediaFiles()
               }
            },
            failure:
            {
               errorDescription in
               print("Synchronization: upload media file failure")
               dlog(errorDescription)
               guard self.checkIfProceed() else { return }
               self.operationQueue.addOperation
               {
                  self.mediasToUploadFile.remove(at: index)
                  self.uploadChangedMediaFiles()
               }
            })
         }
         else
         {
            isMedia = false
            state = .uploadingChangedMediaFiles(current: mediasToUploadFileCount, count: mediasToUploadFileCount)
         }
      }
      
      if !isMedia {
         print("Synchronization: uploadChangedMediaFiles finished")
         proceedToNextState()
      }
   }
   
   
   private func sendMediaEditChanges()
   {
      print("Synchronization: sendMediaEditChanges started, sent \(mediasEditedCount) of \(mediasToEditCount)")
      state = .sendingMediaChanges(current: mediasEditedCount, count: mediasToEditCount)
      var isMedia = false
      
      Realm.main.writeWithTransactionIfNeeded
      {
         mediasEditedCount += 1
         
         if let index = mediasToEditSendChanges.index(where: { !$0.isInvalidated })
         {
            let media = mediasToEditSendChanges[index]
            isMedia = true
            state = .sendingMediaChanges(current: mediasEditedCount, count: mediasToEditCount)
            print("Synchronization: sending edit changes #\(index) of \(mediasToEditSendChanges.count) total")
            
            RequestManager.editMedia(media, loadMediaFile: false,
            success:
            {
               print("Synchronization: edit media success")
               guard self.checkIfProceed() else { return }
               self.operationQueue.addOperation
               {
                  self.mediasToEditSendChanges.remove(at: index)
                  self.sendMediaEditChanges()
               }
            },
            failure:
            {
               errorDescription in
               print("Synchronization: edit media failure")
               dlog(errorDescription)
               guard self.checkIfProceed() else { return }
               self.operationQueue.addOperation
               {
                  self.mediasToEditSendChanges.remove(at: index)
                  self.sendMediaEditChanges()
               }
            })
         }
         else
         {
            isMedia = false
            state = .sendingMediaChanges(current: mediasToEditCount, count: mediasToEditCount)
         }
      }
      
      if !isMedia {
         print("Synchronization: sendMediaChanges finished")
         proceedToNextState()
      }
   }
   
   private func deleteMedias()
   {
      print("Synchronization: deleteMedias started")
      state = .deletingMedias
      
      if mediasToSendForDeletion.isEmpty
      {
         print("Synchronization: no medias to delete")
         proceedToNextState()
      }
      else
      {
         RequestManager.deleteMedias(mediasToSendForDeletion,
         success:
         {
            print("Synchronization: delete medias success")
            if let persona = self.currentPersona
            {
               Realm.main.writeWithTransactionIfNeeded
               {
                  for mediaId in self.mediasToSendForDeletion
                  {
                     if let index = persona.deletedMedias.index(where: {$0.id == mediaId}) {
                        persona.deletedMedias.remove(objectAtIndex: index)
                     }
                  }
               }
            }
            self.proceedToNextState()
         },
         failure:
         {
            errorDescription in
            print("Synchronization: delete medias failure")
            dlog(errorDescription)
            self.proceedToNextState()
         })
      }
   }
   
   private func finish(completed : Bool = false)
   {
      currentUserId = nil
      currentPersonaId = nil
      completedPersonasIds.removeAll()
      mediasToSendForDeletion.removeAll()
      mediasToDownloadFile.removeAll()
      mediasToUploadFile.removeAll()
      mediasToEditSendChanges.removeAll()
      mediasToAdd.removeAll()
      state = .idle
      canceled = true
      
      if self === Synchronization.currentSynchronization {
         Synchronization.currentSynchronization = nil
         Synchronization.mediasDownloadingFileIds.removeAll()
      }
      
      if completed {
         Synchronization.lastSyncTime = Date()
      }
      
      print(String(format: "Synchronization finished, completed: %@\n----------------------------------", (completed ? "true" : "false")))
   }
}
