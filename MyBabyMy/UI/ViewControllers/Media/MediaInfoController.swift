//
//  MediaInfoController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 1/17/17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import UIKit
import RealmSwift
import AVFoundation
import Alamofire

enum MediaInfoType
{
   case photo(image : UIImage)
   case video(videoFileUrl : URL)
}

class MediaInfoController: UIViewController, UITableViewDelegate, UITableViewDataSource, MediaInfoCellDelegate, MediaCityCellDelegate, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource
{
   var media : Media!
   var infoType : MediaInfoType!
   weak var mediaTakeController : MediaTakeController? = nil
   
   @IBOutlet weak var scrollview: UIScrollView!
   @IBOutlet weak var displayContainerView: UIView!
   @IBOutlet weak var displayView: UIView!
   @IBOutlet weak var displayImageView: UIImageView!
   @IBOutlet weak var capturedVideoPlayView: UIView!
   @IBOutlet weak var infoTableView: UITableView!
   @IBOutlet weak var bestMomentView: UIView!
   @IBOutlet weak var bestMomentLabel: UILabel!
   @IBOutlet weak var bestMomentImageView: UIImageView!
   @IBOutlet weak var pickersViewHeight: NSLayoutConstraint!
   @IBOutlet weak var shareButton: UIButton!   
   @IBOutlet weak var saveView: UIView!
   @IBOutlet weak var saveHeight: NSLayoutConstraint!
   @IBOutlet weak var pickersScrollview: UIScrollView!
   @IBOutlet weak var textField: UITextField!
   @IBOutlet weak var weatherView: UIView!
   @IBOutlet weak var weatherPicker: UIPickerView!
   @IBOutlet weak var pickersTitleLabel: UILabel!
   @IBOutlet weak var citiesTableView: UITableView!
   @IBOutlet weak var citiesTableHeight: NSLayoutConstraint!
   
   private let grayColor = rgb(137, 141, 152)
   private let pinkColor = rgb(255, 120, 154)
   
   private var videoPlayer : AVPlayer!
   private var playerLayer : AVPlayerLayer!
   
   private enum CellType
   {
      case date
      case place
      case weather
   }
   private var cellTypes : [CellType] = [.date, .place, .weather]
   
   private var citySuggestions : [String] = []
   
   private var currentPicker : CellType = .place {
      didSet
      {
         switch currentPicker {
         case .place:
            textField.isHidden = false
            weatherView.isHidden = true
            pickersTitleLabel.text = loc("PLACE")
            
         case .weather:
            textField.isHidden = true
            weatherView.isHidden = false
            pickersTitleLabel.text = loc("WEATHER")
            
         default:
            textField.isHidden = true
            weatherView.isHidden = true
            pickersTitleLabel.text = nil
         }
      }
   }
   
   private let temperatures : [String] = ["+50", "+49", "+48", "+47", "+46", "+45", "+44", "+43", "+42", "+41",
                                          "+40", "+39", "+38", "+37", "+36", "+35", "+34", "+33", "+32", "+31",
                                          "+30", "+29", "+28", "+27", "+26", "+25", "+24", "+23", "+22", "+21",
                                          "+20", "+19", "+18", "+17", "+16", "+15", "+14", "+13", "+12", "+11",
                                          "+10", "+9", "+8", "+7", "+6", "+5", "+4", "+3", "+2", "+1","0",
                                          "-1", "-2", "-3", "-4", "-5", "-6", "-7", "-8", "-9", "-10",
                                          "-11", "-12", "-13", "-14", "-15", "-16", "-17", "-18", "-19", "-20",
                                          "-21", "-22", "-23", "-24", "-25", "-26", "-27", "-28", "-29", "-30",
                                          "-31", "-32", "-33", "-34", "-35", "-36", "-37", "-38", "-39", "-40",
                                          "-41", "-42", "-43", "-44", "-45", "-46", "-47", "-48", "-49", "-50"]
   
   private var watchCurrentPositionKey : String? = nil
   
   //MARK: - Lifecycle
   
