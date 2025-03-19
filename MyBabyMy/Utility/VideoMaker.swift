//
//  VideoMaker.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 1/26/17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import AVFoundation
import MediaPlayer
import Photos
import RealmSwift
import Alamofire

enum VideoResolution : String
{
   case size1280x1280 = "1280X1280 (INSTAGRAM)"
   case size1280x720 = "1280X720 (YOUTUBE, FACEBOOK)"
   
   static let allValues : [VideoResolution] = [size1280x1280, size1280x720]
}

class VideoMaker
{
   //MARK: - Properties & Settings
   
   public static var persona : Persona!
   {
      didSet { updateForNewPersona() }
   }
   
   public static var mediaType : BabyMediaType = .photo
   public static var videoPhotoSpeed : VideoPhotoSpeed = .normal
   public static var videoPhotoSpeedValue : Double {
      return videoPhotoSpeed.speedValue(mediaType)
   }
   public static var bestMoments : Bool = false
   public static var showAge : Bool = true
   
   public static var selectedMusic : VideoMusic = .none
   public static var selectedMusicTitle : String?
   {
      switch selectedMusic
      {
      case .mbMusic(let music) where !music.isInvalidated: return music.title
      case .mpMedia(let musicItem): return musicItem.title
      default: return loc("NO SOUND")
      }
   }
   
   public static var selectedVideoSize : VideoResolution = .size1280x1280
   
   public static var captionColor : UIColor = rgb(237, 253, 40)
   public static var captionFontSize : CGFloat { return 66.0 * sizeMultiplier }
   public static var captionFont : UIFont { return UIFont(name: "AvenirNext-Bold", size: captionFontSize) ??
      UIFont.systemFont(ofSize: captionFontSize, weight: UIFontWeightBold) }
   
   public static var logoLinkColor : UIColor = rgb(109, 135, 192)
   public static var logoLinkFontSize : CGFloat { return 44.0 * sizeMultiplier }
   public static var logoLinkFont : UIFont { return UIFont(name: "Foo-Regular", size: logoLinkFontSize) ??
      UIFont.systemFont(ofSize: logoLinkFontSize, weight: UIFontWeightBold) }
   
   private static var pregnancyMediasByType : [BabyMediaType : Results<Media>] = [:]
   private static var babyMediasByType : [BabyMediaType : Results<Media>] = [:]
   
   public static var allPregnancyMedias : Results<Media>
   {
      let medias = pregnancyMediasByType[mediaType]!
      //if bestMoments { medias = medias.filter("isBestMoment == true") }
      return medias
   }
   public static var allBabyMedias : Results<Media>
   {
      var medias = babyMediasByType[mediaType]!
      if bestMoments { medias = medias.filter("isBestMoment == true") }
      return medias
   }
   public static var constrainedToPeriodBabyMedias : [Media]
   {
      let medias = allBabyMedias
      let count = medias.count
      var mediasInRange : [Media] = []      
      for i in selectedPeriodRange
      {
         if i >= count {
            dlog("Out of range selected medias count")
            break
         }
         mediasInRange.append(medias[i])
      }
      return mediasInRange
   }
   
   private static var selectedPregnancyMediasCountByType : [BabyMediaType : [Bool : Int]] =
      [.photo: [true: 0, false: 0], .video: [true: 0, false: 0], .photoInDynamics: [true: 0, false: 0]]
   public static var selectedPregnancyMediasCount : Int
   {
      get {
         return selectedPregnancyMediasCountByType[mediaType]![bestMoments]!
      }
      set {
         selectedPregnancyMediasCountByType[mediaType]![bestMoments] = newValue
      }
   }
   
   private static var selectedBabyMediasCountByType : [BabyMediaType : [Bool : Int]] =
      [.photo: [true: 0, false: 0], .video: [true: 0, false: 0], .photoInDynamics: [true: 0, false: 0]]
   public static var selectedBabyMediasCount : Int
   {
      get {
         return selectedBabyMediasCountByType[mediaType]![bestMoments]!
      }
      set {
         selectedBabyMediasCountByType[mediaType]![bestMoments] = newValue
      }
   }
   
   private static var selectedPeriodRangeByType : [BabyMediaType : [Bool : CountableRange<Int>]] =
      [.photo: [true: 0..<0, false: 0..<0], .video: [true: 0..<0, false: 0..<0], .photoInDynamics: [true: 0..<0, false: 0..<0]]
   public static var selectedPeriodRange : CountableRange<Int>
   {
      get {
         return selectedPeriodRangeByType[mediaType]![bestMoments]!
      }
      set {
         selectedPeriodRangeByType[mediaType]![bestMoments] = newValue
      }
   }
   
   public class func selectedMedias(_ selectedCount : Int, _ status : PersonaStatus) -> [Media]
   {
      guard selectedCount > 0 else { return [] }
      var medias : [Media]
      
      switch status
      {
         case .baby: medias = constrainedToPeriodBabyMedias
         case .pregnant: medias = allPregnancyMedias.toArray()
      }
      
      let totalCount = Double(medias.count)
      let selectedStep : Double = max(1.0, totalCount / Double(selectedCount))
      var mediaIndexes : [Int] = []
      
      var ind : Double = 0
      for _ in 0..<selectedCount
      {
         mediaIndexes.append(Int(round(ind)))
         ind += selectedStep
      }
      
      var selectedMedias : [Media] = []
      for index in mediaIndexes {
         selectedMedias.append(medias[index])
      }
      
      return selectedMedias
   }

