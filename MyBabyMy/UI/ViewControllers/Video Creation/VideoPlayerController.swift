//
//  VideoPlayerController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 3/10/17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class VideoPlayerController: UIViewController
{
   @IBOutlet weak var playPauseButton: UIButton!
   
   @IBOutlet weak var timeLabel: UILabel!
   @IBOutlet weak var timeLabelWidth: NSLayoutConstraint!
   
   @IBOutlet weak var timeSlider: UISlider!
   @IBOutlet var sliderToRightButtonConstraint: NSLayoutConstraint!
   
   @IBOutlet weak var linkButton: UIButton!
   
   
   public var videoURL : URL!
   public var deleteVideoOnExit = true
   public var videoContainsLogoLink = false
   
   private var playerItem : AVPlayerItem!
   private var videoPlayer : AVPlayer!
   private var playerLayer : AVPlayerLayer!
   private var displayLink : CADisplayLink?
   
   private var pausedByUser = true
   private var totalDuration : TimeInterval = 0
   
   private let timeFormatter : DateComponentsFormatter =
   {
      let formatter = DateComponentsFormatter()
      formatter.calendar = calendar
      formatter.unitsStyle = .positional
      formatter.zeroFormattingBehavior = .pad
      return formatter
   }()
   
   private enum PlayerState
   {
      case playing
      case paused
   }
   
   private var playerState : PlayerState = .paused
   {
      didSet
      {
         playPauseButton.removeTarget(nil, action: nil, for: .allEvents)
         switch playerState
         {
         case .playing:
            playPauseButton.addTarget(self, action: #selector(pauseTap), for: .touchUpInside)
            playPauseButton.setImage(#imageLiteral(resourceName: "pauseButton"), for: .normal)
         case .paused:
            playPauseButton.addTarget(self, action: #selector(playTap), for: .touchUpInside)
            playPauseButton.setImage(#imageLiteral(resourceName: "playButton"), for: .normal)
         }
      }
   }
   
   override func viewDidLoad()
   {
      super.viewDidLoad()
      
      playPauseButton.addTarget(self, action: #selector(playTap), for: .touchUpInside)
      
      playerItem = AVPlayerItem(url: videoURL!)
      videoPlayer = AVPlayer(playerItem: playerItem)
      videoPlayer.actionAtItemEnd = .pause
      
      playerLayer = AVPlayerLayer(player: videoPlayer)
      playerLayer.frame = view.bounds
      playerLayer.backgroundColor = UIColor.black.cgColor
      view.layer.insertSublayer(playerLayer, at: 0)
      
      totalDuration = playerItem.asset.duration.seconds
      timeSlider.maximumValue = Float(totalDuration)
      
      if totalDuration < 3600 {
         timeFormatter.allowedUnits = [.minute, .second]
      }
      else {
         timeFormatter.allowedUnits = [.hour, .minute, .second]
      }
      
      let timeString = getTimeString(totalDuration)
      let widestTimeString = String(repeating: "9", count: timeString.characters.count)
      timeLabelWidth.constant = ceil(textSize(widestTimeString, font: timeLabel.font).width)
      timeLabel.text = getTimeString(0)
      
      try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
      setupObservers()
      
      let sliderTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(sliderTap(sender:)))
      timeSlider.addGestureRecognizer(sliderTapRecognizer)
      
      linkButton.isHidden = !videoContainsLogoLink
//      linkButton.borderWidth = 2
//      linkButton.borderColor = UIColor.red
      
      playerLayer.addObserver(self, forKeyPath: "videoRect", context: nil)
      
      createDisplayLink()
   }
   
   override func viewWillAppear(_ animated: Bool)
   {
      super.viewWillAppear(animated)
      
      AppDelegate.allowLandscapeOrientation = true
      
      if let navigationBar = navigationController?.navigationBar
      {
         navigationBar.isTranslucent = true
         navigationBar.shadowImage = UIImage()
         navigationBar.setBackgroundImage(UIImage.pixelImage(rgba(46, 48, 55, 0.5)), for: UIBarMetrics.default)
         navigationBar.tintColor = UIColor.white
         navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white, NSFontAttributeName : UIFont.systemFont(ofSize: 12, weight: UIFontWeightMedium)]
      }
   }
   
   override func viewWillLayoutSubviews()
   {
      super.viewWillLayoutSubviews()
      if Application.statusBarOrientation.isPortrait
      {
         playerLayer.videoGravity = AVLayerVideoGravityResizeAspect
         sliderToRightButtonConstraint.isActive = true
         timeLabel.isHidden = true
      }
      else
      {
         playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
         sliderToRightButtonConstraint.isActive = false
         timeLabel.isHidden = false
      }
   }
   
   override func viewDidLayoutSubviews()
   {
      super.viewDidLayoutSubviews()
      playerLayer.frame = view.bounds
   }
   
   override var prefersStatusBarHidden: Bool {
      return false
   }
   
   // MARK: - Methods
   
   override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
   {
      let videoRect = playerLayer.videoRect
      let linkButtonWidth = videoRect.width * 0.35
      let linkButtonSize = CGSize(width: linkButtonWidth, height: linkButtonWidth / 1.5)
      
      linkButton.frame = CGRect(origin: videoRect.origin, size: linkButtonSize)
      linkButton.isHidden = !videoContainsLogoLink || (Application.statusBarOrientation.isLandscape && (VideoMaker.mediaType == .photoInDynamics || VideoMaker.selectedVideoSize == .size1280x1280))
   }
   
   func createDisplayLink()
   {
      if let dLink = displayLink {
         dLink.invalidate()
      }
      displayLink = CADisplayLink(target: self, selector: #selector(updateScreen(sender:)))
      displayLink?.add(to: RunLoop.main, forMode: .commonModes)
   }
   
   @objc func updateScreen(sender: CADisplayLink)
   {
      let seconds = videoPlayer.currentTime().seconds
      
      if !timeSlider.isTracking
      {
         timeSlider.value = Float(seconds)
         
         if videoPlayer.rate == 0 && !pausedByUser && abs(totalDuration - seconds) > 0.01 {
            videoPlayer.play()
         }
      }
      
      if !timeLabel.isHidden {
         timeLabel.text = getTimeString(seconds)
      }
      
      switch playerState
      {
         case .paused: if videoPlayer.rate != 0 {
            playerState = .playing
         }
         case .playing: if videoPlayer.rate == 0 {
            playerState = .paused
         }
      }
   }
   
   func getTimeString(_ seconds: TimeInterval) -> String
   {
      return timeFormatter.string(from: seconds)?.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: ".", with: "") ?? ""
   }
   
   //MARK: - Observers
   
   private var applicationResignObserver : NSObjectProtocol?
   private var applicationBecomeActiveObserver : NSObjectProtocol?
   private var audioInterruptionObserver : NSObjectProtocol?
   private var audioRouteChangeObserver : NSObjectProtocol?
   
   private func setupObservers()
   {
      applicationResignObserver = NotificationCenter.default.addObserver(forName: .UIApplicationWillResignActive, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         self.videoPlayer.pause()
         self.playerState = .paused
         self.pausedByUser = true
      }
      
      applicationBecomeActiveObserver = NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         if !self.pausedByUser
         {
            self.videoPlayer.play()
            self.playerState = .playing
         }
      }
   
      audioInterruptionObserver = NotificationCenter.default.addObserver(forName: .AVAudioSessionInterruption, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         
         guard let interruptionType : NSNumber = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber else { return }
         switch interruptionType.uintValue
         {
         case AVAudioSessionInterruptionType.began.rawValue:
            self.videoPlayer.pause()
            self.playerState = .paused
            
         case AVAudioSessionInterruptionType.ended.rawValue:
            if let interruptionOption : NSNumber = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? NSNumber,
               interruptionOption.uintValue == AVAudioSessionInterruptionOptions.shouldResume.rawValue
            {
               if !self.pausedByUser
               {
                  self.videoPlayer.play()
                  self.playerState = .playing
               }
            }
            
         default: break
         }
      }
      
      audioRouteChangeObserver = NotificationCenter.default.addObserver(forName: .AVAudioSessionRouteChange, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         
         guard let changeReason : NSNumber = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber else { return }
         if changeReason.uintValue == AVAudioSessionRouteChangeReason.oldDeviceUnavailable.rawValue
         {
            self.videoPlayer.pause()
            self.playerState = .paused
            self.pausedByUser = true
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
      if audioInterruptionObserver != nil {
         NotificationCenter.default.removeObserver(audioInterruptionObserver!)
      }
      if audioRouteChangeObserver != nil {
         NotificationCenter.default.removeObserver(audioRouteChangeObserver!)
      }
      
      videoPlayer.replaceCurrentItem(with: nil)
      
      try? AVAudioSession.sharedInstance().setActive(false)
   }
   
   // MARK: - Actions
   
   @IBAction func closeVideoPlayer()
   {
      playerLayer.removeObserver(self, forKeyPath: "videoRect")
      
      if let dLink = displayLink {
         dLink.invalidate()
      }
      
      AppDelegate.allowLandscapeOrientation = false
      UIDevice.current.setValue(UIDeviceOrientation.portrait.rawValue, forKey: "orientation")
      
      if let navController = navigationController {
         _  = navController.popViewController(animated: true)
      }
      else {
         presentingViewController?.dismiss(animated: true, completion: nil)
      }
      
      if deleteVideoOnExit
      {
         let url = videoURL!
         delay(0.5, queue: BackgroundQueue) {
            try? FileManager.default.removeItem(at: url)
         }
      }
   }
   
   @IBAction func saveVideo(_ sender: UIBarButtonItem)
   {
      checkGalleryAccess
      {
         granted in
         guard granted else { return }
         
         showAppSpinner()
         PHPhotoLibrary.shared().performChanges(
         {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.videoURL)
         })
         {
            saved, error in
            performOnMainThread
            {
               hideAppSpinner()
               if saved
               {
                  sender.isEnabled = false
                  CATransaction.begin()
                  CATransaction.setDisableActions(true)
                  sender.title = loc("Saved")
                  CATransaction.commit()
                  AlertManager.showAlert(loc("Video saved to gallery"))
               }
               else
               {
                  if let errorDescription = error?.localizedDescription, !errorDescription.isEmpty {
                     AlertManager.showAlert(title: loc("Failed to save video to gallery"), message: errorDescription)
                  }
                  else {
                     AlertManager.showAlert(loc("Failed to save video to gallery"))
                  }
               }
            }
         }
      }
   }
   
   @objc func playTap()
   {
      let play =
      {
         self.videoPlayer.play()
         self.playerState = .playing
         self.pausedByUser = false
      }
      
      if playerState == .paused, abs(totalDuration - videoPlayer.currentTime().seconds) < 0.01
      {
         videoPlayer.seek(to: kCMTimeZero, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler:
         {
            finished in
            if finished && !self.pausedByUser {
               play()
            }            
         })
      }
      else
      {
         play()
      }
   }
   
   @objc func pauseTap()
   {
      videoPlayer.pause()
      playerState = .paused
      pausedByUser = true
   }
   
   @IBAction func shareTap()
   {
      let activityViewController = UIActivityViewController(activityItems: [videoURL!], applicationActivities: nil)
      activityViewController.popoverPresentationController?.sourceView = view // so that iPads won't crash
      activityViewController.excludedActivityTypes = [.airDrop]
      
      present(activityViewController, animated: true, completion: nil)
   }
   
   @objc func sliderTap(sender: UITapGestureRecognizer)
   {
      if sender.state == .ended && !timeSlider.isTracking
      {
         let pointTapped: CGPoint = sender.location(in: timeSlider)
         let newValue = totalDuration * Double(pointTapped.x / timeSlider.bounds.size.width)
         
         timeSlider.setValue(Float(newValue), animated: false)
         
         let time = CMTime(seconds: newValue, preferredTimescale: 600)
         videoPlayer.seek(to: time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler:
         {
            finished in
            if finished && !self.pausedByUser {
               self.videoPlayer.play()
            }
         })
      }
   }
   
   @IBAction func timeSliderValueChanged()
   {
      let time = CMTime(seconds: Double(timeSlider.value), preferredTimescale: 600)
      
      //print("from \(videoPlayer.currentTime().seconds) to \(time.seconds), \(timeSlider.isTracking ? "isTracking" : "notTracking"), rate \(videoPlayer.rate)")
      
      if timeSlider.isTracking
      {
         if videoPlayer.rate != 0 {
            videoPlayer.pause()
         }
         videoPlayer.seek(to: time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
      }
      else
      {
         videoPlayer.seek(to: time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler:
         {
            finished in
            if finished && !self.pausedByUser {
               self.videoPlayer.play()
            }
         })
      }
   }
   
   @IBAction func linkButtonTap()
   {
      let url = URL(string: "http://mybabymy.com")!
      Application.openURL(url)
   }
}