   override func viewDidLoad()
   {
      super.viewDidLoad()
      
      setupForVideo()
      setupApplicationObservers()
      setupUserProObserver()
      setupForKeyboard()
      
      if media.realm != nil {
         media = Media(value: media)
      }
      
      updateInteractionEnabled()
      
      if media.isCurrent
      {
         setMediaCurrentPlace()
         setMediaCurrentWeather()
      }
      
      if geolocationAllowed {
         watchCurrentPositionKey = LocationManager.watchCurrentPosition({ _ in })
      }
      
      var bestMomentHeight : CGFloat
      if isIPhone4 {
         infoTableView.rowHeight = 68 * HeightRatio
         bestMomentHeight = 66 * HeightRatio
         saveHeight.constant = 63 * HeightRatio
      }
      else {
         infoTableView.rowHeight = 68 * WidthRatio
         bestMomentHeight = 66 * WidthRatio
      }
      pickersViewHeight.constant = infoTableView.rowHeight * 4
      bestMomentView.frame = CGRect(x: 0, y: 0, width: ScreenWidth, height: bestMomentHeight)
      infoTableView.tableFooterView = bestMomentView
   }
   
   override func viewDidLayoutSubviews()
   {
      super.viewDidLayoutSubviews()
      playerLayer.frame = capturedVideoPlayView.layer.bounds
   }
   
   override func viewWillAppear(_ animated: Bool)
   {
      super.viewWillAppear(animated)
      if let navigationBar = navigationController?.navigationBar
      {
         navigationBar.isTranslucent = true
         navigationBar.shadowImage = UIImage()
         navigationBar.setBackgroundImage(UIImage.pixelImage(UIColor.white), for: UIBarMetrics.default)
      }
      
      switch infoType!
      {
      case .photo(let image):
         navigationItem.title = loc("PHOTO INFO")
         displayImageView.image = image
         stopVideoAnimation()
         shareButton.isHidden = false
      
      case .video(let videoFileURL):
         navigationItem.title = loc("VIDEO INFO")
         MainQueue.async {
            self.startVideoAnimation(videoFileURL)
         }
         displayImageView.image = nil
         shareButton.isHidden = !FileManager.default.isReadableFile(atPath: videoFileURL.relativePath)
      }
      
      if media.type == .photoInDynamics || media.status == .pregnant
      {
         bestMomentView.isHidden = true
      }
      else {
         bestMomentView.isHidden = false
         updateBestMomentView()
      }

      infoTableView.reloadData()
      updateInteractionEnabled()
   }
   
   override func viewDidDisappear(_ animated: Bool)
   {
      super.viewDidDisappear(animated)
      if case .video = infoType! {
         stopVideoAnimation()
      }
   }
   
   //MARK: - Methods
   
   func goBack()
   {
      if mediaTakeController != nil {
         _ = navigationController?.popViewController(animated: true)
      }
      else {
         presentingViewController?.dismiss(animated: true, completion: nil)
      }
   }
   
   func deleteMediaWithConfirmation()
   {
      let alertController = UIAlertController(title: nil, message: loc("You really want to delete?"), preferredStyle: .actionSheet)
      
      let cancel = UIAlertAction(title: loc("CANCEL"), style: .cancel)
      alertController.addAction(cancel)
      
      let delete = UIAlertAction(title: loc("DELETE"), style: .destructive, handler:
      {
         _ in
         self.stopVideoAnimation()
         
         if let controller = self.mediaTakeController {
            controller.removeCurrentMedia()
         }
         
         if let existedMedia = User.current?.mainPersona.media(status: self.media.status,
            type: self.media.type, date: self.media.date, week: self.media.pregnancyWeek)
         {
            existedMedia.delete()
         }
         
         self.goBack()
      })
      alertController.addAction(delete)
      
      AlertManager.showAlert(alertController)
   }
   
   func saveAndDismiss()
   {
      media.timestamp = Int64(Date().timeIntervalSince1970)
      if let controller = self.mediaTakeController {
         controller.saveAndDismiss()
      }
      else {
         media.persona?.addOrUpdate(media)
         goBack()
      }
   }
   