   private class func updateForNewPersona()
   {
      for type in BabyMediaType.allValues
      {
         let pregnancyMedias = persona.medias(.pregnant, type).filter("fileLoaded == true").sorted(byKeyPath: "pregnancyWeek")
         let babyMedias = persona.medias(.baby, type).filter("fileLoaded == true").sorted(byKeyPath: "date.id")
         
         pregnancyMediasByType[type] = pregnancyMedias
         babyMediasByType[type] = babyMedias
         
         let pregnancyMediasCount = pregnancyMedias.count
         selectedPregnancyMediasCountByType[type]![false] = pregnancyMediasCount
         selectedPregnancyMediasCountByType[type]![true] = pregnancyMediasCount
         
         let babyMediasCount = babyMedias.count
         let babyMediasBestMomentsCount = babyMedias.filter("isBestMoment == true").count
         selectedBabyMediasCountByType[type]![false] = babyMediasCount
         selectedBabyMediasCountByType[type]![true] = babyMediasBestMomentsCount
         selectedPeriodRangeByType[type]![false] = 0..<babyMediasCount
         selectedPeriodRangeByType[type]![true] = 0..<babyMediasBestMomentsCount
      }
   }

   //MARK: - Methods

   private static var presentingController : UIViewController?
   private static var spinnerController : CreateVideoSpinnerController?
   private static var updateProgressTimer : Timer?
   fileprivate static var cancel = false
   fileprivate static var addLogo = false
   
   public class func start(presentingController : UIViewController)
   {
      guard selectedPregnancyMediasCount + selectedBabyMediasCount >= 5 else
      {
         let message : String
         switch mediaType
         {
            case .photo, .photoInDynamics: message = loc("Add at least 5 photos to create video")
            case .video: message = loc("Add at least 5 videos to create video")
         }
         AlertManager.showAlert(message)
         return
      }
      
      self.presentingController = presentingController
      spinnerController = Storyboard.instantiateViewController(withIdentifier: "CreateVideoSpinnerController") as? CreateVideoSpinnerController
      spinnerController?.loadViewIfNeeded()
      spinnerController?.progressView?.progress = 0
      
      cancel = false
      addLogo = !User.current!.isPro
      
      prepareAudio
      {
         success in
         guard success, !cancel else
         {
            self.presentingController = nil
            self.spinnerController = nil
            return
         }
         
         let pregnancyMedias = selectedMedias(selectedPregnancyMediasCount, .pregnant)
         let babyMedias = selectedMedias(selectedBabyMediasCount, .baby)
         let medias = pregnancyMedias + babyMedias
         
         if let spinner = spinnerController
         {
            spinner.statusLabel.text = loc("Creating video")
            spinner.progressView.progress = 0
            if spinner.presentingViewController == nil && presentingController.presentedViewController == nil {
               presentingController.present(spinner, animated: true, completion: nil)
            }
            
            updateProgressTimer = Timer.scheduledTimer(timeInterval: 0.04, target: spinner, selector: #selector(CreateVideoSpinnerController.updateVideoCreationProgress(sender:)), userInfo: nil, repeats: true)
         }
         
         switch mediaType
         {
         case .photo:
            switch selectedVideoSize
            {
            case .size1280x1280: VideoWidth = 1280; VideoHeight = 1280
            case .size1280x720: VideoWidth = 1280; VideoHeight = 720
            }
            photoCreationProgress = 0
            createVideoFromPhotos(medias)
            
         case .photoInDynamics:
            VideoWidth = 480
            VideoHeight = 640
            photoCreationProgress = 0
            createVideoFromPhotos(medias)
            
         case .video:
            switch selectedVideoSize
            {
            case .size1280x1280: VideoWidth = 1280; VideoHeight = 1280
            case .size1280x720: VideoWidth = 1280; VideoHeight = 720
            }
            photoCreationProgress = nil
            createVideoFromVideos(medias)
         }
      }
   }
   
   private static var goingToDismissSpinner = false
   private class func dismissSpinner(_ completion : @escaping () -> Void)
   {
      guard let presentingController = presentingController else {
         completion()
         return
      }
      
      if presentingController.presentedViewController == nil
      {
         completion()
      }
      else
      {
         if goingToDismissSpinner
         {
            delay(0.1) {
               dismissSpinner(completion)
            }
         }
         else
         {
            goingToDismissSpinner = true
            presentingController.dismiss(animated: true, completion:
            {
               goingToDismissSpinner = false
               completion()
            })
         }
      }
   }
   
   private static var audioFileUrl : URL?
   private static var audioFileIsTempCopy : Bool = false
   fileprivate static var audioLoadRequest : DownloadRequest?
   
