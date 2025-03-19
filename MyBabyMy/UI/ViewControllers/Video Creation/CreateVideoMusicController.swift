//
//  CreateVideoMusicController.swift
//  MyBabyMy
//
//  Created by Dmitry on 23.01.17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import UIKit
import RealmSwift
import MediaPlayer
import AVFoundation
import Alamofire

let musicThumbnailSize = CGSize.square(ceil(66 * WidthRatio))

enum VideoMusic
{
   case none
   case mpMedia(musicItem : MPMediaItem)
   case mbMusic(music : MBMusic)
   
   var isMusic : Bool
   {
      switch self
      {
      case .none: return false
      case .mpMedia: return true
      case .mbMusic(let music): return !music.isInvalidated
      }
   }
}

class CreateVideoMusicController: UIViewController, UITableViewDataSource, UITableViewDelegate, MPMediaPickerControllerDelegate
{
   @IBOutlet weak var tableView: UITableView!
   @IBOutlet weak var playerView: UIView!
   @IBOutlet weak var playerSongLabel: UILabel!
   @IBOutlet weak var playerToolbar: UIToolbar!
   @IBOutlet weak var playerSlider: UISlider!
   @IBOutlet var playerViewHideConstraint: NSLayoutConstraint!
   
   let playButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .play, target: self, action: #selector(playTap(_:)))
   let pauseButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .pause, target: self, action: #selector(pauseTap(_:)))
   
   var musicList : Results<MBMusic>!
   var musicListUpdateToken : NotificationToken?
   
   var audioPlayer : AVAudioPlayer?
   var audioPlayerUserPaused = false
   
   private var displayLink : CADisplayLink?
   
   override func viewDidLoad()
   {
      super.viewDidLoad()
      
      musicList = Realm.main.objects(MBMusic.self).sorted(byKeyPath: "id")
      musicListUpdateToken = musicList.addNotificationBlock
      {
         [unowned self]
         (changes: RealmCollectionChange<Results<MBMusic>>) in
         switch changes
         {
         case .initial: self.tableView.reloadData()
            
         case .update(_, let deletions, let insertions, let modifications):
            if case .mbMusic(let music) = VideoMaker.selectedMusic, music.isInvalidated {
               VideoMaker.selectedMusic = .none
            }
            
            self.tableView.beginUpdates()
            self.tableView.insertRows(at: insertions.map({ IndexPath(row: $0 + 2, section: 0) }), with: .none)
            self.tableView.deleteRows(at: deletions.map({ IndexPath(row: $0 + 2, section: 0)}), with: .none)
            self.tableView.reloadRows(at: modifications.map({ IndexPath(row: $0 + 2, section: 0) }), with: .none)
            self.tableView.endUpdates()
            
         case .error(let error): dlog(error.localizedDescription)
         }
      }
      
      tableView.rowHeight = 96 * WidthRatio
      
      setupForAudio()
      
      playerToolbar.clipsToBounds = true
      playerToolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
      
      let sliderTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(playerSliderTap(sender:)))
      playerSlider.addGestureRecognizer(sliderTapRecognizer)
      