   func share()
   {
      var activityItems : [Any] = []
      
      switch infoType!
      {
         case .photo(let image): activityItems.append(image)
         case .video(let videoFileURL): activityItems.append(videoFileURL)
      }
      
      let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
      activityViewController.popoverPresentationController?.sourceView = view // so that iPads won't crash
      activityViewController.excludedActivityTypes = [.airDrop]
      
      present(activityViewController, animated: true, completion: nil)
   }
   
   private var interactionEnabled = true
   func updateInteractionEnabled()
   {
      guard let user = User.current else { return }
      
      interactionEnabled = (mediaTakeController != nil || user.isPro)
      if interactionEnabled
      {
         saveView.backgroundColor = rgb(255, 120, 154)
         saveView.isUserInteractionEnabled = true
         infoTableView.isUserInteractionEnabled = true
      }
      else
      {
         saveView.backgroundColor = rgb(137, 141, 152)
         saveView.isUserInteractionEnabled = false
         infoTableView.isUserInteractionEnabled = false
      }
   }
   
   private var getCurrentPositionKey : String? = nil
   func setMediaCurrentPlace()
   {
      guard media.place.isEmpty && interactionEnabled else { return }
      media.autoFillCurrentPlace
      {
         [weak self]
         filled in
         
         if filled {
            self?.infoTableView.reloadData()
         }
      }
   }
   
   private func setMediaCurrentWeather()
   {
      guard media.weather.isEmpty && interactionEnabled else { return }
      media.autoFillCurrentWeather
      {
         [weak self]
         filled in
         
         if filled {
            self?.infoTableView.reloadData()
         }
      }
   }
   
   private func closeCitySuggestions(_ animated : Bool = true)
   {
      citySuggestions.removeAll()
      citiesTableView.reloadData()
      citiesTableHeight.constant = 0
      UIView.animateIgnoringInherited(withDuration: (animated ? 0.3 : 0), animations: {
         self.citiesTableView.superview?.layoutIfNeeded()
      })
   }
   
   private func updateBestMomentView()
   {
      let color : UIColor = media.isBestMoment ? pinkColor : grayColor
      bestMomentLabel.textColor = color
      bestMomentImageView.tintColor = color
   }
   
   //MARK: - Values & Pickers
   
   private func updateFromCurrentField()
   {
      switch currentPicker
      {
      case .place: media.place = textField.text ?? ""
         
      case .weather:
         let weatherType = WeatherType.allTypes[weatherPicker.selectedRow(inComponent: 0)]
         let temperature = temperatures[weatherPicker.selectedRow(inComponent: 1)]
         media.weather = "\(weatherType.rawValue) \(temperature)"
         
      default: break
      }
      
      media.timestamp = Int64(Date().timeIntervalSince1970)
      updateCurrentPickerValue()
      infoTableView.reloadData()
   }
   
   private func updateCurrentPickerValue()
   {
      switch currentPicker
      {
      case .place:
         textField.text = media.place
      
      case .weather:
         let components = media.weather.components(separatedBy: " ")
         var weatherTypeRow = 0
         var temperatureRow = 50
         if components.count == 2
         {
            if let index = WeatherType.allTypes.index(where: {$0.rawValue == components[0]}) {
               weatherTypeRow = index
            }
            if let index = temperatures.index(of: components[1]) {
               temperatureRow = index
            }
         }
         weatherPicker.selectRow(weatherTypeRow, inComponent: 0, animated: false)
         weatherPicker.selectRow(temperatureRow, inComponent: 1, animated: false)
         
      default: break
      }
   }
   
   private func showPicker(_ picker : CellType)
   {
      currentPicker = picker
      updateCurrentPickerValue()
      showPickers()
   }
   
   private var pickersShown = false
   private func showPickers() {
      pickersScrollview.setContentOffset(CGPoint(x : scrollview.width, y : 0), animated: true)
      pickersShown = true
   }
   