   private static func prepareAudio(_ completion : @escaping (Bool) -> Void)
   {
      switch selectedMusic
      {
      case .mpMedia(let musicItem):
         var errorDescription : String = ""
         if let assetUrl = musicItem.assetURL
         {
            let avItem = AVPlayerItem(url: assetUrl)
            if avItem.asset.isComposable {
               audioFileUrl = assetUrl
               audioFileIsTempCopy = false
            }
            else {
               errorDescription = loc("Selected track can not be used")
            }
         }
         else {
            errorDescription = loc("Selected track is not available")
         }
         
         if errorDescription.isEmpty {
            completion(true)
            return
         }
         else {
            AlertManager.showAlert(errorDescription)
            completion(false)
            return
         }
      
      case .mbMusic(let music) where !music.isInvalidated:
         let audioFileName = UUID().uuidString
         var audioURL = URL(fileURLWithPath: tempDirectory).appendingPathComponent(audioFileName, isDirectory: false)
         if let fileType = music.songFileType, !fileType.isEmpty {
            audioURL = audioURL.appendingPathExtension(fileType)
         }
         
         let loadedSongBlock =
         {
            do {
               try FileManager.default.copyItem(at: music.songFileURL, to: audioURL)
            }
            catch let error
            {
               dismissSpinner
               {
                  AlertManager.showAlert(error.localizedDescription)
                  completion(false)
               }
               return
            }
            audioFileUrl = audioURL
            audioFileIsTempCopy = true
            completion(true)
         }
         
         if music.checkSongFile()
         {
            loadedSongBlock()
         }
         else
         {
            if let spinner = spinnerController
            {
               spinner.statusLabel.text = loc("Loading music")
               presentingController?.present(spinner, animated: true, completion: nil)
            }
            
            let link = music.songLink
            audioLoadRequest = RequestManager.downloadData(link, to: music.songFileURL,
            progress:
            {
               progress in
               guard !cancel, let progressView = spinnerController?.progressView else { return }
               progressView.setProgress(Float(progress.fractionCompleted), animated: true)
            },
            success:
            {
               audioLoadRequest = nil
               guard !music.isInvalidated, music.songLink == link else
               {
                  dismissSpinner
                  {
                     AlertManager.showAlert("Selected music changed while loading")
                     completion(false)
                  }
                  return
               }
               dlog("saved song for music ", music.id)
               music.modifyWithTransactionIfNeeded {
                  music.songLoaded = true
               }
               loadedSongBlock()
            },
            failure:
            {
               errorDescription in
               audioLoadRequest = nil
               dismissSpinner
               {
                  if !cancel {
                     AlertManager.showAlert(title: loc("Failed to load music"), message: errorDescription)
                  }
                  completion(false)
               }
            })
         }
         
      default:
         audioFileUrl = nil
         audioFileIsTempCopy = false
         completion(true)
      }
   }
   
   //MARK: - Video Creation
   
   fileprivate static var exportSession : AVAssetExportSession?
   fileprivate static var photoCreationProgress : Float?
   
   static var VideoWidth : Int = 1280
	static var VideoHeight : Int = 720
   static var VideoWidthFloat : CGFloat { return CGFloat(VideoWidth) }
   static var VideoHeightFloat : CGFloat { return CGFloat(VideoHeight) }
   static var VideoSize : CGSize { return CGSize(width: VideoWidth, height: VideoHeight) }
   static var VideoRect : CGRect { return CGRect(origin: .zero, size: VideoSize) }
   
   static var sizeMultiplier : CGFloat { return VideoWidthFloat / 1280 }
   
   static var sessionPreset : String {
      return (mediaType == .photoInDynamics) ? AVAssetExportPreset640x480 : AVAssetExportPreset1280x720
   }
   
   enum VideoContentMode
   {
      case scaleToFill
      case scaleAspectFit
      case scaleAspectFill
   }
   
   static let videoContentMode : VideoContentMode = .scaleAspectFill
   
   //MARK: Video From Videos
   
   private class func createVideoFromVideos(_ medias : [Media])
   {
      let mixComposition = AVMutableComposition()
      let compositionInstruction = AVMutableVideoCompositionInstruction()
      var time : CMTime = kCMTimeZero
      let videoComposition = AVMutableVideoComposition()
      
      let parentLayer = CALayer()
      let videoLayer = CALayer()
      parentLayer.frame = VideoRect
      videoLayer.frame = parentLayer.frame
      parentLayer.addSublayer(videoLayer)
      
