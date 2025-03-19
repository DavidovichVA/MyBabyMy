//
//  MediaTakeController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 1/4/17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation
import RealmSwift

private enum TakenMedia
{
   case none
   case photo(image : UIImage)
   case video(tempFileUrl : URL)
   case existedPhoto(image : UIImage)
   case existedVideo(fileUrl : URL)
}

private enum VideoDuration : Int
{
   case sec2 = 2
   case sec3 = 3
}

private enum InterfaceOrientation
{
   case portrait
   case landscapeLeft
   case landscapeRight
}

class MediaTakeController: UIViewController, TabsViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVCaptureFileOutputRecordingDelegate
{
   @IBOutlet weak var topView: UIView!
   @IBOutlet weak var cancelButton: UIButton!   
   @IBOutlet weak var durationButtonsView: UIView!
   @IBOutlet weak var seconds2Button: HighlightedColorButton!
   @IBOutlet weak var seconds3Button: HighlightedColorButton!
   @IBOutlet weak var changeTemplateButton: UIButton!
   @IBOutlet weak var flashButton: UIButton!
   @IBOutlet weak var leftBottomButton: UIButton!
   @IBOutlet weak var centerBottomButton: UIButton!
   @IBOutlet weak var rightBottomButton: UIButton!
   @IBOutlet weak var bottomButtonsView: UIView!
   
   @IBOutlet weak var displayContainerView: UIView!
   @IBOutlet weak var displayView: UIView!
   @IBOutlet weak var displayRotatingView: UIView!
   @IBOutlet weak var displayImageView: UIImageView!
   @IBOutlet weak var displayTemplateView: UIImageView!
   @IBOutlet weak var capturedVideoPlayView: UIView!
   @IBOutlet weak var countLabel: UILabel!
   @IBOutlet weak var countLabelBottom: NSLayoutConstraint!
   
   @IBOutlet weak var tabsView: TabsView!
   
   private let grayColor = rgb(137, 141, 152)
   private let pinkColor = rgb(255, 120, 154)
   
   private var orientation : InterfaceOrientation = .portrait
   
   private var selectedVideoDuration : VideoDuration =
   {
      let lastDurationValue = UserDefaults.standard.integer(forKey: "lastSelectedVideoDuration")
      if let duration = VideoDuration(rawValue: lastDurationValue) {
         return duration
      }
      else {
         return VideoDuration.sec3
      }
   }()
   {
      didSet {
         UserDefaults.standard.set(selectedVideoDuration.rawValue, forKey: "lastSelectedVideoDuration")
      }
   }
   
   var status : PersonaStatus = .baby
   var date : DMYDate = DMYDate.currentDate()
   var pregnancyWeek : Int = 0
   var mediaType : BabyMediaType = .photo   
   var currentDate = DMYDate.currentDate()
	
	
   private var medias : [BabyMediaType : (media : Media, taken : TakenMedia)] = [:]
   private var media : Media {
      return medias[mediaType]!.media
   }
   private var takenMedia : TakenMedia {
      return medias[mediaType]!.taken
   }
   private var isMediaTaken : Bool
   {
      switch takenMedia {
         case .none: return false
         default: return true
      }
   }
   
   private let scaleTransform = CGAffineTransform(scaleX: WidthRatio, y: WidthRatio)
   
   private var templateMirrored = false
   private var canChangeTemplateSide = false
   
   private let sessionLock : NSLock = NSLock()
   private var captureSession: AVCaptureSession!
   private var previewLayer: AVCaptureVideoPreviewLayer!
   private var videoPlayer : AVPlayer!
   private var playerLayer : AVPlayerLayer!
   private var stillImageOutput: AVCaptureStillImageOutput!
   private var videoFileOutput: AVCaptureMovieFileOutput!
   
   private let microphone : AVCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
   
   private let frontCamera : AVCaptureDevice =
   {
      var camera : AVCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
      let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) ?? []
      for device in devices
      {
         if let captureDevice = device as? AVCaptureDevice, captureDevice.position == .front
         {
            camera = captureDevice
            break
         }
      }
      
      do {
         try camera.lockForConfiguration()
         camera.videoZoomFactor = 1
      }
      catch let error {
         dlog(error.localizedDescription)
      }
      
