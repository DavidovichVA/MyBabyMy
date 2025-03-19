//
//  CreateVideoGeneralSettingsController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/6/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit
import RealmSwift

class CreateVideoGeneralSettingsController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, TabsViewDelegate
{
	@IBOutlet weak var collectionViewFlowLayout: UICollectionViewFlowLayout!
	@IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var tabsView: TabsView!
	
   @IBOutlet weak var pregnancyView: UIView!
   @IBOutlet weak var pregnancyLabel: UILabel!
   @IBOutlet weak var pregnancySlider: UISlider!
   
   @IBOutlet weak var periodView: UIView!
   @IBOutlet weak var periodLabel: UILabel!
   @IBOutlet weak var periodSlider: RangeSlider!
   
   @IBOutlet weak var babyView: UIView!
   @IBOutlet weak var babyLabel: UILabel!
   @IBOutlet weak var babySlider: UISlider!
	
   let sliderDisabledColor = UIColor.darkGray
   let sliderEnabledColor = rgb(255, 120, 154)
   
   private enum CellType
   {
      case normalMovie
      case slowMovie
      case bestMoments
   }
   
   private var cellTypes : [CellType] = []
   private var selectedType : CellType?
   
   private let durationFormatter : DateComponentsFormatter =
   {
      let formatter = DateComponentsFormatter()
      formatter.calendar = calendar
      formatter.allowedUnits = [.hour, .minute, .second]
      formatter.allowsFractionalUnits = true
      formatter.unitsStyle = .short
      formatter.zeroFormattingBehavior = .dropAll
      return formatter
   }()
   
   private let periodDateFormatter : DateComponentsFormatter =
      {
         let formatter = DateComponentsFormatter()
         formatter.calendar = calendar
         formatter.allowedUnits = [.year, .month, .day]
         formatter.unitsStyle = .short
         formatter.maximumUnitCount = 2
         formatter.zeroFormattingBehavior = .dropAll
         return formatter
   }()
   
   private var personaMediasUpdateToken : NotificationToken?
   
   let cellSpacing = 9 * WidthRatio
   
   // MARK: - Lifecycle
   
   override func viewDidLoad()
   {
      super.viewDidLoad()
      tabsView.scrollingEnabled = false
      collectionViewFlowLayout.minimumLineSpacing = cellSpacing
      collectionViewFlowLayout.minimumInteritemSpacing = cellSpacing
      collectionView.contentInset = UIEdgeInsetsMake(0, cellSpacing, 0, cellSpacing)
      
      let personaMedias = Realm.main.objects(Media.self).filter("personaId == %d", VideoMaker.persona.id)
      personaMediasUpdateToken = personaMedias.addNotificationBlock
      {
         [unowned self]
         (changes: RealmCollectionChange<Results<Media>>) in
         switch changes
         {
            case .initial: break
            case .update: self.updateSliderViews()
            case .error(let error): dlog(error.localizedDescription)
         }
      }
      updateSliderViews()
   }
   
	override func viewWillAppear(_ animated: Bool)
   {
		super.viewWillAppear(animated)
      
      navigationController?.navigationBar.barTintColor = UIColor.white
      navigationController?.navigationBar.isTranslucent = false
      navigationController?.navigationBar.tintColor = rgb(191, 182, 184)
      navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: rgb(255, 120, 154), NSFontAttributeName : UIFont.systemFont(ofSize: 12, weight: UIFontWeightMedium)]
      
		navigationController?.setNavigationBarHidden(false, animated: animated)
      