      autoreleasepool {
         for media in medias
         {
            guard !media.isInvalidated, media.checkLoadedFile(), media.videoDuration > 0 else {
               dlog(media)
               continue
            }
            
            let asset = AVURLAsset(url: media.fileURL)
            guard asset.duration.seconds > 0 else {
               dlog(media)
               continue
            }
            
            //         let assetVideoTracks = asset.tracks(withMediaType: AVMediaTypeVideo)
            //         let assetAudioTracks = asset.tracks(withMediaType: AVMediaTypeAudio)
            //
            //         guard !assetVideoTracks.isEmpty else { continue }
            //
            let timeRange = CMTimeRange(start: kCMTimeZero, duration: asset.duration)
            //         let timeRangeValue = NSValue(timeRange: timeRange)
            //
            //         let videoTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
            //         let videoTimeRanges = Array<NSValue>(repeating: timeRangeValue, count: assetVideoTracks.count)
            //
            //         do {
            //            try videoTrack.insertTimeRanges(videoTimeRanges, of: assetVideoTracks, at: time)
            //         }
            //         catch let error
            //         {
            //            dlog(error)
            //            continue
            //         }
            
            do {
               try mixComposition.insertTimeRange(timeRange, of: asset, at: time)
            }
            catch let error
            {
               dlog(error)
               continue
            }
            
            autoreleasepool {
            
               let trackStartTime = time
               time = time + asset.duration
               
               let videoTracks = mixComposition.tracks(withMediaType: AVMediaTypeVideo)
               print("video tracks count: \(videoTracks.count), totalTime: \(time.seconds)")
               for videoTrack in videoTracks
               {
                  print("track start: \(videoTrack.timeRange.start.seconds); duration: \(videoTrack.timeRange.duration.seconds)")
                  
                  if videoTrack.timeRange.end < time { continue }
                  
                  let instruction = videoCompositionInstruction(track: videoTrack, asset: asset, contentMode: videoContentMode)
                  instruction.setOpacity(0, at: kCMTimeZero)
                  instruction.setOpacity(1, at: trackStartTime)
                  instruction.setOpacity(0, at: time)
                  compositionInstruction.layerInstructions.append(instruction)
               }
               
               //         let instruction = videoCompositionInstruction(track: videoTrack, asset: asset, contentMode: videoContentMode)
               //         instruction.setOpacity(0, at: kCMTimeZero)
               //         instruction.setOpacity(1, at: trackStartTime)
               //         instruction.setOpacity(0, at: time)
               //         compositionInstruction.layerInstructions.append(instruction)
               
               if showAge
               {
                  var ageString = ""
                  switch media.status
                  {
                  case .baby:
                     if let birthday = persona.birthday,
                        let string = babyAgeStringFormatter.string(from: birthday.getDate(), to: media.date.getDate())
                     {
                        ageString = string
                     }
                  case .pregnant:
                     ageString = String(format: loc("Week %d"), media.pregnancyWeek)
                     
                  }
                  ageString = ageString.replacingOccurrences(of: ",", with: "")
                  
                  let font = captionFont
                  let fontSize = captionFontSize
                  
                  let textLayer = CATextLayer()
                  textLayer.string = ageString
                  textLayer.fontSize = fontSize
                  textLayer.font = font
                  let textMargin = fontSize
                  textLayer.frame = CGRect(x: textMargin, y: 0, width: VideoWidthFloat - textMargin * 2, height: fontSize * 1.8)
                  textLayer.alignmentMode = kCAAlignmentRight
                  textLayer.foregroundColor = captionColor.cgColor
                  textLayer.isWrapped = true
                  textLayer.truncationMode = kCATruncationEnd
                  textLayer.allowsFontSubpixelQuantization = true
                  
                  parentLayer.addSublayer(textLayer)
                  
                  textLayer.opacity = 0
                  let animation = CAKeyframeAnimation(keyPath: "opacity")
                  animation.isRemovedOnCompletion = false
                  animation.fillMode = kCAFillModeRemoved
                  animation.calculationMode = kCAAnimationDiscrete
                  animation.beginTime = (trackStartTime == kCMTimeZero) ? AVCoreAnimationBeginTimeAtZero : CFTimeInterval(trackStartTime.seconds)
                  animation.duration = CFTimeInterval(asset.duration.seconds)
                  animation.keyTimes = [0.0, 1.0]
                  animation.values = [1.0]
                  textLayer.add(animation, forKey: "opacityAnimation")
               }
               
               //         if !assetAudioTracks.isEmpty
               //         {
               //            let audioTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
               //            let audioTimeRanges = Array<NSValue>(repeating: timeRangeValue, count: assetAudioTracks.count)
               //
               //            do {
               //               try audioTrack.insertTimeRanges(audioTimeRanges, of: assetAudioTracks, at: trackStartTime)
               //            }
               //            catch let error {
               //               dlog(error)
               //            }
               //         }
               
            }
         }
         
         if addLogo
         {
            let logoLayer = CALayer()
            let logo : UIImage = #imageLiteral(resourceName: "babyLogo.png")
            let logoWidth = logo.size.width * sizeMultiplier
            let logoHeight = logo.size.height * sizeMultiplier
            logoLayer.frame = CGRect(x: logoWidth, y: VideoHeightFloat - logoHeight * 1.2, width: logoWidth, height: logoHeight)
            logoLayer.contentsScale = logo.scale
            logoLayer.contents = logo.cgImage
            parentLayer.addSublayer(logoLayer)
            
            let font = logoLinkFont
            let fontSize = logoLinkFontSize
            
            let linkLayer = CATextLayer()
            linkLayer.string = "MYBABYMY.com"
            linkLayer.fontSize = fontSize
            linkLayer.font = font
            let linkHeight = fontSize * 2
            linkLayer.frame = CGRect(x: fontSize, y: logoLayer.frame.minY - linkHeight * 1.1,
                                     width: VideoWidthFloat - fontSize * 2, height: linkHeight)
            linkLayer.alignmentMode = kCAAlignmentLeft
            linkLayer.foregroundColor = logoLinkColor.cgColor
            linkLayer.allowsFontSubpixelQuantization = true
            parentLayer.addSublayer(linkLayer)
         }
         
         let totalTimeRange = CMTimeRange(start: kCMTimeZero, duration: time)
         compositionInstruction.timeRange = totalTimeRange
         compositionInstruction.backgroundColor = UIColor.black.cgColor
         
         videoComposition.instructions = [compositionInstruction]
         videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
         videoComposition.renderSize = VideoSize
         
         let addedOverlays : Bool = addLogo || showAge
         if addedOverlays
         {
            videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
         }
         
         if let audioUrl = audioFileUrl
         {
            let audioAsset = AVURLAsset(url: audioUrl)
            let assetAudioTracks = audioAsset.tracks(withMediaType: AVMediaTypeAudio)
            
            if !assetAudioTracks.isEmpty
            {
               let audioTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
               
               let audioDuration = audioAsset.duration
               var currentTime = kCMTimeZero
               
               while true
               {
                  let duration = min(audioDuration, time - currentTime)
                  let timeRangeValue = NSValue(timeRange: CMTimeRange(start: kCMTimeZero, duration: duration))
                  let audioTimeRanges = Array<NSValue>(repeating: timeRangeValue, count: assetAudioTracks.count)
                  
                  do {
                     try audioTrack.insertTimeRanges(audioTimeRanges, of: assetAudioTracks, at: currentTime)
                  }
                  catch let error {
                     dlog(error)
                     break
                  }
                  
                  currentTime = currentTime + duration
                  if currentTime >= time {
                     break
                  }
               }
            }
         }
      }
      