   private func hidePickers() {
      pickersScrollview.setContentOffset(CGPoint.zero, animated: true)
      pickersShown = false
   }
   
   //MARK: - Picker Delegate
   
   public func numberOfComponents(in pickerView: UIPickerView) -> Int
   {
      return 2
   }
   
   public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int
   {
      if component == 0 {
         return WeatherType.allTypes.count
      }
      else {
         return temperatures.count
      }
   }
   
   public func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView
   {
      var pickerLabel : UILabel! = view as? UILabel;
      
      if (pickerLabel == nil)
      {
         pickerLabel = UILabel()         
         pickerLabel.font = UIFont.systemFont(ofSize: 15.45 * WidthRatio)
         pickerLabel.textAlignment = .center
         pickerLabel.textColor = pinkColor
      }
      
      if component == 0 {
         pickerLabel.text = loc(WeatherType.allTypes[row].rawValue)
      }
      else {
         pickerLabel.text = temperatures[row]
      }

      return pickerLabel
   }
   
   //MARK: - Video
   
   private func setupForVideo()
   {
      videoPlayer = AVPlayer()
      videoPlayer.actionAtItemEnd = .pause
      setupVideoEndObserver()
      
      playerLayer = AVPlayerLayer(player: videoPlayer)
      playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
      capturedVideoPlayView.layer.addSublayer(playerLayer)
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
         videoPlayer.seek(to: CMTime(seconds: 0, preferredTimescale: 600))
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
   
   //MARK: - Observers
   
   private var applicationResignObserver : NSObjectProtocol?
   private var applicationBecomeActiveObserver : NSObjectProtocol?
   private var videoEndObserver : NSObjectProtocol?
   private var userProObserver : NSObjectProtocol?
   
   private func setupApplicationObservers()
   {
      applicationResignObserver = NotificationCenter.default.addObserver(forName: .UIApplicationWillResignActive, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         
         if case .video = self.infoType! {
            self.stopVideoAnimation()
         }
      }
      
      applicationBecomeActiveObserver = NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         
         if case .video(let videoFileUrl) = self.infoType! {
            self.startVideoAnimation(videoFileUrl)
         }
      }
   }
   
