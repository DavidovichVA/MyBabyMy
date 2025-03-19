//
//  MainController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/6/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit
import QuartzCore

fileprivate(set) weak var mainController : MainController?

public let babyAgeStringFormatter : DateComponentsFormatter =
{
   let formatter = DateComponentsFormatter()
   formatter.calendar = calendar
   formatter.allowedUnits = [.year, .month, .day]
   formatter.unitsStyle = .full
   formatter.maximumUnitCount = 2
   formatter.zeroFormattingBehavior = .dropAll
   return formatter
}()

class MainController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, MainMonthCellDelegate, MainPregnancyCellDelegate, TabsViewSynchronizedScrolling, UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning, UIGestureRecognizerDelegate
{
   @IBOutlet weak var welcomeView: UIView!
   @IBOutlet weak var bgImageView: UIImageView!
   @IBOutlet weak var rightCloudImageView: UIImageView!
   @IBOutlet weak var centerCloudImageView: UIImageView!
   @IBOutlet weak var leftCloudImageView: UIImageView!
   @IBOutlet weak var dotsImageView: UIImageView!
   @IBOutlet weak var sunImageView: UIImageView!
   
   @IBOutlet weak var tabsView: TabsView!
   @IBOutlet weak var calendarCollectionView: UICollectionView!
   @IBOutlet weak var calendarFlowLayout: UICollectionViewFlowLayout!
   
   @IBOutlet weak var leftView: UIView!
   @IBOutlet weak var leftImageView: UIImageView!
   @IBOutlet weak var centerView: UIView!
   @IBOutlet weak var centerImageView: UIImageView!
   @IBOutlet weak var rightView: UIView!
   @IBOutlet weak var rightImageView: UIImageView!
   @IBOutlet weak var rightButton: UIButton!
   
   @IBOutlet weak var ageLabel: UILabel!
   @IBOutlet weak var nameLabel: UILabel!
   
   private var mainPersonaPregnancyWeek : Int?
   
   var displayedMediaType : BabyMediaType {
      return BabyMediaType(rawValue: Int(round(calendarCollectionView.contentOffset.x / calendarFlowLayout.itemSize.width)) % 3)!
   }
   
   var cachedCells : [BabyMediaType : UICollectionViewCell] = [:]
   
   enum MainDataType
   {
      case currentData
      case month(displayedMonth : DisplayedMonth)
      case pregnancy
   }
   
   var dataType : MainDataType = .currentData
   
   private var weatherTimer : Timer!
   
   //MARK: - Lifecycle
   