      let fileName = UUID().uuidString + ".mp4"
      let fileURL = URL(fileURLWithPath: tempDirectory).appendingPathComponent(fileName, isDirectory: false)
		
      guard let session = AVAssetExportSession(asset: mixComposition, presetName: sessionPreset) else
      {
         videoCreationFinish(fileURL, loc("Video creation failed"))
         return
      }
      exportSession = session
      
      session.videoComposition = videoComposition
      session.outputURL = fileURL
      session.outputFileType = AVFileTypeMPEG4
      session.shouldOptimizeForNetworkUse = true
      
      session.exportAsynchronously()
      {
         switch session.status
         {
         case .completed : MainQueue.async { videoCreationFinish(fileURL, nil) }
         case .failed :
            MainQueue.async {
               videoCreationFinish(fileURL, loc("Video creation failed" + ": ") + (session.error?.localizedDescription ?? loc("Error")))
            }
         case .cancelled : MainQueue.async { videoCreationFinish(fileURL, loc("Video creation canceled")) }
         default : break
         }
      }
   }
   
   class func videoCompositionInstruction(track: AVCompositionTrack, asset: AVAsset, contentMode : VideoContentMode, videoSize : CGSize? = nil) -> AVMutableVideoCompositionLayerInstruction
   {
      let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
      guard let assetTrack = asset.tracks(withMediaType: AVMediaTypeVideo).first else {
         return instruction
      }
      
      let videoSize : CGSize = videoSize ?? VideoSize
      let videoWidth = videoSize.width
      let videoHeight = videoSize.height
      
      var transform = assetTrack.preferredTransform
      
      let assetVideoSize = assetTrack.naturalSize.applying(transform)
      let assetVideoWidth = abs(assetVideoSize.width)
      let assetVideoHeight = abs(assetVideoSize.height)
      
      let scaleX = videoWidth / assetVideoWidth
      let scaleY = videoHeight / assetVideoHeight
      
      switch contentMode
      {
      case .scaleToFill:
         let scaleFactor = CGAffineTransform(scaleX: scaleX, y: scaleY)
         transform = transform.concatenating(scaleFactor)
         
      case .scaleAspectFit, .scaleAspectFill:
         let scaleRatio = (contentMode == .scaleAspectFit) ? min(scaleX, scaleY) : max(scaleX, scaleY)
         let scaleFactor = CGAffineTransform(scaleX: scaleRatio, y: scaleRatio)
         transform = transform.concatenating(scaleFactor)
      }
      
      // center fix: adjust translation for scaled size to be centered in video size
      let rect = CGRect(origin: .zero, size: assetTrack.naturalSize)
      let transformedRect = rect.applying(transform)
      let centerFix = CGAffineTransform(translationX: (videoWidth - transformedRect.width) / 2  - transformedRect.origin.x,
                                        y: (videoHeight - transformedRect.height) / 2  - transformedRect.origin.y)
      transform = transform.concatenating(centerFix)
      
      instruction.setTransform(transform, at: kCMTimeZero)
      return instruction
   }
   
   //MARK: Video From Photos
   
   fileprivate static var videoWriter : AVAssetWriter?
   fileprivate static let videoWriterLock : NSLock = NSLock()
   private static var videoWriterTask : UIBackgroundTaskIdentifier?
   
   private class func createVideoFromPhotos(_ medias : [Media])
   {
      let startTime = Date()
      
      let fileName = UUID().uuidString + ".mp4"
      let fileURL = URL(fileURLWithPath: tempDirectory).appendingPathComponent(fileName, isDirectory: false)
      let writer : AVAssetWriter
      
      do {
         writer = try AVAssetWriter(url: fileURL, fileType: AVFileTypeMPEG4)
      }
      catch let error {
         dlog(error)
         videoCreationFinish(fileURL, error.localizedDescription)
         return
      }
      videoWriter = writer
      
      let videoSettings : [String : Any] = [AVVideoCodecKey : AVVideoCodecH264, AVVideoWidthKey : VideoWidth, AVVideoHeightKey : VideoHeight]
      let writerInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
      writerInput.expectsMediaDataInRealTime = false
      let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)
      guard writer.canAdd(writerInput) else
      {
         videoCreationFinish(fileURL, "Can not add images input")
         return
      }
      writer.add(writerInput)
      
      videoWriterTask = Application.beginBackgroundTask(expirationHandler:
      {
         dlog("Did not finish creating video due to background transition")
         if let task = videoWriterTask {
            videoWriterTask = nil
            Application.endBackgroundTask(task)
         }
      })
      
      let secondsPerPhoto = videoPhotoSpeedValue
      let frameTime = CMTime(seconds: secondsPerPhoto, preferredTimescale: 600)
      var time : CMTime = kCMTimeZero
      var captions : [VideoCaption] = []
      
      writer.startWriting()
      writer.startSession(atSourceTime: kCMTimeZero)
      
      var i = 0
      let mediasCount = medias.count
      