   private func setupVideoEndObserver()
   {
      videoEndObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         
         guard let object = notification.object as? AVPlayerItem, let playerItem = self.videoPlayer.currentItem, object === playerItem else { return }
         
         UIView.animateIgnoringInherited(withDuration: 1, animations: {
            self.capturedVideoPlayView.alpha = 0
         },
         completion:
         {
            animationFinished in
            guard animationFinished else { return }
            self.startVideoAnimation()
         })
      }
   }
   
   private func setupUserProObserver()
   {
      userProObserver = NotificationCenter.default.addObserver(forName: .MBUserProChanged, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         if let currentUser = User.current, let user = notification.object as? User, user.id == currentUser.id,
            let proStatusChanged = notification.userInfo?[kUserProChangedStatus] as? Bool, proStatusChanged
         {
            self.updateInteractionEnabled()
         }
      }
   }
   
   private var keyboardObserver : NSObjectProtocol?
   private var activeInputView : UIView?
   private func setupForKeyboard()
   {
      let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideKeyboardTap))
      view.addGestureRecognizer(tapRecognizer)
      
      keyboardObserver = NotificationCenter.default.addObserver(forName: .UIKeyboardWillChangeFrame, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         let keyboardRect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
         let duration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
         let curve = UIViewAnimationCurve(rawValue: (notification.userInfo?[UIKeyboardAnimationCurveUserInfoKey] as! NSNumber).intValue)!
         
         let keyboardWillHide = (keyboardRect.origin.y >= ScreenHeight)
         
         UIView.beginAnimations(nil, context: nil)
         UIView.setAnimationDuration(duration)
         UIView.setAnimationCurve(curve)
         
         if keyboardWillHide {
            self.scrollview.contentInset = UIEdgeInsets.zero
         }
         else
         {
            self.scrollview.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardRect.size.height, right: 0)
            if let activeView = self.activeInputView {
               self.scrollview.scrollViewToVisible(activeView, animated: false)
            }
         }
         
         UIView.commitAnimations()
      }
   }
   
   @objc private func hideKeyboardTap() {
      view.endEditing(true)
   }
   
   deinit
   {
      if keyboardObserver != nil {
         NotificationCenter.default.removeObserver(keyboardObserver!)
      }
      if applicationResignObserver != nil {
         NotificationCenter.default.removeObserver(applicationResignObserver!)
      }
      if applicationBecomeActiveObserver != nil {
         NotificationCenter.default.removeObserver(applicationBecomeActiveObserver!)
      }
      if videoEndObserver != nil {
         NotificationCenter.default.removeObserver(videoEndObserver!)
      }
      if userProObserver != nil {
         NotificationCenter.default.removeObserver(userProObserver!)
      }
      if let key = getCurrentPositionKey {
         LocationManager.cancelGetCurrentPosition(key)
      }
      if let key = watchCurrentPositionKey {
         LocationManager.stopWatchingPosition(key)
      }
   }
   
   //MARK: - Table view
   
   func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
   {
      if tableView == infoTableView {
         return cellTypes.count
      }
      else {
         return citySuggestions.count
      }
   }
   
   func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
   {
      if tableView == infoTableView
      {
         let cellType = cellTypes[indexPath.row]
         let cell = tableView.dequeueReusableCell(withIdentifier: (cellType == .date ? "MediaInfoDateCell" : "MediaInfoCell"), for: indexPath) as! MediaInfoCell
         
         switch cellType
         {
         case .date:
            cell.mediaImageView.image = #imageLiteral(resourceName: "mediaInfoDate")
            switch media.status
            {
            case .baby:
               cell.mediaLabel.text = loc("DATE")
               cell.mediaValueLabel.text = media.date.description
            case .pregnant:
               cell.mediaLabel.text = loc("WEEK")
               cell.mediaValueLabel.text = String(media.pregnancyWeek)
            }
            cell.separator.isHidden = false
            
         case .place:
            cell.mediaImageView.image = #imageLiteral(resourceName: "mediaInfoPlace")
            cell.mediaLabel.text = loc("PLACE")
            cell.mediaValueLabel.text = media.place
            cell.separator.isHidden = false
            
         case .weather:
            cell.mediaImageView.image = #imageLiteral(resourceName: "mediaInfoWeather")
            cell.mediaLabel.text = loc("WEATHER")
            
            let components = media.weather.components(separatedBy: " ")
            if components.count == 2 {
               cell.mediaValueLabel.text = "\(loc(components[0])) \(components[1])"
            }
            else {
               cell.mediaValueLabel.text = ""
            }
            cell.separator.isHidden = !bestMomentView.isHidden
         }
         
         let scale = WidthRatio
         cell.mediaImageView.transform = CGAffineTransform(scaleX: scale, y: scale)
         cell.delegate = self
         
         return cell
      }
      else
      {
         let cell = tableView.dequeueReusableCell(withIdentifier: "MediaCityCell", for: indexPath) as! MediaCityCell
         cell.cityTextField.text = citySuggestions[indexPath.row]
         cell.delegate = self
         return cell
      }
   }
   