   override func viewDidLoad()
   {
      super.viewDidLoad()
      
      mainController = self
      
      syncScrollPartner = tabsView
      tabsView.syncScrollPartner = self
      
      rightCloudImageView.alpha = 0
      centerCloudImageView.alpha = 0
      leftCloudImageView.alpha = 0
      sunImageView.alpha = 0
      dotsImageView.alpha = 0
      bgImageView.alpha = 0
      
      setupUserProObserver()
      setupDayChangeObserver()
      
      weatherTimer = Timer.scheduledTimer(timeInterval: 600, target: self, selector: #selector(updateDisplayedWeather), userInfo: nil, repeats: true)
   }
   
   private var didFinishStartLayout = false
   private let startType : BabyMediaType = User.current?.mainPersona.lastMedia?.type ?? .photo
   
   override func viewDidLayoutSubviews()
   {
      super.viewDidLayoutSubviews()
      
      if didFinishStartLayout
      {
         for cell in cachedCells.values
         {
            cell.size = calendarFlowLayout.itemSize
            cell.layoutIfNeeded()
            cell.setNeedsDisplay()
         }
      }
      else
      {
         tabsView.setStartType(startType)
         
         let typeValue = startType.rawValue
         let offsetX = calendarCollectionView.width * CGFloat(pagesCount / 2 + typeValue)
         calendarCollectionView.contentOffset = CGPoint(x : offsetX, y : 0)
      }
      
      calendarFlowLayout.itemSize = calendarCollectionView.size
   }
   
   override func viewDidAppear(_ animated: Bool)
   {
      super.viewDidAppear(animated)
      didFinishStartLayout = true
      scrollingEnabled = true
      syncScrollPartner?.scrollingEnabled = true
      
      if let user = User.current, !user.welcomeAnimationShown
      {
         user.welcomeAnimationShown = true
         welcomeAnimation()
      }
   }
   
   override func viewWillDisappear(_ animated: Bool)
   {
      super.viewWillDisappear(animated)
      tabsView.setStartType(displayedMediaType)
   }
   
   override func viewWillAppear(_ animated: Bool)
   {
      super.viewWillAppear(animated)
      setNeedsStatusBarAppearanceUpdate()
      updateAll()
      
      if didFinishStartLayout
      {
         MainQueue.async {
            self.tabsView.updateSelectedType()
         }
      }
      
      Synchronization.forbidden = false
      AppDelegate.updateUserData()
      
      if !playingWelcomeAnimation, !(Weather.lastKnown?.isActual ?? false) {
         updateDisplayedWeather()
      }
   }
   
   override func prepare(for segue: UIStoryboardSegue, sender: Any?)
   {
      if (segue.identifier == "editMainPersona")
      {
         let controller = segue.destination as! PersonaEditController
         controller.editedPersona = User.current!.mainPersona
      }
      else if (segue.identifier == "TakeMedia")
      {
         let navController = segue.destination as! UINavigationController
         navController.transitioningDelegate = self
         let controller = navController.topViewController as! MediaTakeController
         if let data = sender as? (day : DMYDate, type : BabyMediaType)
         {
            controller.status = .baby
            controller.date = data.day
            controller.mediaType = data.type
         }
         else if let data = sender as? (week : Int, type : BabyMediaType)
         {
            controller.status = .pregnant
            controller.pregnancyWeek = data.week
            controller.mediaType = data.type
         }
         controller.setup()
      }
      else if (segue.identifier == "MediaInfo")
      {
         let data = sender as! (media : Media, infoType : MediaInfoType)
         let navController = segue.destination as! UINavigationController
         navController.transitioningDelegate = self
         let mediaInfoController = navController.topViewController as! MediaInfoController
         mediaInfoController.media = data.media
         mediaInfoController.infoType = data.infoType         
      }
      else if (segue.identifier == "showCalendar")
      {
         let navController = segue.destination as! UINavigationController
         let calendarController = navController.topViewController as! CalendarController
         calendarController.persona = User.current!.mainPersona
         calendarController.mediaType = displayedMediaType
         switch dataType
         {
         case .currentData: calendarController.startMonth = DisplayedMonth.monthForDate()
         case .month(let displayedMonth): calendarController.startMonth = displayedMonth
         default: break
         }
      }
   }
   
   //MARK: - Observers
   
   private var dayChangeObserver : NSObjectProtocol?
   private var userProObserver : NSObjectProtocol?
   
   private func setupUserProObserver()
   {
      userProObserver = NotificationCenter.default.addObserver(forName: .MBUserProChanged, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         if let currentUser = User.current, let user = notification.object as? User, user.id == currentUser.id,
            let proStatusChanged = notification.userInfo?[kUserProChangedStatus] as? Bool, proStatusChanged
         {
            self.updateAll()
         }
      }
   }
   
   private func setupDayChangeObserver()
   {
      dayChangeObserver = NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         self.updateAll()
         self.updateDisplayedWeather()
      }
   }
   
   deinit
   {
      if userProObserver != nil {
         NotificationCenter.default.removeObserver(userProObserver!)
      }
      if dayChangeObserver != nil {
         NotificationCenter.default.removeObserver(dayChangeObserver!)
      }
      weatherTimer.invalidate()
   }
   
   //MARK: - Methods
   