      writerInput.requestMediaDataWhenReady(on: MainQueue)
      {
         photoCreationProgress = Float(i) / Float(mediasCount)
         while writerInput.isReadyForMoreMediaData
         {
            photoCreationProgress = Float(i) / Float(mediasCount)
            guard !cancel else { break }
            
            guard i < mediasCount else
            {
               writerInput.markAsFinished()
               writer.endSession(atSourceTime: time)
               writer.finishWriting
               {
                  guard !cancel else { return }
                  
                  switch writer.status
                  {
                  case .completed :
                     if let task = videoWriterTask {videoWriterTask = nil; Application.endBackgroundTask(task) }
                     videoWriter = nil
                     print("photos time:", -startTime.timeIntervalSinceNow)
                     MainQueue.async { addSongAndCaptions(fileURL, captions: captions) }
                  case .failed :
                     if let task = videoWriterTask {videoWriterTask = nil; Application.endBackgroundTask(task) }
                     videoWriter = nil
                     MainQueue.async {
                        videoCreationFinish(fileURL, loc("Video creation failed" + ": ") + (writer.error?.localizedDescription ?? loc("Error")))
                     }
                  case .cancelled :
                     if let task = videoWriterTask {videoWriterTask = nil; Application.endBackgroundTask(task) }
                     videoWriter = nil
                     MainQueue.async { videoCreationFinish(fileURL, loc("Video creation canceled")) }
                  default : break
                  }
               }
               
               break
            }
            
            let media = medias[i]
            i += 1
            
            guard !media.isInvalidated, media.checkLoadedFile(), let image = media.getImage() else
            {
               dlog(media)
               continue
            }
            
            guard let buffer = createPixelBuffer(from: image, contentMode: videoContentMode) else { continue }
            var added : Bool = false
            videoWriterLock.synchronized
            {
               if !cancel {
                  added = adaptor.append(buffer, withPresentationTime: time)
               }
            }
            
            guard added else { continue }
            
            if showAge
            {
               var ageString = ""
               switch media.status
               {
               case .baby:
                  if let birthday = persona.birthday,
                     let string = babyAgeStringFormatter.string(from: birthday.getDate(), to: media.date.getDate())
                  {
                     ageString = string
                  }
               case .pregnant:
                  ageString = String(format: loc("Week %d"), media.pregnancyWeek)
                  
               }
               ageString = ageString.replacingOccurrences(of: ",", with: "")
               
               let caption: VideoCaption = (timeRange: CMTimeRange(start: time, duration: frameTime), text: ageString)
               captions.append(caption)
            }
            
            time = time + frameTime
         }
      }
   }
   
   private static var pxBuffer : CVPixelBuffer?
   private static var pxContext : CGContext?
   
   private class func createPixelBuffer(from image: UIImage, contentMode : VideoContentMode) -> CVPixelBuffer?
   {
      let options = [kCVPixelBufferCGImageCompatibilityKey as String : true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey as String : true,
                     kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32ARGB,
                     kCVPixelBufferWidthKey as String : VideoWidth,
                     kCVPixelBufferHeightKey as String : VideoHeight] as CFDictionary
      
      var pixelBuffer : CVPixelBuffer! = pxBuffer
      var context : CGContext! = pxContext
      let lockFlags = CVPixelBufferLockFlags(rawValue: 0)
      
      if pixelBuffer == nil || context == nil
      {
         let status = CVPixelBufferCreate(nil, VideoWidth, VideoHeight, kCVPixelFormatType_32ARGB, options, &pxBuffer)
         guard status == kCVReturnSuccess, pxBuffer != nil else { return nil }
         pixelBuffer = pxBuffer
         
         CVPixelBufferLockBaseAddress(pixelBuffer, lockFlags)
         
         guard let pixelBufferBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, lockFlags); return nil
         }
         