//   func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
//   {
//      let cellType = cellTypes[indexPath.row]
//      switch cellType
//      {
//         case .date: break
//         default: showPicker(cellType)
//      }
//      tableView.deselectRow(at: indexPath, animated: true)
//   }
   
   func cellInfoTap(_ cell : MediaInfoCell)
   {
      guard let indexPath = infoTableView.indexPath(for: cell) else { return }
      
      let cellType = cellTypes[indexPath.row]
      switch cellType
      {
         case .date: break
         default: showPicker(cellType)
      }
      
      infoTableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
      infoTableView.deselectRow(at: indexPath, animated: true)
   }
   
   func cellCityTap(_ cell : MediaCityCell)
   {
      guard let indexPath = citiesTableView.indexPath(for: cell) else { return }
      
      citiesTableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
      citiesTableView.deselectRow(at: indexPath, animated: true)
      
      let cityName = citySuggestions[indexPath.row]
      textField.text = cityName
      
      delay(0.3) {
         self.closeCitySuggestions()
      }
   }
   
   //MARK: - TextField & Autocompletion
   
   private var lastCityEditingTime = Date.distantPast
   private var autocompletionRequest : DataRequest?   
   
   func sendCityCompletionRequestIfNeeded()
   {
      guard let text = textField.text, !text.isEmpty else { return }
      if -lastCityEditingTime.timeIntervalSinceNow < 0.5 && autocompletionRequest != nil { return }
      
      autocompletionRequest?.cancel()
      
      let request = RequestManager.googleAutocompletionCities(text, coordinate: LocationManager.location?.coordinate,
      success:
      {
         [weak self]
         cities in
         
         dlog(cities)
         guard let strongSelf = self else { return }
         guard !isNilOrEmpty(strongSelf.textField.text) else { return }
         
         strongSelf.citySuggestions = cities.reversed()
         strongSelf.citiesTableView.reloadData()
         strongSelf.citiesTableHeight.constant = CGFloat(min(cities.count, 5)) * strongSelf.citiesTableView.rowHeight
         UIView.animateIgnoringInherited(withDuration: 0.3, animations: { 
            strongSelf.citiesTableView.superview?.layoutIfNeeded()
         })
      },
      failure:
      {
         errorDescription in
         dlog(errorDescription)
      })
      
      autocompletionRequest = request
   }
   
   @IBAction func textFieldEditingChanged(_ sender: UITextField)
   {
      lastCityEditingTime = Date()
      
      if isNilOrEmpty(sender.text)
      {
         closeCitySuggestions()
      }
      else
      {
         delay(0.5)
         {
            [weak self] in
            self?.sendCityCompletionRequestIfNeeded()
         }
      }
   }
   
   public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool
   {
      activeInputView = textField
      return true
   }
   
   public func textFieldDidEndEditing(_ textField: UITextField)
   {
      if activeInputView == textField {
         activeInputView = nil
      }
   }
   
   public func textFieldShouldReturn(_ textField: UITextField) -> Bool
   {
      view.endEditing(true)
      closeCitySuggestions()
      return true
   }
   
   //MARK: - Actions
   
   @IBAction func backTap(_ sender: UIBarButtonItem) {
      goBack()
   }
   
   @IBAction func deleteTap(_ sender: UIBarButtonItem) {
      deleteMediaWithConfirmation()
   }
   
   @IBAction func shareTap() {
      share()
   }
   
   @IBAction func saveTap()
   {
      if pickersShown {
         updateFromCurrentField()
      }
      saveAndDismiss()
   }
   
   @IBAction func closePickersTap()
   {
      view.endEditing(true)
      closeCitySuggestions()
      updateFromCurrentField()
      hidePickers()
   }
   
   @IBAction func bestMomentTap()
   {
      media.isBestMoment = !media.isBestMoment
      updateBestMomentView()
   }
}


protocol MediaInfoCellDelegate : AnyObject {
   func cellInfoTap(_ cell : MediaInfoCell)
}

class MediaInfoCell : UITableViewCell
{
   @IBOutlet weak var mediaImageView: UIImageView!
   @IBOutlet weak var mediaLabel: UILabel!
   @IBOutlet weak var mediaValueLabel: UILabel!
   @IBOutlet weak var separator: UIView!
   weak var delegate : MediaInfoCellDelegate?
   
   @IBAction func cellTap() {
      delegate?.cellInfoTap(self)
   }
}

protocol MediaCityCellDelegate : AnyObject {
   func cellCityTap(_ cell : MediaCityCell)
}

class MediaCityCell : UITableViewCell
{
   @IBOutlet weak var cityTextField: UITextField!
   weak var delegate : MediaCityCellDelegate?
   
   @IBAction func cellTap() {
      delegate?.cellCityTap(self)
   }
}