      AppDelegate.updateMusic()
   }
   
   // MARK: - Song loading
   
   private var loadingSong : (musicId : Int, request : DownloadRequest)? = nil
   
   @discardableResult
   private func loadSong(_ music : MBMusic) -> Bool
   {
      guard !music.isInvalidated else { return false }
      
      if let loading = loadingSong
      {
         guard loading.musicId != music.id else { return true }
         loading.request.cancel()
      }
      
      if let request = loadSongRequest(music)
      {
         loadingSong = (music.id, request)
         updateLoadingIndicators()
         return true
      }
      else {
         updateLoadingIndicators()
         return false
      }
   }
   
   private func loadSongRequest(_ music : MBMusic) -> DownloadRequest?
   {
      let link = music.songLink
      let musicId = music.id
      guard !link.isEmpty else { return nil }
      
      let finishRequest =
      {
         [weak self] in
         guard let strongSelf = self else { return }
         if let loading = strongSelf.loadingSong, loading.musicId == musicId
         {
            strongSelf.loadingSong = nil
            if strongSelf.audioUrl == nil, !music.isInvalidated, music.checkSongFile(),
               case .mbMusic(let selectedMusic) = VideoMaker.selectedMusic, !selectedMusic.isInvalidated, selectedMusic.id == musicId
            {
               strongSelf.startAudioPlayer(title: music.title, url: music.songUrl, fileTypeHint: music.songFileType)
            }
         }
         strongSelf.updateLoadingIndicators()
      }
      
      return RequestManager.downloadData(link, to: music.songFileURL,
      progress:
      {
         [weak self]
         progress in
         guard let strongSelf = self else { return }
         strongSelf.updateLoadingIndicators()
         
//         guard let index = strongSelf.musicList.index(where: { !$0.isInvalidated && $0.id == music.id}) else { return }
//         let indexPath = IndexPath(row: index + 2, section: 0)
//         if let cell = strongSelf.tableView.cellForRow(at: indexPath) as? CreateVideoMusicCell
//         {
//            cell.loadedIcon.isHidden = true
//            cell.loadingProgressView.isHidden = false
//            cell.loadingProgressView.progress = Float(progress.fractionCompleted)
//         }
      },
      success:
      {
         guard !music.isInvalidated, music.songLink == link else { finishRequest(); return }
         dlog("saved song for music ", music.id)
         music.modifyWithTransactionIfNeeded {
            music.songLoaded = true
         }
         finishRequest()
      },
      failure:
      {
         errorDescription in
         dlog(errorDescription)
         finishRequest()
      })
   }
   
   func updateLoadingIndicators()
   {
      for cell in tableView.visibleCells
      {
         guard let musicCell = cell as? CreateVideoMusicCell else { continue }
         guard let music = musicCell.music, !music.isInvalidated else { continue }
         
         if let loading = loadingSong, loading.musicId == music.id
         {
            musicCell.loadedIcon.isHidden = true
            musicCell.loadingProgressView.isHidden = false
            musicCell.loadingProgressView.progress = Float(loading.request.progress.fractionCompleted)
         }
         else
         {
            musicCell.loadedIcon.isHidden = !music.songLoaded
            musicCell.loadingProgressView.isHidden = true
         }
      }
   }
   
   // MARK: - Selection
   
   func selectMusicItem(_ musicItem : MPMediaItem?)
   {
      guard let musicItem = musicItem else { deselectAllMusic(); return }
      
      deselectMBMusic()
      deselectNoMusicCell()
      
      if let cell = tableView.cellForRow(at: IndexPath(row: 1, section: 0)) as? CreateVideoMusicLibraryCell
      {
         if let artwork = musicItem.artwork, let image = artwork.image(at: musicThumbnailSize) {
            cell.musicImageView.image = image
         }
         else {
            cell.musicImageView.image = #imageLiteral(resourceName: "iTunesLogo")
         }
         cell.nameLabel.text = musicItem.title
         cell.checkImageView.isHidden = false
         cell.disclosure.isHidden = true
      }
      
      VideoMaker.selectedMusic = .mpMedia(musicItem: musicItem)
   }
   
   func selectMusic(_ music : MBMusic)
   {
      guard !music.isInvalidated else { deselectAllMusic(); return }
      
      deselectMusicItem()
      deselectNoMusicCell()
      
      if case .mbMusic(let selectedMusic) = VideoMaker.selectedMusic, !selectedMusic.isInvalidated
      {
         if selectedMusic.id == music.id {
            return
         }
         else {
            deselectMBMusic()
         }
      }
      
      if let index = musicList.index(where: { !$0.isInvalidated && $0.id == music.id}),
         let cell = tableView.cellForRow(at: IndexPath(row: index + 2, section: 0)) as? CreateVideoMusicCell
      {
         cell.checkImageView.image = #imageLiteral(resourceName: "radioButtonChecked")
      }
      
      VideoMaker.selectedMusic = .mbMusic(music: music)
   }
   
   func deselectAllMusic()
   {
      deselectMBMusic()
      deselectMusicItem()
      selectNoMusicCell()
      VideoMaker.selectedMusic = .none
   }
   
   func deselectNoMusicCell()
   {
      if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? CreateVideoMusicCell {
         cell.checkImageView.image = #imageLiteral(resourceName: "radioButtonEmpty")
      }
   }
   
   func selectNoMusicCell()
   {
      if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? CreateVideoMusicCell {
         cell.checkImageView.image = #imageLiteral(resourceName: "radioButtonChecked")
      }
   }
   
   func deselectMusicItem()
   {
      if case .mpMedia = VideoMaker.selectedMusic, let cell = tableView.cellForRow(at: IndexPath(row: 1, section: 0)) as? CreateVideoMusicLibraryCell
      {
         cell.musicImageView.image = #imageLiteral(resourceName: "musicBrowse")
         cell.nameLabel.text = loc("BROWSE MUSIC")
         cell.checkImageView.isHidden = true
         cell.disclosure.isHidden = false
      }
   }
   
   func deselectMBMusic()
   {
      if case .mbMusic(let music) = VideoMaker.selectedMusic, !music.isInvalidated, let index = musicList.index(where: { !$0.isInvalidated && $0.id == music.id}),
         let cell = tableView.cellForRow(at: IndexPath(row: index + 2, section: 0)) as? CreateVideoMusicCell
      {
         cell.checkImageView.image = #imageLiteral(resourceName: "radioButtonEmpty")
      }
   }
   
   // MARK: - Audio
   
   private var audioUrl : URL?
   func startAudioPlayer(title : String?, url: URL, fileTypeHint : String? = nil)
   {
      audioPlayerUserPaused = false
      guard url != audioUrl else { return }
      
      if let player = audioPlayer {
         player.stop()
      }
      audioPlayer = nil
      audioUrl = nil
      playerSongLabel.text = " "
      
      try? audioPlayer = AVAudioPlayer(contentsOf: url, fileTypeHint: fileTypeHint)
      if audioPlayer != nil {
         playerSongLabel.text = title ?? " "
      }
      updatePlayerUI()
      guard let player = audioPlayer else { return }
      
      player.numberOfLoops = -1
      audioUrl = url
      try? AVAudioSession.sharedInstance().setActive(true)
      player.play()
   }
   
   func removeAudioPlayer()
   {
      audioPlayerUserPaused = false
      guard let player = audioPlayer else { return }
      player.stop()
      audioPlayer = nil
      audioUrl = nil
      playerSongLabel.text = " "
      updatePlayerUI()
      try? AVAudioSession.sharedInstance().setActive(false)
   }
   
   private var playerShown = false
   func updatePlayerUI()
   {
      let showPlayerView = (audioPlayer != nil)
      if showPlayerView == playerShown { return }
      
      UIView.animateIgnoringInherited(withDuration: 0.3)
      {
         self.playerViewHideConstraint.isActive = !showPlayerView
         self.view.layoutIfNeeded()
         self.tableView.contentInset = showPlayerView ? UIEdgeInsets(top: 0, left: 0, bottom: self.playerView.height, right: 0) : UIEdgeInsets.zero
      }
      
      playerShown = showPlayerView
   }
   
   private var currentButtonIsPlay = true
   func updatePlayButton()
   {
      guard let player = audioPlayer else { return }
      guard player.isPlaying == currentButtonIsPlay else { return }
      
      if var items = playerToolbar.items
      {
         if player.isPlaying
         {
            items[1] = pauseButtonItem
            currentButtonIsPlay = false
         }
         else
         {
            items[1] = playButtonItem
            currentButtonIsPlay = true
         }
         
         playerToolbar.items = items
      }
   }
   
   func createAudioDisplayLink()
   {
      if let dLink = displayLink {
         dLink.invalidate()
      }
      displayLink = CADisplayLink(target: self, selector: #selector(updateAudioBar(sender:)))
      displayLink?.add(to: RunLoop.main, forMode: .commonModes)
   }
   
   @objc func updateAudioBar(sender : CADisplayLink)
   {
      if let player = audioPlayer, !playerSlider.isTracking
      {
         playerSlider.maximumValue = Float(player.duration)
         playerSlider.value = Float(player.currentTime)
      }
      updatePlayButton()
   }
   
   func setupForAudio()
   {
      try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
      setupAudioObservers()
      createAudioDisplayLink()
   }
   
   private var audioInterruptionObserver : NSObjectProtocol?
   private var audioRouteChangeObserver : NSObjectProtocol?
   func setupAudioObservers()
   {
      audioInterruptionObserver = NotificationCenter.default.addObserver(forName: .AVAudioSessionInterruption, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         
         guard let interruptionType : NSNumber = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber else { return }
         switch interruptionType.uintValue
         {
         case AVAudioSessionInterruptionType.began.rawValue:
            if let player = self.audioPlayer {
               player.pause()
            }
            
         case AVAudioSessionInterruptionType.ended.rawValue:
            if let interruptionOption : NSNumber = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? NSNumber,
               interruptionOption.uintValue == AVAudioSessionInterruptionOptions.shouldResume.rawValue,
               let player = self.audioPlayer, !self.audioPlayerUserPaused
            {
               player.play()
            }
            
         default: break
         }
      }
      
      audioRouteChangeObserver = NotificationCenter.default.addObserver(forName: .AVAudioSessionRouteChange, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         
         guard let changeReason : NSNumber = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber else { return }
         if changeReason.uintValue == AVAudioSessionRouteChangeReason.oldDeviceUnavailable.rawValue,
            let player = self.audioPlayer
         {
            player.pause()
            self.audioPlayerUserPaused = true
         }
      }
   }
   
   deinit
   {
      if audioInterruptionObserver != nil {
         NotificationCenter.default.removeObserver(audioInterruptionObserver!)
      }
      if audioRouteChangeObserver != nil {
         NotificationCenter.default.removeObserver(audioRouteChangeObserver!)
      }
      if let dLink = displayLink {
         dLink.invalidate()
      }
      
      if let player = audioPlayer {
         player.stop()
      }
      audioPlayer = nil
      
      try? AVAudioSession.sharedInstance().setActive(false)
      musicListUpdateToken?.stop()
      
      if let loading = loadingSong {
         loading.request.cancel()
      }
   }
   
   // MARK: - Table view

   func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
      return 2 + musicList.count
   }
   
   func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
   {
      let row = indexPath.row
      
      if row == 1
      {
         let cell = tableView.dequeueReusableCell(withIdentifier: "CreateVideoMusicLibraryCell", for: indexPath) as! CreateVideoMusicLibraryCell
         
         if case .mpMedia(let musicItem) = VideoMaker.selectedMusic
         {
            if let artwork = musicItem.artwork, let image = artwork.image(at: musicThumbnailSize) {
               cell.musicImageView.image = image
            }
            else {
               cell.musicImageView.image = #imageLiteral(resourceName: "iTunesLogo")
            }
            cell.nameLabel.text = musicItem.title
            cell.checkImageView.isHidden = false
            cell.disclosure.isHidden = true
         }
         else
         {
            cell.musicImageView.image = #imageLiteral(resourceName: "musicBrowse")
            cell.nameLabel.text = loc("BROWSE MUSIC")
            cell.checkImageView.isHidden = true
            cell.disclosure.isHidden = false
         }
         
         return cell
      }
      else
      {
         let cell = tableView.dequeueReusableCell(withIdentifier: "CreateVideoMusicCell", for: indexPath) as! CreateVideoMusicCell
         
         if row == 0
         {
            cell.music = nil
            cell.loadedIcon.isHidden = true
            cell.loadingProgressView.isHidden = true
            cell.musicImageView.image = #imageLiteral(resourceName: "musicNoSound")
            cell.nameLabel.text = loc("NO SOUND")
            
            let selected = !VideoMaker.selectedMusic.isMusic
            cell.checkImageView.image = (selected ? #imageLiteral(resourceName: "radioButtonChecked") : #imageLiteral(resourceName: "radioButtonEmpty"))
         }
         else
         {
            let music = musicList[row - 2]
            cell.music = music
            guard !music.isInvalidated else { return cell }
            
            cell.musicImageView.image = music.getThumbnail()
            cell.nameLabel.text = music.title
            
            if let loading = loadingSong, loading.musicId == music.id
            {
               cell.loadedIcon.isHidden = true
               cell.loadingProgressView.isHidden = false
               cell.loadingProgressView.progress = Float(loading.request.progress.fractionCompleted)
            }
            else
            {
               cell.loadedIcon.isHidden = !music.songLoaded
               cell.loadingProgressView.isHidden = true
            }
            
            var selected = false
            if case .mbMusic(let selectedMusic) = VideoMaker.selectedMusic, !selectedMusic.isInvalidated {
               selected = (selectedMusic.id == music.id)
            }
            cell.checkImageView.image = (selected ? #imageLiteral(resourceName: "radioButtonChecked") : #imageLiteral(resourceName: "radioButtonEmpty"))
         }
         
         return cell
      }
   }
   
   func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
   {
      tableView.deselectRow(at: indexPath, animated: true)
      
      let row = indexPath.row
      if row == 0
      {
         deselectAllMusic()
         removeAudioPlayer()
      }
      else if row == 1
      {
         if case .mpMedia(let musicItem) = VideoMaker.selectedMusic, let assetURL = musicItem.assetURL
         {
            startAudioPlayer(title: musicItem.title, url: assetURL)
         }
         else
         {
            let soundPicker = MPMediaPickerController(mediaTypes: [.music, .anyAudio])
            soundPicker.delegate = self
            soundPicker.allowsPickingMultipleItems = false
            soundPicker.prompt = loc("Select any song for use in video")
            present(soundPicker, animated: true, completion: nil)
         }
      }
      else
      {
         let music = musicList[row - 2]
         guard !music.isInvalidated else { return }
         
         if case .mbMusic(let selectedMusic) = VideoMaker.selectedMusic, !selectedMusic.isInvalidated, selectedMusic.id == music.id
         {
            if music.checkSongFile() {
               startAudioPlayer(title: music.title, url: music.songUrl, fileTypeHint: music.songFileType)
            }
            else {
               loadSong(music)
            }
         }
         else
         {
            selectMusic(music)
         }
      }
   }
	
   // MARK: - MPMediaPickerControllerDelegate
   
   func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection)
   {
      var errorDescription : String = ""
      if let item = mediaItemCollection.items.first
      {
         if let assetUrl = item.assetURL
         {
            let avItem = AVPlayerItem(url: assetUrl)
            if !avItem.asset.isComposable {
               errorDescription = loc("Selected track can not be used") // probably DRM protection
            }
         }
         else
         {
            if item.isCloudItem {
               errorDescription = loc("Track must be downloaded from iTunes")
            }
            else {
               errorDescription = loc("Selected track is not available")
            }
         }
      }
      else {
         errorDescription = loc("Selected track is not available")
      }
      
      if errorDescription.isEmpty
      {
         selectMusicItem(mediaItemCollection.items.first)
         dismiss(animated: true, completion: nil)
      }
      else {
         AlertManager.showAlert(errorDescription)
      }
   }
   
   func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController)
   {
      dismiss(animated: true, completion: nil)
   }
   
	// MARK: - Actions

   @IBAction func backTap(_ sender: UIBarButtonItem)
   {
      if let dLink = displayLink {
         dLink.invalidate()
      }
      _ = navigationController?.popViewController(animated: true)
   }
   
   @IBAction func playerSliderValueChanged(_ sender: UISlider)
   {
      guard let player = audioPlayer, player.duration > 0 else { return }
      player.currentTime = TimeInterval(sender.value)
   }
   
   @objc func playTap(_ sender: UIBarButtonItem)
   {
      if let player = audioPlayer
      {
         audioPlayerUserPaused = false
         player.play()
      }
   }
   
   @objc func pauseTap(_ sender: UIBarButtonItem)
   {
      if let player = audioPlayer
      {
         audioPlayerUserPaused = true
         player.pause()
      }
   }
   
   @objc func playerSliderTap(sender: UITapGestureRecognizer)
   {
      if sender.state == .ended
      {
         let pointTapped: CGPoint = sender.location(in: playerSlider)
         let newValue = playerSlider.maximumValue * Float(pointTapped.x / playerSlider.bounds.size.width)
         
         playerSlider.setValue(newValue, animated: false)
         playerSliderValueChanged(playerSlider)
      }
   }
}

class CreateVideoMusicCell : UITableViewCell
{
   @IBOutlet weak var musicImageView: UIImageView!
	@IBOutlet weak var nameLabel: UILabel!
   @IBOutlet weak var checkImageView: UIImageView!   
   @IBOutlet weak var loadedIcon: UIImageView!
   @IBOutlet weak var loadingProgressView: UIProgressView!
   var music : MBMusic?
}

class CreateVideoMusicLibraryCell : UITableViewCell
{
   @IBOutlet weak var musicImageView: UIImageView!
   @IBOutlet weak var nameLabel: UILabel!
   @IBOutlet weak var checkImageView: UIImageView!
   @IBOutlet weak var disclosure: UIImageView!
}