         pxContext = CGContext(data: pixelBufferBaseAddress, width: VideoWidth, height: VideoHeight, bitsPerComponent: 8, bytesPerRow: 4 * VideoWidth, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
         
         guard pxContext != nil else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, lockFlags); return nil
         }
         
         context = pxContext
         context.translateBy(x: 0, y: VideoHeightFloat)
         context.scaleBy(x: 1.0, y: -1.0)
         context.setFillColor(UIColor.black.cgColor)
      }
      else
      {
         CVPixelBufferLockBaseAddress(pixelBuffer, lockFlags)
      }

      UIGraphicsPushContext(context)
      context.fill(VideoRect)
      
      switch contentMode
      {
      case .scaleToFill:
         image.draw(in: VideoRect)
      
      case .scaleAspectFit, .scaleAspectFill:
         let scaleX = VideoWidthFloat / image.size.width
         let scaleY = VideoHeightFloat / image.size.height
         
         let scaleRatio = (contentMode == .scaleAspectFit) ? min(scaleX, scaleY) : max(scaleX, scaleY)
         let scaleFactor = CGAffineTransform(scaleX: scaleRatio, y: scaleRatio)
         
         let scaledSize = image.size.applying(scaleFactor)
         let scaledWidth = abs(scaledSize.width)
         let scaledHeight = abs(scaledSize.height)
         
         let centeredRect = CGRect(x: (VideoWidthFloat - scaledWidth) / 2, y: (VideoHeightFloat - scaledHeight) / 2, width: scaledWidth, height: scaledHeight)
         
         image.draw(in: centeredRect)
      }
      
      UIGraphicsPopContext()
      CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
      
      return pixelBuffer
   }
   
   
   private typealias VideoCaption = (timeRange : CMTimeRange, text : String)
   private class func addSongAndCaptions(_ tempVideoUrl : URL, captions : [VideoCaption]? = nil)
   {
      guard !isNilOrEmpty(captions) || addLogo || audioFileUrl != nil else
      {
         MainQueue.async { videoCreationFinish(tempVideoUrl, nil) }
         return
      }
      
      let startTime = Date()

      let mixComposition = AVMutableComposition()
      let videoComposition = AVMutableVideoComposition()
      let asset = AVURLAsset(url: tempVideoUrl)
      let totalTime = asset.duration
      let timeRange = CMTimeRange(start: kCMTimeZero, duration: totalTime)
      let timeRangeValue = NSValue(timeRange: timeRange)
      
      let compositionInstruction = AVMutableVideoCompositionInstruction()
      compositionInstruction.timeRange = timeRange
      compositionInstruction.backgroundColor = UIColor.black.cgColor
      videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
      videoComposition.renderSize = VideoSize
      videoComposition.instructions = [compositionInstruction]
      
      let assetVideoTracks = asset.tracks(withMediaType: AVMediaTypeVideo)
      let assetAudioTracks = asset.tracks(withMediaType: AVMediaTypeAudio)
      
      if !assetVideoTracks.isEmpty
      {
         let videoTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
         let videoTimeRanges = Array<NSValue>(repeating: timeRangeValue, count: assetVideoTracks.count)
         
         do {
            try videoTrack.insertTimeRanges(videoTimeRanges, of: assetVideoTracks, at: kCMTimeZero)
         }
         catch let error {
            dlog(error)
         }
         
         let instruction = videoCompositionInstruction(track: videoTrack, asset: asset, contentMode: videoContentMode)
         compositionInstruction.layerInstructions.append(instruction)
      }
      
      if !assetAudioTracks.isEmpty
      {
         let audioTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
         let audioTimeRanges = Array<NSValue>(repeating: timeRangeValue, count: assetAudioTracks.count)
         
         do {
            try audioTrack.insertTimeRanges(audioTimeRanges, of: assetAudioTracks, at: kCMTimeZero)
         }
         catch let error {
            dlog(error)
         }
      }
      
      let addOverlays : Bool = addLogo || !(captions?.isEmpty ?? true)
      if addOverlays
      {
         let parentLayer = CALayer()
         let videoLayer = CALayer()
         parentLayer.frame = VideoRect
         videoLayer.frame = parentLayer.frame
         parentLayer.addSublayer(videoLayer)
         
         if let captions = captions, !captions.isEmpty
         {
            for caption in captions
            {
               let font = captionFont
               let fontSize = captionFontSize
               
               let textLayer = CATextLayer()
               textLayer.string = caption.text
               textLayer.fontSize = fontSize
               textLayer.font = font
               let textMargin = fontSize
               textLayer.frame = CGRect(x: textMargin, y: 0, width: VideoWidthFloat - textMargin * 2, height: fontSize * 1.8)
               textLayer.alignmentMode = kCAAlignmentRight
               textLayer.foregroundColor = captionColor.cgColor
               textLayer.isWrapped = true
               textLayer.truncationMode = kCATruncationEnd
               textLayer.allowsFontSubpixelQuantization = true
               
               parentLayer.addSublayer(textLayer)
               
               textLayer.opacity = 0
               let animation = CAKeyframeAnimation(keyPath: "opacity")
               animation.isRemovedOnCompletion = false
               animation.fillMode = kCAFillModeRemoved
               animation.calculationMode = kCAAnimationDiscrete
               animation.beginTime = (caption.timeRange.start == kCMTimeZero) ? AVCoreAnimationBeginTimeAtZero : CFTimeInterval(caption.timeRange.start.seconds)
               animation.duration = CFTimeInterval((caption.timeRange.duration - videoComposition.frameDuration).seconds) // -1 кадр чтобы не было наложения надписей
               animation.keyTimes = [0.0, 1.0]
               animation.values = [1.0]
               textLayer.add(animation, forKey: "opacityAnimation")
            }
         }
         
         if addLogo
         {
            let logoLayer = CALayer()
            let logo : UIImage = #imageLiteral(resourceName: "babyLogo.png")
            let logoWidth = logo.size.width * sizeMultiplier
            let logoHeight = logo.size.height * sizeMultiplier
            logoLayer.frame = CGRect(x: logoWidth, y: VideoHeightFloat - logoHeight * 1.2, width: logoWidth, height: logoHeight)
            logoLayer.contentsScale = logo.scale
            logoLayer.contents = logo.cgImage
            parentLayer.addSublayer(logoLayer)
            
            let font = logoLinkFont
            let fontSize = logoLinkFontSize
            
            let linkLayer = CATextLayer()
            linkLayer.string = "MYBABYMY.com"
            linkLayer.fontSize = fontSize
            linkLayer.font = font
            let linkHeight = fontSize * 2
            linkLayer.frame = CGRect(x: fontSize, y: logoLayer.frame.minY - linkHeight * 1.1,
                                     width: VideoWidthFloat - fontSize * 2, height: linkHeight)
            linkLayer.alignmentMode = kCAAlignmentLeft
            linkLayer.foregroundColor = logoLinkColor.cgColor
            linkLayer.allowsFontSubpixelQuantization = true
            parentLayer.addSublayer(linkLayer)
         }
         
         videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
      }
      
      if let audioUrl = audioFileUrl
      {
         let audioAsset = AVURLAsset(url: audioUrl)
         let assetAudioTracks = audioAsset.tracks(withMediaType: AVMediaTypeAudio)
         
         if !assetAudioTracks.isEmpty
         {
            let audioTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            let audioDuration = audioAsset.duration
            var currentTime = kCMTimeZero
            
            while true
            {
               let duration = min(audioDuration, totalTime - currentTime)
               let timeRangeValue = NSValue(timeRange: CMTimeRange(start: kCMTimeZero, duration: duration))
               let audioTimeRanges = Array<NSValue>(repeating: timeRangeValue, count: assetAudioTracks.count)
               
               do {
                  try audioTrack.insertTimeRanges(audioTimeRanges, of: assetAudioTracks, at: currentTime)
               }
               catch let error {
                  dlog(error)
                  break
               }
               
               currentTime = currentTime + duration
               if currentTime >= totalTime {
                  break
               }
            }
         }
      }
      
      let fileName = UUID().uuidString + ".mp4"
      let fileURL = URL(fileURLWithPath: tempDirectory).appendingPathComponent(fileName, isDirectory: false)
      
      guard let session = AVAssetExportSession(asset: mixComposition, presetName: sessionPreset) else
      {
         videoCreationFinish(fileURL, loc("Video creation failed"))
         return
      }
      exportSession = session
      
      session.videoComposition = videoComposition
      session.outputURL = fileURL
      session.outputFileType = AVFileTypeMPEG4
      session.shouldOptimizeForNetworkUse = true
      
      session.exportAsynchronously()
      {
         switch session.status
         {
         case .completed :
            try? FileManager.default.removeItem(at: tempVideoUrl)
            print("song and captions time:", -startTime.timeIntervalSinceNow)
            MainQueue.async { videoCreationFinish(fileURL, nil) }
            
         case .failed :
            try? FileManager.default.removeItem(at: tempVideoUrl)
            MainQueue.async {
               videoCreationFinish(fileURL, loc("Video creation failed" + ": ") + (session.error?.localizedDescription ?? loc("Error")))
            }
            
         case .cancelled :
            try? FileManager.default.removeItem(at: tempVideoUrl)
            MainQueue.async { videoCreationFinish(fileURL, loc("Video creation canceled")) }
            
         default : break
         }
      }
   }
   
   //MARK: Completion
   
   fileprivate class func videoCreationFinish(_ videoURL : URL?, _ errorDescription : String?)
   {
      updateProgressTimer?.invalidate()
      updateProgressTimer = nil
      if let audioUrl = audioFileUrl, audioFileIsTempCopy {
         BackgroundQueue.async { try? FileManager.default.removeItem(at: audioUrl) }
      }
      audioFileUrl = nil
      audioFileIsTempCopy = false
      spinnerController = nil
      pxBuffer = nil
      pxContext = nil
      videoWriter = nil
      exportSession = nil
      photoCreationProgress = nil
      
      dismissSpinner
      {
         if let errorDesc = errorDescription
         {
            if let url = videoURL {
               BackgroundQueue.async { try? FileManager.default.removeItem(at: url) }
            }
            if !cancel {
               AlertManager.showAlert(errorDesc)
            }
         }
         else
         {
            let playerController = Storyboard.instantiateViewController(withIdentifier: "VideoPlayerController") as! VideoPlayerController
            playerController.videoURL = videoURL!
            playerController.videoContainsLogoLink = addLogo
            
            AppDelegate.allowLandscapeOrientation = true
            UIViewController.attemptRotationToDeviceOrientation()
            if let navController = presentingController?.navigationController {
               navController.pushViewController(playerController, animated: true)
            }
            else {
               presentingController?.present(playerController, animated: true, completion: nil)
            }
         }
         
         presentingController = nil
         
         if let task = videoWriterTask {
            videoWriterTask = nil
            Application.endBackgroundTask(task)
         }
      }
   }
}