      return camera
   }()
   
   private let backCamera : AVCaptureDevice =
   {
      var camera : AVCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
      let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) ?? []
      for device in devices
      {
         if let captureDevice = device as? AVCaptureDevice, captureDevice.position == .back
         {
            camera = captureDevice
            break
         }
      }
      
      do {
         try camera.lockForConfiguration()
         camera.videoZoomFactor = 1
      }
      catch let error {
         dlog(error.localizedDescription)
      }
      
      return camera
   }()
   
   private var useFrontCamera = false
   private var currentCamera : AVCaptureDevice {
      return useFrontCamera ? frontCamera : backCamera
   }
   
   private var useFlash = false
   
   private var maxVideoDuration : Double = 2
   private var videoStartRecord : Date!
   private var displayLink : CADisplayLink?
   
   private var videoStopTask : UIBackgroundTaskIdentifier?
   
   //MARK: - Lifecycle
   
   override func viewDidLoad()
   {
      super.viewDidLoad()
      
      tabsView.scrollingEnabled = false
      tabsView.delegate = self
      
      changeTemplateButton.transform = scaleTransform
      flashButton.transform = scaleTransform
      
      setupForVideo()
      setupApplicationObservers()
      setupUserProObserver()
      setInitialTemplateSide()
      
      updateVideoDurationButtons()
      updateTabsInteractionEnabled()
      
      leftBottomButton.titleLabel?.numberOfLines = 2
      leftBottomButton.titleLabel?.lineBreakMode = .byWordWrapping
      leftBottomButton.titleLabel?.textAlignment = .center
      rightBottomButton.titleLabel?.numberOfLines = 2
      rightBottomButton.titleLabel?.lineBreakMode = .byWordWrapping
      rightBottomButton.titleLabel?.textAlignment = .center
   }
   
   override var prefersStatusBarHidden: Bool {
      return !isMediaTaken
   }
   
   override func viewWillAppear(_ animated: Bool)
   {
      super.viewWillAppear(animated)
      if let navigationBar = navigationController?.navigationBar
      {
         navigationBar.isTranslucent = false
         navigationBar.shadowImage = nil
         navigationBar.setBackgroundImage(nil, for: UIBarMetrics.default)
         navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: pinkColor,
                                               NSFontAttributeName : UIFont.systemFont(ofSize: 12, weight: UIFontWeightMedium)]
      }
		
      UIDevice.current.beginGeneratingDeviceOrientationNotifications()
      MainQueue.async {
         self.updateCurrentOrientation()
      }
      updateUI(animated)
   }	
	
   private var didSetStartTab = false
   override func viewDidLayoutSubviews()
   {
      super.viewDidLayoutSubviews()
      if !didSetStartTab {
         tabsView.setStartType(mediaType)
      }
      
      updateVideoLayersFrames()
      
      cancelButton.invalidateIntrinsicContentSize()
      topView.layoutIfNeeded()
   }
   
   func updateVideoLayersFrames()
   {
      loadViewIfNeeded()
      previewLayer.frame = displayView.layer.bounds
      playerLayer.frame = capturedVideoPlayView.layer.bounds
   }
   
   override func viewDidAppear(_ animated: Bool)
   {
      super.viewDidAppear(animated)
      didSetStartTab = true
   }
   
   override func viewDidDisappear(_ animated: Bool)
   {
      super.viewDidDisappear(animated)
      stopVideoAnimation()
      UIDevice.current.endGeneratingDeviceOrientationNotifications()
      sessionLock.lock()
      captureSession.stopRunning()
      sessionLock.unlock()   }
   
   //MARK: - Methods
   
   func setup()
   {
      guard let user = User.current else { return }
      for type in BabyMediaType.allValues
      {
         var takenMedia : TakenMedia
         var media : Media
         
         if let existedMedia = user.mainPersona.media(status: status, type: type, date: date, week: pregnancyWeek)
         {
            media = Media(value: existedMedia)
            switch type
            {
            case .photo, .photoInDynamics:
               if let image = media.getImage() {
                  takenMedia = .existedPhoto(image: image)
               }
               else {
                  takenMedia = .none
               }
               
            case .video:
               if media.checkLoadedFile() {
                  takenMedia = .existedVideo(fileUrl: media.fileURL)
               }
               else {
                  takenMedia = .none
               }
            }
         }
         else
         {
            media = Media()
            media.persona = user.mainPersona
            media.type = type
            media.status = status
            media.link = nil
            media.fileLoaded = false
            switch status {
               case .baby: media.date = date
               case .pregnant: media.pregnancyWeek = pregnancyWeek
            }
            takenMedia = .none
         }

         medias[type] = (media, takenMedia)
      }
   }
   
   private var wasMediaTaken = false
   private var firstUpdateUI = true
   
   func updateUI(_ animated: Bool = false)
   {
      updateFlash()
      updateRotation()
      
      let isMediaTaken = self.isMediaTaken
      
      guard let user = User.current else { return }
      
      let navBarHidden = !isMediaTaken
      let title : String
      switch mediaType {
         case .photo, .photoInDynamics: title = loc("PHOTO PREVIEW")
         case .video: title = loc("VIDEO PREVIEW")
      }
      
      let animateDuration = animated ? 0.3 : 0
      
      let addMicrophoneAtStart = (!microphoneInputAdded && microphoneAccessAllowed)
      setCameraPreview((isMediaTaken ? nil : currentCamera), addMicrophone: addMicrophoneAtStart)
      
      if firstUpdateUI || (isMediaTaken != wasMediaTaken)
      {
         CATransaction.begin()
         CATransaction.setDisableActions(true)
         
         if isMediaTaken
         {
            let canRetake = (status == .pregnant) || user.isPro || (date == DMYDate.currentDate())
            leftBottomButton.isHidden = !canRetake
            leftBottomButton.removeTarget(nil, action: nil, for: .allEvents)
            if (canRetake) { leftBottomButton.addTarget(self, action: #selector(retakeTap), for: .touchUpInside) }
            leftBottomButton.setImage(nil, for: .normal)
            leftBottomButton.setTitle(loc("RETAKE"), for: .normal)
            leftBottomButton.transform = .identity
            
            centerBottomButton.removeTarget(nil, action: nil, for: .allEvents)
            centerBottomButton.addTarget(self, action: #selector(confirmTap), for: .touchUpInside)
            centerBottomButton.setImage(#imageLiteral(resourceName: "checkPinkIcon"), for: .normal)
            
            rightBottomButton.removeTarget(nil, action: nil, for: .allEvents)
            rightBottomButton.addTarget(self, action: #selector(editInfoTap), for: .touchUpInside)
            rightBottomButton.setImage(nil, for: .normal)
            rightBottomButton.setTitle(loc("EDIT INFO"), for: .normal)
            rightBottomButton.transform = .identity
         }
         else
         {
            leftBottomButton.isHidden = false
            leftBottomButton.removeTarget(nil, action: nil, for: .allEvents)
            leftBottomButton.addTarget(self, action: #selector(pickFromGalleryTap), for: .touchUpInside)
            leftBottomButton.setTitle(nil, for: .normal)
            leftBottomButton.setImage(#imageLiteral(resourceName: "pickFromGallery"), for: .normal)
            leftBottomButton.transform = scaleTransform
            
            centerBottomButton.removeTarget(nil, action: nil, for: .allEvents)
            centerBottomButton.addTarget(self, action: #selector(cameraTap), for: .touchUpInside)
            centerBottomButton.setImage(#imageLiteral(resourceName: "takeMedia"), for: .normal)
            
            rightBottomButton.removeTarget(nil, action: nil, for: .allEvents)
            rightBottomButton.addTarget(self, action: #selector(changeCameraTap), for: .touchUpInside)
            rightBottomButton.setTitle(nil, for: .normal)
            rightBottomButton.setImage(#imageLiteral(resourceName: "changeCamera"), for: .normal)
            rightBottomButton.transform = scaleTransform
         }
         
         self.leftBottomButton.layoutIfNeeded()
         self.centerBottomButton.layoutIfNeeded()
         self.rightBottomButton.layoutIfNeeded()
         self.bottomButtonsView.layoutIfNeeded()
         
         CATransaction.commit()
      }
      
      if (mediaType == .video && !isMediaTaken && !microphoneInputAdded && !addMicrophoneAtStart) {
         addMicrophone()
      }
      
      switch takenMedia
      {
      case .photo(let image), .existedPhoto(let image):
         UIView.transitionIgnoringInherited(with: displayContainerView, duration: animateDuration, options: .transitionCrossDissolve, animations: {
            self.displayImageView.image = image
            self.displayTemplateView.image = nil
         }, completion: nil)
         stopVideoAnimation()
      
      case .video(let videoFileUrl), .existedVideo(let videoFileUrl):
         UIView.transitionIgnoringInherited(with: displayContainerView, duration: animateDuration, options: .transitionCrossDissolve, animations: {
            self.displayImageView.image = nil
            self.displayTemplateView.image = nil
         }, completion: nil)
         startVideoAnimation(videoFileUrl)
         
      case .none:
         UIView.transitionIgnoringInherited(with: displayContainerView, duration: animateDuration, options: .transitionCrossDissolve, animations: {
            self.displayImageView.image = nil
            if self.mediaType == .photoInDynamics
            {
               switch self.status {
                  case .baby : self.displayTemplateView.image = #imageLiteral(resourceName: "templateBaby")
                  case .pregnant : self.displayTemplateView.image = #imageLiteral(resourceName: "templatePregnancy")
               }
            }
            else {
               self.displayTemplateView.image = nil
            }
         }, completion: nil)
         stopVideoAnimation()
      }
      
      UIView.animateIgnoringInherited(withDuration: animateDuration,
      animations:
      {
         if !navBarHidden {
            self.navigationItem.title = title
            self.navigationController?.setNavigationBarHidden(navBarHidden, animated: false)
         }
         self.setNeedsStatusBarAppearanceUpdate()
         self.navigationController?.navigationBar.alpha = navBarHidden ? 0 : 1
         self.topView.alpha = navBarHidden ? 1 : 0
         if self.canChangeTemplateSide {
            self.changeTemplateButton.alpha = (self.mediaType == .photoInDynamics) ? 1 : 0
         }
         self.durationButtonsView.alpha = (self.mediaType == .video) ? 1 : 0
      },
      completion: {
         finished in
         self.navigationItem.title = title
         self.navigationController?.setNavigationBarHidden(navBarHidden, animated: false)
         self.view.isUserInteractionEnabled = true
         self.updateVideoLayersFrames()
      })
      
      firstUpdateUI = false
      wasMediaTaken = isMediaTaken
	
   }
   
   func updateTabsInteractionEnabled()
   {
      if let user = User.current {
         tabsView.isUserInteractionEnabled = user.isPro || (status == .pregnant) || (date == DMYDate.currentDate())
      }
   }
   
   private var templateTransform : CGAffineTransform {
      return templateMirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
   }
   
   func setInitialTemplateSide()
   {
      guard status == .pregnant else
      {
         templateMirrored = false
         displayTemplateView.transform = templateTransform
         changeTemplateButton.isHidden = true
         return
      }
      
      let media = medias[.photoInDynamics]!.media
      
      let photosInDynamicsPregnant : List<Media> = media.persona?.photosInDynamicsPregnant ?? List<Media>()
      
      let photosCount = photosInDynamicsPregnant.count
      if photosCount > 0
      {
         let firstPhotoIndynamics = photosInDynamicsPregnant.min(by: {m1, m2 in m1.pregnancyWeek < m2.pregnancyWeek})!
         
         if photosCount == 1 && firstPhotoIndynamics.pregnancyWeek == media.pregnancyWeek {
            templateMirrored = media.mirrored
            canChangeTemplateSide = true
         }
         else {
            templateMirrored = firstPhotoIndynamics.mirrored
            media.mirrored = templateMirrored
            canChangeTemplateSide = false
         }
      }
      else {
         templateMirrored = media.mirrored
         canChangeTemplateSide = true
      }
      
      displayTemplateView.transform = templateTransform
      changeTemplateButton.isHidden = !canChangeTemplateSide
   }
   
   func updateTemplateSide(_ animated : Bool = true)
   {
      changeTemplateButton.isEnabled = false
      
      UIView.transition(with: displayTemplateView, duration: (animated ? 0.5 : 0),
      options: [(templateMirrored ? .transitionFlipFromRight : .transitionFlipFromLeft)],
      animations:
      {
         self.displayTemplateView.transform = self.templateTransform
      },
      completion: { _ in
         self.changeTemplateButton.isEnabled = true
      })
   }
   
   func updateVideoDurationButtons()
   {
      let selectedButton : HighlightedColorButton
      let unselectedButton : HighlightedColorButton
      switch selectedVideoDuration
      {
         case .sec2: selectedButton = seconds2Button; unselectedButton = seconds3Button
         case .sec3: selectedButton = seconds3Button; unselectedButton = seconds2Button
      }
      
      selectedButton.setColor(normal: UIColor.white, higlighted: UIColor.white.withAlphaComponent(0.85))
      selectedButton.setTitleColor(pinkColor, for: .normal)
      
      unselectedButton.setColor(normal: UIColor.clear, higlighted: UIColor.white.withAlphaComponent(0.15))
      unselectedButton.setTitleColor(UIColor.white, for: .normal)
   }
   
   func createDisplayLink()
   {
      if let dLink = displayLink {
         dLink.invalidate()
      }
      displayLink = CADisplayLink(target: self, selector: #selector(updateVideoTimer(sender:)))
      displayLink?.add(to: RunLoop.main, forMode: .commonModes)
   }
   
   @objc func updateVideoTimer(sender : CADisplayLink)
   {
      let remainingTime = maxVideoDuration + videoStartRecord.timeIntervalSinceNow
      
      if remainingTime > 0
      {
         countLabel.text = String(Int(ceil(remainingTime)))
         countLabel.isHidden = false
      }
      else
      {
         countLabel.isHidden = true
         sender.invalidate()
      }
   }
   
   private func updateCurrentOrientation()
   {
      switch UIDevice.current.orientation
      {
      case .portrait, .portraitUpsideDown: self.orientation = .portrait
      case .landscapeLeft: self.orientation = .landscapeLeft
      case .landscapeRight: self.orientation = .landscapeRight
      default: break
      }
      
      self.updateRotation()
   }
   
   private func updateRotation()
   {
      guard !videoFileOutput.isRecording else { return }
      
      if mediaType == .photoInDynamics
      {
         displayRotatingView.transform = .identity
         countLabelBottom.constant = 10
      }
      else
      {
         switch orientation
         {
         case .portrait:
            displayRotatingView.transform = .identity
            countLabelBottom.constant = 10
            
         case .landscapeLeft:
            displayRotatingView.transform = CGAffineTransform(rotationAngle: CGFloat.pi/2)
            countLabelBottom.constant = 10 + (self.displayContainerView.height - self.displayContainerView.width) / 2
            
         case .landscapeRight:
            displayRotatingView.transform = CGAffineTransform(rotationAngle: -CGFloat.pi/2)
            countLabelBottom.constant = 10 + (self.displayContainerView.height - self.displayContainerView.width) / 2
         }
      }
   }
   
   func sizeImage(_ image : UIImage, forType type : BabyMediaType) -> UIImage
	{
      let boundingSize = mediaSize(forType: type)
      if image.size.width * image.scale > boundingSize.width || image.size.height * image.scale > boundingSize.height
      {
         let sizedImage = image.constrained(to: boundingSize, mode: .scaleAspectFill, useDeviceScale: false)
         return sizedImage
      }
      return image
   }
   
   func mediaSize(forType type : BabyMediaType) -> CGSize
   {
      if type == .photoInDynamics {
         return CGSize(width: 480, height: 640)
      }
      else {
         return CGSize.square(1280)
      }
   }
   
   func removeCurrentMedia()
   {
      var mediaData = medias[mediaType]!
      
      if case .video(let tempFileUrl) = mediaData.taken {
         BackgroundQueue.async { try? FileManager.default.removeItem(at: tempFileUrl) }
      }
      
      let currentMedia = mediaData.media
      
      mediaData.media = Media()
      mediaData.media.personaId = currentMedia.personaId
      mediaData.media.type = currentMedia.type
      mediaData.media.status = currentMedia.status
      mediaData.media.link = nil
      mediaData.media.fileLoaded = false
      switch currentMedia.status {
         case .baby: mediaData.media.date = currentMedia.date
         case .pregnant: mediaData.media.pregnancyWeek = currentMedia.pregnancyWeek
      }
      
      mediaData.taken = .none
      medias[mediaType] = mediaData
      
      updateUI(true)
   }
   
   func goToMediaInfo()
   {
      let mediaInfoController = Storyboard.instantiateViewController(withIdentifier: "MediaInfoController") as! MediaInfoController
      
      mediaInfoController.mediaTakeController = self
      mediaInfoController.media = media

      switch takenMedia
      {
         case .photo(let image), .existedPhoto(let image): mediaInfoController.infoType = .photo(image: image)
         case .video(let url), .existedVideo(let url): mediaInfoController.infoType = .video(videoFileUrl : url)
         case .none: return
      }
      
      navigationController?.pushViewController(mediaInfoController, animated: true)
   }
   
   func saveAndDismiss()
   {
      showAppSpinner()
      
      var wasError = false
      let completion =
      {
         hideAppSpinner()
         if !wasError {
            self.presentingViewController?.dismiss(animated: true, completion: nil)
         }
      }
      
      var videoConversionStarted = false
      let mediaIsCurrent = media.isCurrent
      
      for (type, mediaData) in medias
      {
         switch mediaData.taken
         {
         case .photo(let image):
            mediaData.media.timestamp = Int64(Date().timeIntervalSince1970)
            let sizedImage = sizeImage(image, forType: type)
            if let errorDescription = mediaData.media.save(image: sizedImage) {
               AlertManager.showAlert(errorDescription)
               wasError = true
            }
            else if let addedMedia = mediaData.media.persona?.addOrUpdate(mediaData.media), mediaIsCurrent
            {
               addedMedia.autoFillCurrentPlace()
               addedMedia.autoFillCurrentWeather()
            }
            
         case .video(let tempFileUrl):
            mediaData.media.timestamp = Int64(Date().timeIntervalSince1970)
            videoConversionStarted = true
            
            sizeAndConvertVideo(tempFileUrl, forType: type, completion:
            {
               (convertedURL, errorDescription) in
               
               if let errorDesc = errorDescription
               {
                  AlertManager.showAlert(errorDesc)
                  wasError = true
               }
               else
               {
                  dlog("Converted video: ", convertedURL!.relativePath)
                  BackgroundQueue.async { try? FileManager.default.removeItem(at: tempFileUrl) }
                  if let errorDesc = mediaData.media.save(video: convertedURL!)
                  {
                     AlertManager.showAlert(errorDesc)
                     wasError = true
                  }
                  else if let addedMedia = mediaData.media.persona?.addOrUpdate(mediaData.media), mediaIsCurrent
                  {
                     addedMedia.autoFillCurrentPlace()
                     addedMedia.autoFillCurrentWeather()
                  }
                  
                  BackgroundQueue.async { try? FileManager.default.removeItem(at: convertedURL!) }
               }

               completion()
            })
            
         case .existedPhoto, .existedVideo:
            if let updatedMedia = mediaData.media.persona?.addOrUpdate(mediaData.media), mediaIsCurrent
            {
               updatedMedia.autoFillCurrentPlace()
               updatedMedia.autoFillCurrentWeather()
            }
            
         case .none:
            if let existedMedia = User.current?.mainPersona.media(status: status, type: mediaData.media.type, date: date, week: pregnancyWeek) {
               existedMedia.delete()
            }
         }
      }
      
      if !videoConversionStarted {
         completion()
      }
   }
   
   func checkIfCanTakeMedia() -> Bool
   {
      guard let user = User.current else { return false }
      if user.isPro { return true }
      
      for (type, mediaData) in medias
      {
         if (type != mediaType)
         {
            switch mediaData.taken
            {
               case .none: break
               default:
                  let proController = Storyboard.instantiateViewController(withIdentifier: "SettingsProAccount")
                  navigationController?.pushViewController(proController, animated: true)
                  return false
            }
         }
      }
      
      return true
   }
   
   //MARK: - TabsViewDelegate
   
   func tabsViewShouldSelect(_ mediaType : BabyMediaType) -> Bool {
      return !videoFileOutput.isRecording
   }
   
   func tabsViewDidSelect(_ type : BabyMediaType, animated : Bool)
   {
      view.isUserInteractionEnabled = false
      mediaType = type
      updateUI(animated)
   }
   
   //MARK: - Observers

   private var applicationResignObserver : NSObjectProtocol?
   private var applicationBecomeActiveObserver : NSObjectProtocol?
   private var deviceOrientationChangeObserver : NSObjectProtocol?
   private var videoEndObserver : NSObjectProtocol?
   private var userProObserver : NSObjectProtocol?
   
   private func setupApplicationObservers()
   {
      applicationResignObserver = NotificationCenter.default.addObserver(forName: .UIApplicationWillResignActive, object: nil, queue: OperationQueue.main)
      {
         [weak self]
         notification in
         
         guard let strongSelf = self else { return }
         
         if strongSelf.videoFileOutput.isRecording
         {
            strongSelf.videoStopTask = Application.beginBackgroundTask(expirationHandler:
            {
               dlog("Did not finish record video due to background transition")
               if let task = strongSelf.videoStopTask {
                  Application.endBackgroundTask(task)
                  strongSelf.videoStopTask = nil
               }
            })
            
            strongSelf.videoFileOutput.stopRecording()
         }
         
         switch strongSelf.takenMedia
         {
            case .video, .existedVideo: strongSelf.stopVideoAnimation()
            default: break
         }
      }
      
      applicationBecomeActiveObserver = NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: OperationQueue.main)
      {
         [weak self]
         notification in
         
         guard let strongSelf = self else { return }
         
         if strongSelf.navigationController?.topViewController == self
         {
            switch strongSelf.takenMedia
            {
               case .video(let videoFileUrl), .existedVideo(let videoFileUrl): strongSelf.startVideoAnimation(videoFileUrl)
               default: break
            }
         }
      }
      
      deviceOrientationChangeObserver = NotificationCenter.default.addObserver(forName: .UIDeviceOrientationDidChange, object: nil, queue: OperationQueue.main)
      {
         [weak self]
         notification in
         guard let strongSelf = self else { return }
         strongSelf.updateCurrentOrientation()
      }
   }
   
   private func setupVideoEndObserver()
   {
      videoEndObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: OperationQueue.main)
      {
         [weak self]
         notification in
         
         guard let strongSelf = self else { return }
         
         guard let object = notification.object as? AVPlayerItem, let playerItem = strongSelf.videoPlayer.currentItem, object === playerItem else { return }
         
         UIView.animateIgnoringInherited(withDuration: 1, animations: {
            strongSelf.capturedVideoPlayView.alpha = 0
         },
         completion:
         {
            animationFinished in
            guard animationFinished else { return }
            strongSelf.startVideoAnimation()
         })
      }
   }
   
   private func setupUserProObserver()
   {
      userProObserver = NotificationCenter.default.addObserver(forName: .MBUserProChanged, object: nil, queue: OperationQueue.main)
      {
         [weak self]
         notification in
         
         guard let strongSelf = self else { return }
         
         if let currentUser = User.current, let user = notification.object as? User, user.id == currentUser.id,
            let proStatusChanged = notification.userInfo?[kUserProChangedStatus] as? Bool, proStatusChanged
         {
            strongSelf.updateUI(false)
            strongSelf.updateTabsInteractionEnabled()
         }
      }
   }
   
   deinit
   {
      if applicationResignObserver != nil {
         NotificationCenter.default.removeObserver(applicationResignObserver!)
      }
      if applicationBecomeActiveObserver != nil {
         NotificationCenter.default.removeObserver(applicationBecomeActiveObserver!)
      }
      if deviceOrientationChangeObserver != nil {
         NotificationCenter.default.removeObserver(deviceOrientationChangeObserver!)
      }
      if videoEndObserver != nil {
         NotificationCenter.default.removeObserver(videoEndObserver!)
      }
      if userProObserver != nil {
         NotificationCenter.default.removeObserver(userProObserver!)
      }
      if let dLink = displayLink {
         dLink.invalidate()
      }
      
      for mediaData in medias.values
      {
         if case .video(let tempFileUrl) = mediaData.taken {
            BackgroundQueue.async { try? FileManager.default.removeItem(at: tempFileUrl) }
         }
      }
   }
   
   
   //MARK: - ImagePicker
   
   func pickFromGallery()
   {
      let imagePicker = UIImagePickerController()
      imagePicker.delegate = self
      imagePicker.sourceType = .photoLibrary
      
      switch mediaType
      {
      case .photo, .photoInDynamics:
         imagePicker.mediaTypes = [kUTTypeImage as String]
         
      case .video:
         imagePicker.mediaTypes = [kUTTypeMovie as String, kUTTypeVideo as String]
         imagePicker.videoMaximumDuration = 3
      }
      
      imagePicker.modalPresentationStyle = .fullScreen
      present(imagePicker, animated: true, completion: nil)
   }
   
   public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any])
   {
      var mediaData = medias[mediaType]!
      
      var videoIsTooLong = false
      
      switch mediaType
      {
      case .photo, .photoInDynamics:
         guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else { break }
         mediaData.taken = .photo(image: image)
         medias[mediaType] = mediaData
      
      case .video:
         guard let videoFileURL = info[UIImagePickerControllerMediaURL] as? URL else { break }
         
         let durationInSeconds = getVideoDuration(videoFileURL)
         dlog(String(format: "duration: %.2f", durationInSeconds))
         
         if durationInSeconds < 4
         {
            mediaData.taken = .video(tempFileUrl: videoFileURL)
            medias[mediaType] = mediaData
         }
         else {
            videoIsTooLong = true
         }
      }
      
      updateUI(true)
      picker.presentingViewController?.dismiss(animated: true, completion:
      {
         if videoIsTooLong {
            AlertManager.showAlert(loc("Selected video is too long"))
         }
      })
   }
   
   public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      picker.presentingViewController?.dismiss(animated: true, completion: nil)
   }
   
   //MARK: - AV
   
   private func setupForVideo()
   {
      captureSession = AVCaptureSession()
      sessionLock.lock()
      captureSession.beginConfiguration()
      captureSession.sessionPreset = AVCaptureSessionPresetHigh
      
      previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
      previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
      previewLayer.masksToBounds = false
      displayView.layer.insertSublayer(previewLayer, at: 0)
      
      videoPlayer = AVPlayer()
      videoPlayer.actionAtItemEnd = .pause
      setupVideoEndObserver()
      
      playerLayer = AVPlayerLayer(player: videoPlayer)
      playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
      playerLayer.masksToBounds = false
      capturedVideoPlayView.layer.addSublayer(playerLayer)
      
      stillImageOutput = AVCaptureStillImageOutput()
      stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG, AVVideoQualityKey: NSNumber(value: 0.95)]
      if captureSession.canAddOutput(stillImageOutput) {
         captureSession.addOutput(stillImageOutput)
      }
      
      videoFileOutput = AVCaptureMovieFileOutput()
      videoFileOutput.movieFragmentInterval = kCMTimeInvalid
      if captureSession.canAddOutput(videoFileOutput) {
         captureSession.addOutput(videoFileOutput)
      }
      
      captureSession.commitConfiguration()
      sessionLock.unlock()
   }
   
   private func updateFlash()
   {
      var camera : AVCaptureDevice
      var otherCamera : AVCaptureDevice
      if useFrontCamera {
         camera = frontCamera
         otherCamera = backCamera
      }
      else {
         camera = backCamera
         otherCamera = frontCamera
      }
      
      do {
         try camera.lockForConfiguration()
         try otherCamera.lockForConfiguration()
      }
      catch let error {
         dlog(error.localizedDescription)
         return
      }
      
      if otherCamera.hasFlash { otherCamera.flashMode = .off }
      if otherCamera.hasTorch { otherCamera.torchMode = .off }
      otherCamera.unlockForConfiguration()
      
      let useLight = useFlash && !isMediaTaken
      var lightActive : Bool = false
      
      switch mediaType
      {
      case .photo, .photoInDynamics:
         if camera.hasTorch { camera.torchMode = .off }
         if useLight && camera.hasFlash && camera.isFlashAvailable {
            camera.flashMode = .on
            lightActive = true
         }
         else {
            if camera.hasFlash { camera.flashMode = .off }
            lightActive = false
         }
         
      case .video:
         if camera.hasFlash { camera.flashMode = .off }
         if useLight && camera.hasTorch && camera.isTorchAvailable
         {
            do {
               try camera.setTorchModeOnWithLevel(AVCaptureMaxAvailableTorchLevel)
               lightActive = true
            }
            catch let error {
               camera.unlockForConfiguration()
               AlertManager.showAlert(loc(error.localizedDescription))
               return
            }
         }
         else
         {
            if camera.hasTorch { camera.torchMode = .off }
            lightActive = false
         }
      }
      
      camera.unlockForConfiguration()      
      flashButton.imageView?.tintColor = lightActive ? pinkColor : grayColor
   }
   
   private var usedCamera : AVCaptureDevice? = nil
   private var usedCameraInput : AVCaptureDeviceInput? = nil
   private func setCameraPreview(_ camera : AVCaptureDevice!, addMicrophone : Bool = false)
   {
      if camera == nil
      {
         UserInitiatedQueue.async
         {
            self.captureSession.stopRunning()
            MainQueue.async {
               self.previewLayer.isHidden = true
            }
         }
         return
      }
      
      checkCameraAccess
      {
         granted in
         guard granted else { return }
         
         UserInitiatedQueue.async
         {
            var needAddMicrophone = addMicrophone
            
            if let lastCamera = self.usedCamera, let lastCameraInput = self.usedCameraInput
            {
               if lastCamera != camera
               {
                  self.sessionLock.lock()
                  self.captureSession.beginConfiguration()
                  
                  self.captureSession.removeInput(lastCameraInput)
                  self.usedCamera = nil
                  self.usedCameraInput = nil
                  
                  self.addCameraInput(camera)
                  if needAddMicrophone {
                     self.addMicrophoneInput()
                     needAddMicrophone = false
                  }
                  
                  self.captureSession.commitConfiguration()
                  self.sessionLock.unlock()
               }
            }
            else
            {
               self.sessionLock.lock()
               self.captureSession.beginConfiguration()
               self.addCameraInput(camera)
               if needAddMicrophone {
                  self.addMicrophoneInput()
                  needAddMicrophone = false
               }
               self.captureSession.commitConfiguration()
               self.sessionLock.unlock()
            }
            
            if needAddMicrophone
            {
               self.sessionLock.lock()
               self.captureSession.beginConfiguration()
               self.addMicrophoneInput()
               self.captureSession.commitConfiguration()
               self.sessionLock.unlock()
            }
            
            self.sessionLock.lock()
            self.captureSession.startRunning()
            self.sessionLock.unlock()
            
            MainQueue.async {
               self.previewLayer.isHidden = false
            }
         }
      }
   }
   
   private func addCameraInput(_ camera : AVCaptureDevice) -> Void
   {
      var error: NSError?
      var input: AVCaptureDeviceInput!
      do {
         input = try AVCaptureDeviceInput(device: camera)
      } catch let error1 as NSError {
         error = error1
         input = nil
      }
      guard error == nil else {
         dlog(error!.localizedDescription)
         return
      }
      
      guard captureSession.canAddInput(input) else {
         dlog("Error Add Video Input")
         return
      }
      
      captureSession.addInput(input)
      usedCamera = camera
      usedCameraInput = input
      previewLayer.connection?.videoOrientation = .portrait
   }
   
   private func addMicrophone()
   {
      checkMicrophoneAccess
      {
         granted in
         guard granted else { return }
         
         UserInitiatedQueue.async
         {
            self.sessionLock.lock()
            self.captureSession.beginConfiguration()
            self.addMicrophoneInput()
            self.captureSession.commitConfiguration()
            self.sessionLock.unlock()
         }
      }
   }
   
   private var microphoneInputAdded = false
   private func addMicrophoneInput()
   {
      var error: NSError?
      var input: AVCaptureDeviceInput!
      
      do {
         input = try AVCaptureDeviceInput(device: self.microphone)
      } catch let error1 as NSError {
         error = error1
         input = nil
      }
      guard error == nil else {
         dlog(error!.localizedDescription)
         return
      }
      
      guard self.captureSession.canAddInput(input) else {
         dlog("Error Add Audio Input")
         return
      }
      
      self.captureSession.addInput(input)
      self.microphoneInputAdded = true
   }
   
   private func startVideoAnimation(_ videoFileUrl : URL)
   {
      let playerItem = AVPlayerItem(url: videoFileUrl)
      videoPlayer.replaceCurrentItem(with: playerItem)
      startVideoAnimation()
   }
   
   private func startVideoAnimation()
   {
      capturedVideoPlayView.alpha = 0
      
      let videoAnimationBlock =
      {
         UIView.animateIgnoringInherited(withDuration: 1, animations: {
            self.capturedVideoPlayView.alpha = 1
         },
         completion:
         {
            animationFinished in
            guard animationFinished else { return }
            self.videoPlayer.play()
         })
      }
      
      if videoPlayer.status == .readyToPlay
      {
         videoPlayer.seek(to: CMTime(seconds: 0, preferredTimescale: 600), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
         {
            finished in
            guard finished else { return }
            videoAnimationBlock()
         }
      }
      else {
         videoAnimationBlock()
      }
   }
   
   private func stopVideoAnimation()
   {
      capturedVideoPlayView.layer.removeAllAnimations()
      videoPlayer.replaceCurrentItem(with: nil)
   }
   
   private func takePhoto()
   {
      let type = mediaType
      var mediaData = medias[type]!
      
      guard let videoConnection = stillImageOutput.connection(withMediaType: AVMediaTypeVideo) else { return }
      
      videoConnection.videoOrientation = .portrait
      let imageOrientation : UIImageOrientation
      switch (useFrontCamera, orientation)
      {
      case (false, .portrait): imageOrientation = .right
      case (false, .landscapeLeft): imageOrientation = .up
      case (false, .landscapeRight): imageOrientation = .down
      case (true, .portrait): imageOrientation = .leftMirrored
      case (true, .landscapeLeft): imageOrientation = .downMirrored
      case (true, .landscapeRight): imageOrientation = .upMirrored
      }
      
      view.isUserInteractionEnabled = false
      
      stillImageOutput.captureStillImageAsynchronously(from: videoConnection, completionHandler:
      {
         (sampleBuffer, error) in
         
         MainQueue.async {
            UIView.animateIgnoringInherited(withDuration: 0.5, animations: {
               self.displayContainerView.layer.borderWidth = 0
            }, completion: nil)
         }
         
         if sampleBuffer != nil,
            let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer),
            let dataProvider = CGDataProvider(data: imageData as CFData),
            let cgImageRef = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
         {
            let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: imageOrientation)
            
            mediaData.taken = .photo(image: image)
            MainQueue.async {
               self.medias[type] = mediaData
               self.updateUI(false)
            }
         }
         else {
            dlog("captureStillImage error " + (error?.localizedDescription ?? ""))
            self.view.isUserInteractionEnabled = true
         }
      })
   }
   
   private func takeVideo()
   {
      let fileName = NSUUID().uuidString + ".mov"
      let fileURL = URL(fileURLWithPath: tempDirectory).appendingPathComponent(fileName, isDirectory: false)
      
      maxVideoDuration = Double(selectedVideoDuration.rawValue)
      videoFileOutput.maxRecordedDuration = CMTime(seconds: maxVideoDuration, preferredTimescale: 600)
      updateCaptureVideoOrientation()
      
      videoFileOutput.startRecording(toOutputFileURL: fileURL, recordingDelegate: self)
   }
   
   private func updateCaptureVideoOrientation()
   {
      guard !self.videoFileOutput.isRecording, let videoConnection = self.videoFileOutput.connection(withMediaType: AVMediaTypeVideo) else { return }
      
      switch self.orientation
      {
      case .portrait: videoConnection.videoOrientation = .portrait
      case .landscapeLeft: videoConnection.videoOrientation = .landscapeRight
      case .landscapeRight: videoConnection.videoOrientation = .landscapeLeft
      }
      videoConnection.isVideoMirrored = useFrontCamera
   }
   
   func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!)
   {
      videoStartRecord = Date()
      createDisplayLink()
   }
   
   func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!)
   {
      if let dLink = displayLink {
         dLink.invalidate()
         countLabel.isHidden = true
      }
      
      centerBottomButton.isUserInteractionEnabled = true
      
      if error != nil
      {
         let nsError = error as NSError
         if !(nsError.domain == AVFoundationErrorDomain && nsError.code == -11810) // max time stop
         {
            AlertManager.showAlert(loc(error.localizedDescription))
            return
         }
      }

      dlog(outputFileURL.absoluteString)
      
      let type = mediaType
      var mediaData = medias[type]!
      
      mediaData.taken = .video(tempFileUrl: outputFileURL)
      performOnMainThread
      {
         self.medias[type] = mediaData
         self.updateUI(false)
         
         if let task = self.videoStopTask {
            Application.endBackgroundTask(task)
            self.videoStopTask = nil
         }
      }
   }
   
   func sizeAndConvertVideo(_ videoUrl : URL, forType type : BabyMediaType, completion : @escaping (URL?, String?) -> Void)
   {
      let mixComposition = AVMutableComposition()
      let compositionInstruction = AVMutableVideoCompositionInstruction()
      
      let asset = AVURLAsset(url: videoUrl)
      let assetVideoTracks = asset.tracks(withMediaType: AVMediaTypeVideo)
      let assetAudioTracks = asset.tracks(withMediaType: AVMediaTypeAudio)
      
      guard !assetVideoTracks.isEmpty else {
         completion(nil, "Video creation failed")
         return
      }
      
      let timeRange = CMTimeRange(start: kCMTimeZero, duration: asset.duration)
      let timeRangeValue = NSValue(timeRange: timeRange)
      
      let videoTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
      let videoTimeRanges = Array<NSValue>(repeating: timeRangeValue, count: assetVideoTracks.count)
      
      do {
         try videoTrack.insertTimeRanges(videoTimeRanges, of: assetVideoTracks, at: kCMTimeZero)
      }
      catch let error
      {
         dlog(error)
         completion(nil, "Video creation failed")
         return
      }
      
      let videoSize = mediaSize(forType: .video)
      
      let instruction = VideoMaker.videoCompositionInstruction(track: videoTrack, asset: asset, contentMode : .scaleAspectFill, videoSize: videoSize)
      instruction.setOpacity(1, at: kCMTimeZero)
      compositionInstruction.layerInstructions.append(instruction)
      
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
      
      compositionInstruction.timeRange = timeRange
      compositionInstruction.backgroundColor = UIColor.black.cgColor
      
      let videoComposition = AVMutableVideoComposition()
      videoComposition.instructions = [compositionInstruction]
      videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
      videoComposition.renderSize = videoSize
      
      let sessionPreset = (type == .photoInDynamics) ? AVAssetExportPreset640x480 : AVAssetExportPreset1280x720
      guard let exportSession = AVAssetExportSession(asset: mixComposition, presetName: sessionPreset) else {
         completion(nil, "Video creation failed")
         return
      }
      
      let fileName = NSUUID().uuidString + ".mp4"
      let fileURL = URL(fileURLWithPath: tempDirectory).appendingPathComponent(fileName, isDirectory: false)
      
      exportSession.videoComposition = videoComposition
      exportSession.outputURL = fileURL
      exportSession.outputFileType = AVFileTypeMPEG4
      
      exportSession.exportAsynchronously
      {
         switch exportSession.status
         {
         case .completed : MainQueue.async { completion(fileURL, nil) }
         case .failed :
            MainQueue.async {
               completion(nil, loc("Video creation failed" + ": ") + (exportSession.error?.localizedDescription ?? loc("Error")))
            }
         case .cancelled : MainQueue.async { completion(nil, loc("Video creation canceled")) }
         default : break
         }
      }
   }
   
   //MARK: - Actions
   
   @IBAction func cancelTap()
   {
      guard !videoFileOutput.isRecording else { return }
      presentingViewController?.dismiss(animated: true, completion: nil)
   }
   
   @IBAction func changeTemplateTap()
   {
      guard !videoFileOutput.isRecording else { return }
      templateMirrored = !templateMirrored
      media.mirrored = templateMirrored
      updateTemplateSide()
   }
   
   @IBAction func flashTap()
   {
      useFlash = !useFlash
      updateFlash()
   }
   
   @objc func retakeTap()
   {
      guard !videoFileOutput.isRecording else { return }
      removeCurrentMedia()
   }

   @objc func editInfoTap()
   {
      guard !videoFileOutput.isRecording else { return }
      goToMediaInfo()
   }
   
   @objc func confirmTap()
   {
      guard !videoFileOutput.isRecording else { return }
      saveAndDismiss()
   }
   
   @objc func pickFromGalleryTap()
   {
      guard !videoFileOutput.isRecording else { return }
      checkGalleryAccess
      {
         granted in
         if granted { self.pickFromGallery() }
      }
   }
   
   @objc func cameraTap()
   {
      switch mediaType
      {
      case .photo, .photoInDynamics:
      //   guard checkIfCanTakeMedia() else { return }
         displayContainerView.borderColor = UIColor.white
         displayContainerView.layer.borderWidth = 0
         UIView.animateIgnoringInherited(withDuration: 0.5, animations: {
            self.displayContainerView.layer.borderWidth = 3
         })
         takePhoto()
      
      case .video:
         if videoFileOutput.isRecording {
            centerBottomButton.isUserInteractionEnabled = false
            videoFileOutput.stopRecording()
         }
         else {
       //     guard checkIfCanTakeMedia() else { return }
            takeVideo()
         }
      }
   }
   
   @objc func changeCameraTap()
   {
      guard !videoFileOutput.isRecording else { return }
      if !isMediaTaken
      {
         useFrontCamera = !useFrontCamera
         setCameraPreview(currentCamera)
      }
   }
   
   @IBAction func secondsButtonTap(_ sender: HighlightedColorButton)
   {
      guard !videoFileOutput.isRecording else { return }
      selectedVideoDuration = (sender === seconds2Button ? .sec2 : .sec3)
      updateVideoDurationButtons()
   }
}
