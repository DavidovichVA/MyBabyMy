//
//  MainPregnancyCell.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/22/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit
import RealmSwift

protocol MainPregnancyCellDelegate : AnyObject
{
   func cellDidSelect(week : Int, type : BabyMediaType)
}

class MainPregnancyCell: UICollectionViewCell, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, CalendarDayCellDelegate
{
   static let itemWidth = 48 * WidthRatio
   static let itemHeight = itemWidth
   static let itemSpacing = 4 * WidthRatio
   static let sideInset = (ScreenWidth - itemWidth * 7 - itemSpacing * 6) / 2
   static let contentInset = UIEdgeInsets(top: 8 * WidthRatio, left: MainPregnancyCell.sideInset, bottom: 36 * WidthRatio, right: MainPregnancyCell.sideInset)
   
   @IBOutlet weak var pregnancyCollectionView: UICollectionView!
   @IBOutlet weak var pregnancyFlowLayout: UICollectionViewFlowLayout!
   @IBOutlet weak var pregnancyCollectionHeight: NSLayoutConstraint!
   
   weak var delegate : MainPregnancyCellDelegate?
   
   /// текущая неделя
   private var currentWeek : Int?
   
   private var mediaList = List<Media>()
   private var type : BabyMediaType = .photo
   private var isPro = false
   
   private var mediaListUpdateToken : NotificationToken?
   
   //MARK: - Lifecycle
   
   override func awakeFromNib()
   {
      super.awakeFromNib()
      pregnancyFlowLayout.itemSize = CGSize(width: MainPregnancyCell.itemWidth, height: MainPregnancyCell.itemHeight)
      pregnancyFlowLayout.minimumLineSpacing = MainPregnancyCell.itemSpacing
      pregnancyFlowLayout.minimumInteritemSpacing = floor(MainPregnancyCell.itemSpacing)
      
      pregnancyCollectionView.contentInset = MainPregnancyCell.contentInset
      pregnancyCollectionHeight.constant = 5 * MainPregnancyCell.itemHeight + 4 * MainPregnancyCell.itemSpacing + MainPregnancyCell.contentInset.top + MainPregnancyCell.contentInset.bottom
   }
   
   override func prepareForReuse()
   {
      super.prepareForReuse()
      var contentOffset = pregnancyCollectionView.contentOffset
      contentOffset.y = -pregnancyCollectionView.contentInset.top
      pregnancyCollectionView.contentOffset = contentOffset
   }
   
   override func layoutSubviews()
   {
      let overHeight = pregnancyCollectionHeight.constant - self.height
      if overHeight > 0 && overHeight < MainPregnancyCell.contentInset.bottom
      {
         var contentInset = MainPregnancyCell.contentInset
         contentInset.bottom -= overHeight
         pregnancyCollectionView.contentInset = contentInset
      }
      else
      {
         pregnancyCollectionView.contentInset = MainPregnancyCell.contentInset
      }
      super.layoutSubviews()
   }
   
   deinit
   {
      mediaListUpdateToken?.stop()
   }
   
   //MARK: - Methods
   
   public func updateData(_ type : BabyMediaType, currentWeek : Int? = nil)
   {
      self.currentWeek = currentWeek
      self.type = type
      isPro = User.current!.isPro
      let persona = User.current!.mainPersona
      mediaList = persona.medias(.pregnant, type)
      
      setNeedsLayout()
      
      mediaListUpdateToken?.stop()      
      mediaListUpdateToken = mediaList.addNotificationBlock
      {
         [unowned self]
         (changes: RealmCollectionChange<List<Media>>) in
         switch changes
         {
            case .initial: break
            case .update: self.pregnancyCollectionView.reloadData()
            case .error(let error): dlog(error.localizedDescription)
         }
      }
      pregnancyCollectionView.reloadData()
   }
   
   //MARK: - CollectionView
   
   func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
   {
      return 35
   }
   
   func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
   {
      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CalendarDayCell", for: indexPath) as! CalendarDayCell
      let weekNum = indexPath.item + 5
      
      cell.dayLabel.text = String(weekNum)
      let media = mediaList.first { m in m.pregnancyWeek == weekNum}
      cell.isActiveDay = true
      if let week = currentWeek
      {
         //cell.isActiveDay = (media != nil) || (weekNum == week)
         cell.isCurrent = (weekNum == week)
         cell.media = media
         cell.dayButton.isEnabled = cell.isCurrent || (isPro && weekNum <= week) || (cell.isActiveDay && cell.media != nil)
      }
      else
      {
         //cell.isActiveDay = (media != nil)
         cell.isCurrent = false
         cell.media = media
         cell.dayButton.isEnabled = isPro || (cell.media != nil)
      }
      
      cell.delegate = self
      
      return cell
   }
   
   //MARK: Cell delegate
   
   func calendarDayCellSelect(_ cell : CalendarDayCell)
   {
      guard let indexPath = pregnancyCollectionView.indexPath(for: cell) else { return }
      let week = indexPath.item + 5
      delegate?.cellDidSelect(week: week, type: type)
   }
}