//MARK: - Spinner
internal class CreateVideoSpinnerController: UIViewController
{
   @IBOutlet weak var spinningCircles: UIImageView!
   @IBOutlet weak var progressView: UIProgressView!
   @IBOutlet weak var statusLabel: UILabel!
   
   override func viewWillAppear(_ animated: Bool)
   {
      super.viewWillAppear(animated)
      Synchronization.forbidden = true
      UIView.animateIgnoringInherited(withDuration: 0.5, delay: 0, options: [.curveLinear, .repeat], animations:
      {
         self.spinningCircles.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
      }, completion: nil)
   }
   
   override func viewWillDisappear(_ animated: Bool)
   {
      super.viewWillDisappear(animated)
      Synchronization.forbidden = false
   }
   
   @objc func updateVideoCreationProgress(sender : Timer)
   {
      var progress : Float = 0

      if let session = VideoMaker.exportSession {
         progress = session.progress
      }
      if let photoProgress = VideoMaker.photoCreationProgress {
         progress = progress * 0.85 + photoProgress * 0.15
      }
      
      progressView.setProgress(progress, animated: true)
   }
   
   @IBAction func cancelTap()
   {
      VideoMaker.cancel = true
      var finishCalled = false
      
      if let audioRequest = VideoMaker.audioLoadRequest {
         audioRequest.cancel()
      }
      if let writer = VideoMaker.videoWriter
      {
         VideoMaker.videoWriterLock.synchronized {
            writer.cancelWriting()
         }
      }
      if let session = VideoMaker.exportSession
      {
         finishCalled = true
         session.cancelExport()
      }
      
      if !finishCalled
      {
         finishCalled = true
         VideoMaker.videoCreationFinish(nil, loc("Video creation canceled"))
      }
   }
}