   private var playingWelcomeAnimation = true
   private func welcomeAnimation()
   {
      let containerWidth = welcomeView.width
      let containerHeight = welcomeView.height
      let heightCoef = containerHeight / 280.0
      let widthCoef = containerWidth / 414.0
      
      let sunSize = 92.0 * min(heightCoef, widthCoef)
      
      rightCloudImageView.frame = CGRect(x: 0, y: containerHeight, width: containerWidth, height: 123 * widthCoef)
      centerCloudImageView.frame = CGRect(x: 0, y: containerHeight, width: containerWidth, height: 122.5 * widthCoef)
      leftCloudImageView.frame = CGRect(x: 0, y: containerHeight, width: containerWidth, height: 134 * widthCoef)
      sunImageView.frame = CGRect(x: -sunSize, y: containerHeight, width: sunSize, height: sunSize)
      
      let rightCloudAlpha : CGFloat = 0.3
      let centerCloudAlpha : CGFloat = 0.45
      let leftCloudAlpha : CGFloat = 0.6
      
      bgImageView.alpha = 0
      dotsImageView.alpha = 0
      rightCloudImageView.alpha = rightCloudAlpha / 2
      centerCloudImageView.alpha = centerCloudAlpha / 2
      leftCloudImageView.alpha = leftCloudAlpha / 2
      sunImageView.alpha = 1
      
      let duration : Double = 2.1
      UIView.animateKeyframes(withDuration: duration, delay: 0.5, animations:
      {
         UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5 / duration, animations: {
            self.bgImageView.alpha = 1
         })
         
         UIView.addKeyframe(withRelativeStartTime: 1 / duration, relativeDuration: 0.5 / duration, animations:
         {
            var center = self.rightCloudImageView.center
            center.y -= self.rightCloudImageView.height
            self.rightCloudImageView.center = center

            self.rightCloudImageView.alpha = rightCloudAlpha
         })
         
         UIView.addKeyframe(withRelativeStartTime: 1.3 / duration, relativeDuration: 0.5 / duration, animations:
         {
            var center = self.centerCloudImageView.center
            center.y -= self.centerCloudImageView.height
            self.centerCloudImageView.center = center
            
            self.centerCloudImageView.alpha = centerCloudAlpha
         })
         
         UIView.addKeyframe(withRelativeStartTime: 1.6 / duration, relativeDuration: 0.5 / duration, animations:
         {
            var center = self.leftCloudImageView.center
            center.y -= self.leftCloudImageView.height
            self.leftCloudImageView.center = center
            
            self.leftCloudImageView.alpha = leftCloudAlpha
         })
         
      },
      completion:
      {
         _ in
         let sunAnimation = CAKeyframeAnimation(keyPath: "position")
         sunAnimation.calculationMode = kCAAnimationPaced
         sunAnimation.fillMode = kCAFillModeForwards
         sunAnimation.isRemovedOnCompletion = false
         sunAnimation.duration = 0.75
         
         let path = CGMutablePath()
         path.move(to: self.sunImageView.center)
         path.addCurve(to: CGPoint(x: containerWidth * 0.17, y: 175.0 * heightCoef),
                       control1: CGPoint(x: containerWidth * 0.5, y: containerHeight * 0.75),
                       control2: CGPoint(x: containerWidth * 0.2, y: containerHeight * 0.5))
         
         sunAnimation.path = path
         
         self.sunImageView.layer.add(sunAnimation, forKey: nil)
      })
      