      update()
	}

   private var didSetStartTab = false
	override func viewDidLayoutSubviews()
	{
      tabsView.delegate = self
      if !didSetStartTab {
         tabsView.setStartType(VideoMaker.mediaType)
      }
	}
   
   override func viewDidAppear(_ animated: Bool)
   {
      super.viewDidAppear(animated)
      didSetStartTab = true
   }
   
   deinit
   {
      personaMediasUpdateToken?.stop()
   }
   
   // MARK: - Methods
   
   func update(_ animated : Bool = false)
   {
      updateSliderViews()
      
      switch VideoMaker.mediaType
      {
         case .photo: cellTypes = [.normalMovie, .slowMovie, .bestMoments]
         case .photoInDynamics: cellTypes = [.normalMovie, .slowMovie]
         case .video: cellTypes = [.bestMoments]
      }
      
      collectionView.reloadData()
      
      if VideoMaker.bestMoments { selectedType = .bestMoments }
      else if VideoMaker.videoPhotoSpeed == .slow { selectedType = .slowMovie }
      else if VideoMaker.videoPhotoSpeed == .normal { selectedType = .normalMovie }
      else { selectedType = nil }
      
      if let type = selectedType, let index = cellTypes.index(of: type)
      {
         let indexPath = IndexPath(item: index, section: 0)
         collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally , animated: animated)
      }
   }
   
   func updateSliderViews()
   {      
      updatePeriodSliderView()
      updatePregancySliderView()
   }
   
   func updatePregancySliderView()
   {
      let pregnancyMediasCount = VideoMaker.allPregnancyMedias.count
      let enabled = (pregnancyMediasCount > 0)
      
      if enabled
      {
         if VideoMaker.selectedPregnancyMediasCount > pregnancyMediasCount {
            VideoMaker.selectedPregnancyMediasCount = pregnancyMediasCount
         }
         
         pregnancyView.isUserInteractionEnabled = true
         pregnancyView.alpha = 1
         pregnancySlider.minimumTrackTintColor = sliderEnabledColor
         pregnancySlider.maximumValue = Float(pregnancyMediasCount)
         pregnancySlider.value = Float(VideoMaker.selectedPregnancyMediasCount)
         updatePregnancyLabel(totalCount: pregnancyMediasCount)
      }
      else
      {
         VideoMaker.selectedPregnancyMediasCount = 0
         
         pregnancyView.isUserInteractionEnabled = false
         pregnancyView.alpha = 0.4
         pregnancyLabel.text = nil
         pregnancySlider.minimumTrackTintColor = sliderDisabledColor
         pregnancySlider.maximumValue = 1
         pregnancySlider.value = 0
      }
   }
   
   func updateBabySliderView()
   {
      let constrainedBabyMediasCount = VideoMaker.constrainedToPeriodBabyMedias.count
      let enabled = (VideoMaker.persona.status == .baby && constrainedBabyMediasCount > 0)
      
      if enabled
      {
         if VideoMaker.selectedBabyMediasCount > constrainedBabyMediasCount {
            VideoMaker.selectedBabyMediasCount = constrainedBabyMediasCount
         }
         
         babyView.isUserInteractionEnabled = true
         babyView.alpha = 1
         babySlider.minimumTrackTintColor = sliderEnabledColor
         babySlider.maximumValue = Float(constrainedBabyMediasCount)
         babySlider.value = Float(VideoMaker.selectedBabyMediasCount)
         updateBabyLabel(totalCount: constrainedBabyMediasCount)
      }
      else
      {
         VideoMaker.selectedBabyMediasCount = 0
         
         babyView.isUserInteractionEnabled = false
         babyView.alpha = 0.4
         babyLabel.text = nil
         babySlider.minimumTrackTintColor = sliderDisabledColor
         babySlider.maximumValue = 1
         babySlider.value = 0
      }
   }
   
   func updatePeriodSliderView()
   {
      let babyMediasCount = VideoMaker.allBabyMedias.count
      let enabled = (VideoMaker.persona.status == .baby && babyMediasCount > 0)
      
      if enabled
      {
         let selectedPeriodRange = VideoMaker.selectedPeriodRange
         var lowerBound = selectedPeriodRange.lowerBound
         var upperBound = selectedPeriodRange.upperBound
         lowerBound = max(0, lowerBound)
         upperBound = min(babyMediasCount, upperBound)
         VideoMaker.selectedPeriodRange = lowerBound..<upperBound
         
         periodView.isUserInteractionEnabled = true
         periodView.alpha = 1
         periodSlider.trackHighlightTintColor = sliderEnabledColor
         periodSlider.maximumValue = CGFloat(babyMediasCount)
         periodSlider.lowerValue = CGFloat(lowerBound)
         periodSlider.upperValue = CGFloat(upperBound)
         updatePeriodLabel()
      }
      else
      {
         VideoMaker.selectedPeriodRange = 0..<0
         
         periodView.isUserInteractionEnabled = false
         periodView.alpha = 0.4
         periodLabel.text = nil
         periodSlider.trackHighlightTintColor = sliderDisabledColor
         periodSlider.maximumValue = 1
         periodSlider.lowerValue = 0
         periodSlider.upperValue = 0
      }
      
      updateBabySliderView()
   }
   
   
   func updatePeriodLabel()
   {
      guard let birthday = VideoMaker.persona.birthday?.getDate() else { periodLabel.text = nil; return }
      
      Realm.main.writeWithTransactionIfNeeded
      {
         let medias = VideoMaker.constrainedToPeriodBabyMedias
         guard !medias.isEmpty else { periodLabel.text = nil; return }
         
         let startDateString = periodDateFormatter.string(from: birthday, to: medias.first!.date.getDate())?
            .replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: ".", with: "") ?? ""
         
         if medias.count == 1 {
            periodLabel.text = startDateString
         }
         else
         {
            let endDateString = periodDateFormatter.string(from: birthday, to: medias.last!.date.getDate())?
               .replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: ".", with: "") ?? ""
            
            if !startDateString.isEmpty, !endDateString.isEmpty
            {
               periodLabel.text = startDateString + " - " + endDateString
            }
            else {
               periodLabel.text = nil
            }
         }
      }
   }
   
   func updatePregnancyLabel(selectedCount : Int = VideoMaker.selectedPregnancyMediasCount,
                             totalCount : Int = VideoMaker.allPregnancyMedias.count)
   {
      pregnancyLabel.text = getMediasDurationString(.pregnant, selectedCount: selectedCount, totalCount: totalCount)
   }
   
   func updateBabyLabel(selectedCount : Int = VideoMaker.selectedBabyMediasCount,
                             totalCount : Int = VideoMaker.selectedPeriodRange.count)
   {
      babyLabel.text = getMediasDurationString(.baby, selectedCount: selectedCount, totalCount: totalCount)
   }
   
   private func getMediasDurationString(_ status : PersonaStatus, selectedCount : Int, totalCount : Int) -> String
   {
      var selectedLength : Double = 0
      
      if selectedCount > 0
      {
         switch VideoMaker.mediaType
         {
         case .photo, .photoInDynamics:
            selectedLength = Double(selectedCount) * VideoMaker.videoPhotoSpeedValue
            
         case .video:
            Realm.main.writeWithTransactionIfNeeded
            {
               let selectedMedias = VideoMaker.selectedMedias(selectedCount, status)
               for media in selectedMedias {
                  selectedLength += media.videoDuration
               }
            }            
         }
      }
      
      let durationString = durationFormatter.string(from: ceil(selectedLength))?
         .replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: ".", with: "") ?? ""
      //return String(format: loc("%d of %d"), selectedCount, totalCount) + (durationString.isEmpty ? "" : " (\(durationString))")
      return durationString
   }
 
	//MARK: - CollectionView

   func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
      return cellTypes.count
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
	{
      let cellType = cellTypes[indexPath.item]
      
      if cellType == selectedType
      {
         if cellType == .bestMoments
         {
            VideoMaker.bestMoments = false
            update(true)
         }
      }
      else
      {
         switch cellType
         {
         case .normalMovie:
            VideoMaker.videoPhotoSpeed = .normal;
            VideoMaker.bestMoments = false
            
         case .slowMovie:
            VideoMaker.videoPhotoSpeed = .slow;
            VideoMaker.bestMoments = false
            
         case .bestMoments:
            VideoMaker.bestMoments = true
         }
         update(true)
      }
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
	{
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MovieTypeCell", for: indexPath) as! MovieTypeCell
      let cellType = cellTypes[indexPath.item]
      let selected = (selectedType == cellType)
      
      cell.checkMark.isHidden = !selected
      
      switch cellType
      {
      case .normalMovie:
         cell.imageView.image = #imageLiteral(resourceName: "createVideoNormalMovie")
         cell.typeTextLabel.text = loc("Normal movie")
         cell.backgroundCellView.backgroundColor = rgb(119, 211, 107)
         cell.wormsImageView.isHidden = false
      case .slowMovie:
         cell.imageView.image = #imageLiteral(resourceName: "createVideoSlowMovie")
         cell.typeTextLabel.text = loc("Slow movie")
         cell.backgroundCellView.backgroundColor = rgb(87, 212, 213)
         cell.wormsImageView.isHidden = false
      case .bestMoments:
         cell.imageView.image = #imageLiteral(resourceName: "createVideoBestMoments")
         cell.wormsImageView.isHidden = true
         cell.typeTextLabel.text = loc("Best moments")
         cell.backgroundCellView.backgroundColor = rgb(255, 114, 99)
      }
		
		return cell
	}
	
   private let unselectedHeight = floor(152 * WidthRatio)
   private let selectedHeight = floor(165 * WidthRatio)
   
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
	{
      let cellType = cellTypes[indexPath.item]
      let selected = (selectedType == cellType)
   
      let height = selected ? selectedHeight : unselectedHeight
      let width = max(height, floor((collectionView.width - cellSpacing * 2) / CGFloat(cellTypes.count) -
                                     CGFloat(cellTypes.count - 1) * cellSpacing))
		
		return CGSize(width: width, height: height)
	}
   
   //MARK: - TabsViewDelegate
   
   func tabsViewShouldSelect(_ mediaType : BabyMediaType) -> Bool {
      return true
   }
   
   func tabsViewDidSelect(_ type: BabyMediaType, animated: Bool)
	{
		VideoMaker.mediaType = type
		update()
	}
   
	//MARK: - Actions
	@IBAction func backTap(_ sender: UIBarButtonItem)
	{
      MBMusic.clearThumbnailCache()
      presentingViewController?.dismiss(animated: true, completion: nil)
	}
   
   @IBAction func nextTap()
   {
      performSegue(withIdentifier: "CreateVideoExtraSettings", sender: self)
   }
   
   @IBAction func periodValueChanged()
   {
      let lowerValue = round(periodSlider.lowerValue)
      let upperValue = round(periodSlider.upperValue)
      
      if !periodSlider.isTracking
      {
         periodSlider.lowerValue = lowerValue
         periodSlider.upperValue = upperValue
      }
      
      let intLowerValue = Int(lowerValue)
      let intUpperValue = Int(upperValue)
      
      let currentPeriodRange = VideoMaker.selectedPeriodRange
      
      if intLowerValue != currentPeriodRange.lowerBound || intUpperValue != currentPeriodRange.upperBound
      {
         VideoMaker.selectedPeriodRange = intLowerValue..<intUpperValue
         updateBabySliderView()
         updatePeriodLabel()
      }
   }
   
   @IBAction func pregnancyValueChanged()
   {
      let value = round(pregnancySlider.value)
      if !pregnancySlider.isTracking {
         pregnancySlider.value = value
      }
      
      let intValue = Int(value)
      if intValue != VideoMaker.selectedPregnancyMediasCount
      {
         VideoMaker.selectedPregnancyMediasCount = intValue
         updatePregnancyLabel(selectedCount: intValue)
      }
   }
   
   @IBAction func babyValueChanged()
   {
      let value = round(babySlider.value)
      if !babySlider.isTracking {
         babySlider.value = value
      }
      
      let intValue = Int(value)
      if intValue != VideoMaker.selectedBabyMediasCount
      {
         VideoMaker.selectedBabyMediasCount = intValue
         updateBabyLabel(selectedCount: intValue)
      }
   }
}


class MovieTypeCell : UICollectionViewCell
{
	@IBOutlet weak var wormsImageView: UIImageView!
	@IBOutlet weak var backgroundCellView: UIView!
	@IBOutlet weak var imageView: UIImageView!
	@IBOutlet weak var typeTextLabel: UILabel!
	@IBOutlet weak var checkMark: UIImageView!
}