      UIView.animateIgnoringInherited(withDuration: 0.75, delay: 3.5, animations:
      {
         self.dotsImageView.alpha = 1
         self.leftCloudImageView.alpha = 1
      },
      completion:
      {
         finished in
         self.playingWelcomeAnimation = false
         self.updateDisplayedWeather()
      })
   }
   
   private func updateAll()
   {
      guard let user = User.current, !user.personas.isEmpty else { return }
      let mainPersona = user.mainPersona
      
      mainPersonaPregnancyWeek = mainPersona.getCurrentPregnancyStats()?.pregnancyWeek
      updateNameAndAge()
      
      updateAvatars()
      
      updateCollectionViewDataSource()
      calendarCollectionView.reloadData()
   }
   
   public func updateAvatars()
   {
      guard let user = User.current, !user.personas.isEmpty else { return }
      dlog("update avatars")
      
      let mainPersona = user.mainPersona
      if let lastMedia = mainPersona.lastMedia
      {
         lastMedia.getThumbnailImage {
            image in
            self.centerImageView.image = image ?? #imageLiteral(resourceName: "defaultAvatar")
         }
      }
      else {
         centerImageView.image = #imageLiteral(resourceName: "defaultAvatar")
      }
      
      if user.personas.count >= 2
      {
         leftView.isHidden = false
         let persona = user.personas[1]
         if let lastMedia = persona.lastMedia
         {
            lastMedia.getThumbnailImage {
               image in
               self.leftImageView.image = image ?? #imageLiteral(resourceName: "defaultAvatar")
            }
         }
         else {
            leftImageView.image = #imageLiteral(resourceName: "defaultAvatar")
         }
      }
      else {
         leftView.isHidden = true
      }
      
      rightButton.removeTarget(nil, action: nil, for: .allEvents)
      if user.personas.count >= 3
      {
         let persona = user.personas[2]
         if let lastMedia = persona.lastMedia
         {
            lastMedia.getThumbnailImage {
               image in
               self.rightImageView.image = image ?? #imageLiteral(resourceName: "defaultAvatar")
            }
         }
         else {
            rightImageView.image = #imageLiteral(resourceName: "defaultAvatar")
         }
         rightButton.addTarget(self, action: #selector(rightPersonaTap), for: .touchUpInside)
      }
      else {
         rightImageView.image = #imageLiteral(resourceName: "plusSign")
         rightButton.addTarget(self, action: #selector(addPersonaTap), for: .touchUpInside)
      }
   }
   
   private func updateNameAndAge()
   {
      guard let user = User.current, !user.personas.isEmpty else { return }
      let persona = user.mainPersona
      
      nameLabel.text = persona.status == .baby ? persona.name : loc("Pregnancy")
      
      var today = Date()      
      var todayStartDate = today
      var interval : TimeInterval = 0
      _ = calendar.dateInterval(of: .day, start: &todayStartDate, interval: &interval, for: today)
      today = todayStartDate.addingTimeInterval(interval - 1)
      
      var ageString = ""
      
      switch dataType
      {
      case .currentData:
         switch persona.status
         {
         case .baby:
            if let date = persona.birthday?.getDate(), date < today,
               let string = babyAgeStringFormatter.string(from: date, to: today)
            {
               ageString = string
            }
            
         case .pregnant:
            if let (pregnancyWeek, _) = persona.getCurrentPregnancyStats() {
               ageString = String(format: loc("Week %d"), pregnancyWeek)
            }
         }
         
      case .month(let displayedMonth):
         switch persona.status
         {
         case .baby:
            ageString = String(format: "%@ %d", monthNames[displayedMonth.month - 1], displayedMonth.year)
            
         case .pregnant:
            if let (pregnancyWeek, _) = persona.getCurrentPregnancyStats() {
               ageString = String(format: loc("Week %d"), pregnancyWeek)
            }
         }
         
      case .pregnancy:
         if let (pregnancyWeek, _) = persona.getCurrentPregnancyStats() {
            ageString = String(format: loc("Week %d"), pregnancyWeek)
         }
         else if persona.status == .baby {
            ageString = loc("Pregnancy")
         }
      }
      
      ageString = ageString.replacingOccurrences(of: ",", with: " ").uppercased(with: locale)
      
      ageLabel.text = ageString
   }
   
   private func updateCollectionViewDataSource()
   {
      for type in BabyMediaType.allValues
      {
         let indexPath = IndexPath(item: type.rawValue, section: 0)
         
         switch dataType
         {
         case .currentData:
            switch User.current!.mainPersona.status
            {
            case .baby:
               let cell = calendarCollectionView.dequeueReusableCell(withReuseIdentifier: "MainMonthCell", for: indexPath) as! MainMonthCell
               cell.updateData(type)
               cell.delegate = self
               if didFinishStartLayout {
                  cell.size = calendarFlowLayout.itemSize
                  cell.layoutIfNeeded()
                  cell.setNeedsDisplay()
               }
               cachedCells[type] = cell
               
            case .pregnant:
               let cell = calendarCollectionView.dequeueReusableCell(withReuseIdentifier: "MainPregnancyCell", for: indexPath) as! MainPregnancyCell
               cell.updateData(type, currentWeek: mainPersonaPregnancyWeek)
               cell.delegate = self
               if didFinishStartLayout {
                  cell.size = calendarFlowLayout.itemSize
                  cell.layoutIfNeeded()
                  cell.setNeedsDisplay()
               }
               cachedCells[type] = cell
            }
            
         case .month(let displayedMonth):
            switch User.current!.mainPersona.status
            {
            case .baby:
               let cell = calendarCollectionView.dequeueReusableCell(withReuseIdentifier: "MainMonthCell", for: indexPath) as! MainMonthCell
               cell.updateData(type, displayedMonth: displayedMonth)
               cell.delegate = self
               if didFinishStartLayout {
                  cell.size = calendarFlowLayout.itemSize
                  cell.layoutIfNeeded()
                  cell.setNeedsDisplay()
               }
               cachedCells[type] = cell
               
            case .pregnant:
               let cell = calendarCollectionView.dequeueReusableCell(withReuseIdentifier: "MainPregnancyCell", for: indexPath) as! MainPregnancyCell
               cell.updateData(type, currentWeek: mainPersonaPregnancyWeek)
               cell.delegate = self
               if didFinishStartLayout {
                  cell.size = calendarFlowLayout.itemSize
                  cell.layoutIfNeeded()
                  cell.setNeedsDisplay()
               }
               cachedCells[type] = cell
            }
            
         case .pregnancy:
            let cell = calendarCollectionView.dequeueReusableCell(withReuseIdentifier: "MainPregnancyCell", for: indexPath) as! MainPregnancyCell
            cell.updateData(type, currentWeek: mainPersonaPregnancyWeek)
            cell.delegate = self
            if didFinishStartLayout {
               cell.size = calendarFlowLayout.itemSize
               cell.layoutIfNeeded()
               cell.setNeedsDisplay()
            }
            cachedCells[type] = cell
         }
      }
   }
   
   private var displayedWeatherTime : WeatherTime? // отображаемая комбинация времени дня и погоды
   @objc private func updateDisplayedWeather()
   {
      Weather.getCurrentWeatherTime
      {
         [weak self]
         weatherTime in
         guard let strongSelf = self, !strongSelf.playingWelcomeAnimation else { return }
         
         if let currentWeatherTime = strongSelf.displayedWeatherTime
         {
            if (currentWeatherTime.daytime != weatherTime.daytime) || (currentWeatherTime.weatherType != weatherTime.weatherType)
            {
               let weatherImage = Weather.image(for: weatherTime)
               UIView.transitionIgnoringInherited(with: strongSelf.bgImageView, duration: 2, options: [.transitionCrossDissolve], animations: {
                  strongSelf.bgImageView.image = weatherImage
               }, completion: nil)
            }
         }
         else
         {
            let weatherImage = Weather.image(for: weatherTime)
            
            UIView.animateIgnoringInherited(withDuration: 2, animations:
            {
               strongSelf.dotsImageView.alpha = 0
               strongSelf.sunImageView.alpha = 0
            })
            UIView.transitionIgnoringInherited(with: strongSelf.bgImageView, duration: 2, options: [.transitionCrossDissolve], animations: {
               strongSelf.bgImageView.image = weatherImage
            }, completion: nil)
         }
         strongSelf.displayedWeatherTime = weatherTime
      }
   }
   
   //MARK: - Transitions
   
   /// present / dismiss
   var transitionPresent = true
   
   func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning?
   {
      transitionPresent = true
      return self
   }
   
   func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning?
   {
      transitionPresent = false
      return self
   }
   
   func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
      return 0.4
   }
   
   func animateTransition(using transitionContext: UIViewControllerContextTransitioning)
   {
      guard let fromVC = transitionContext.viewController(forKey: .from),
            let toVC = transitionContext.viewController(forKey: .to) else {
         return
      }
      
      let containerView = transitionContext.containerView
      var initialFrame = transitionContext.initialFrame(for: fromVC)
      var finalFrame = transitionContext.finalFrame(for: toVC)
      let movingView: UIView
      
      if transitionPresent
      {
         movingView = toVC.view
         initialFrame.origin.y = -initialFrame.height
         containerView.addSubview(toVC.view)
      }
      else
      {
         movingView = fromVC.view
         finalFrame.origin.y = -finalFrame.height
         containerView.insertSubview(toVC.view, at: 0)
      }
      
      movingView.frame = initialFrame

      let duration = transitionContext.isAnimated ? transitionDuration(using: transitionContext) : 0
      UIView.animateIgnoringInherited(withDuration: duration, delay: 0, options: .curveLinear,
      animations:
      {
         movingView.frame = finalFrame
      },
      completion:
      {
         finished in
         transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
      })
   }
   
   //MARK: - Actions
   
   @IBAction func leftPersonaTap()
   {
      if let user = User.current
      {
         user.mainPersona = user.personas[1]
         updateAll()
      }
   }
   
   @objc func rightPersonaTap()
   {
      if let user = User.current
      {
         user.mainPersona = user.personas[2]
         updateAll()
      }
   }
   
   @objc func addPersonaTap()
   {
      self.performSegue(withIdentifier: "addPersona", sender: self)
   }
   
   //MARK: - CollectionView
   
   func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
      return pagesCount
   }
   
   public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
   {
      if cachedCells.isEmpty {
         updateCollectionViewDataSource()
      }
      
      let type = BabyMediaType(rawValue: indexPath.item % 3)!
      let cell = cachedCells[type]!
      cell.prepareForReuse()
      return cell
   }
   
   //MARK: Cell delegate
   
   func cellDidSelect(day : DMYDate, type : BabyMediaType)
   {
      guard let user = User.current else { return }
      let persona = user.mainPersona
      
      if user.isPro
      {
         let data = (day : day, type : type)
         performSegue(withIdentifier: "TakeMedia", sender: data)
      }
      else
      {
         if let existedMedia = persona.media(status: persona.status, type: type, date: day)
         {
            if day == DMYDate.currentDate()
            {
               let data = (day : day, type : type)
               performSegue(withIdentifier: "TakeMedia", sender: data)
            }
            else
            {
               switch existedMedia.type
               {
               case .photo, .photoInDynamics:
                  if let image = existedMedia.getImage() {
                     performSegue(withIdentifier: "MediaInfo", sender: (existedMedia, MediaInfoType.photo(image : image)))
                  }
               case .video:
                  performSegue(withIdentifier: "MediaInfo", sender: (existedMedia, MediaInfoType.video(videoFileUrl: existedMedia.fileURL)))
               }
            }
         }
         else
         {
            let dayMedias = persona.medias(status: persona.status, date: day)
				/*  if dayMedias.first(where: { $0.type != type }) != nil
            {
               let proNavController = Storyboard.instantiateViewController(withIdentifier: "SettingsProNavigationController")
               present(proNavController, animated: true, completion: nil)
            }
            else
            {*/
               let data = (day : day, type : type)
               performSegue(withIdentifier: "TakeMedia", sender: data)
         //   }
         }
      }
   }
   
   func cellDidSelect(week : Int, type : BabyMediaType)
   {
      guard let user = User.current else { return }
      let persona = user.mainPersona
      
      if user.isPro
      {
         let data = (week : week, type : type)
         performSegue(withIdentifier: "TakeMedia", sender: data)
      }
      else
      {
         let weekMedias = persona.medias(status: persona.status, week: week)
        /* if (weekMedias.first(where: { $0.type == type }) == nil) && (weekMedias.first(where: { $0.type != type }) != nil)
         {
            let proNavController = Storyboard.instantiateViewController(withIdentifier: "SettingsProNavigationController")
            present(proNavController, animated: true, completion: nil)
         }
         else
         {*/
            let data = (week : week, type : type)
            performSegue(withIdentifier: "TakeMedia", sender: data)
         //}
      }
   }
   
   //MARK: - Collection scrollview
   
   public func scrollViewDidScroll(_ scrollView: UIScrollView) {
      didScroll()
   }
   
   public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
      didEndScrolling()
   }
   
   public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
      didEndScrolling()
   }
   
   public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>)
   {
      syncScrollPartner?.scrollingEnabled = true
   }
   
   //MARK: - TabsViewSynchronizedScrolling
   
   weak var syncScrollPartner: TabsViewSynchronizedScrolling?
   
   var dragging : Bool {
      return calendarCollectionView.isTracking
   }
   
   var leadsScrolling : Bool = false
   {
      didSet {
         syncScrollPartner?.scrollingEnabled = !leadsScrolling
      }
   }
   
   var scrollingEnabled : Bool
   {
      get {
         return calendarCollectionView.isScrollEnabled
      }
      set {
         calendarCollectionView.isScrollEnabled = newValue
         if !newValue {
            calendarCollectionView.setContentOffset(calendarCollectionView.contentOffset, animated: false)
         }
      }
   }
   
   var currentPage : CGFloat
   {
      get
      {
         return calendarCollectionView.contentOffset.x / calendarCollectionView.width
      }
      set
      {
         calendarCollectionView.contentOffset = CGPoint(x : newValue * calendarCollectionView.width, y : 0)
      }
   }
   
   func returnToCenterOfLoop()
   {
      if abs(0.5 - (calendarCollectionView.contentOffset.x / calendarCollectionView.contentSize.width)) > 0.25
      {
         let offsetFromtTypesStart = calendarCollectionView.contentOffset.x.truncatingRemainder(dividingBy: calendarCollectionView.width * 3)
         let offsetX = calendarCollectionView.width * CGFloat(pagesCount / 2) + offsetFromtTypesStart
         
         calendarCollectionView.contentOffset = CGPoint(x : offsetX, y : 0)
      }
   }
   
   //MARK: - Swipe Recognizer Delegate
   
   func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
   {
      if otherGestureRecognizer is UIPanGestureRecognizer, let collectionView = otherGestureRecognizer.view as? UICollectionView
      {
         return collectionView.contentOffset.y <= -collectionView.contentInset.top + 5
      }
      else {
         return false
      }
   }
}
