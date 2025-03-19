//
//  CalendarCell.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 2/22/17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import UIKit
import RealmSwift

class CalendarCell: UITableViewCell, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource
{
   @IBOutlet weak var collectionView: UICollectionView!
   @IBOutlet weak var collectionFlowLayout: UICollectionViewFlowLayout!
   
   @IBOutlet weak var headerLabel: UILabel!

   enum CalendarCellType
   {
      case pregnant(currentWeek : Int?)
      case baby(month : DisplayedMonth, currentDate : DMYDate)
   }
   
   var type : CalendarCellType = .pregnant(currentWeek: nil)
   var personaStatus: PersonaStatus = .pregnant
   var medias : AnyRealmCollection<Media> = AnyRealmCollection<Media>(List<Media>())
   
   private var mediasUpdateToken : NotificationToken?
   
   static let itemWidth = 48 * WidthRatio
   static let itemHeight = itemWidth
   static let itemSpacing = 4 * WidthRatio
   static let sideInset = (ScreenWidth - itemWidth * 7 - itemSpacing * 6) / 2
   static let pregnantContentInset = UIEdgeInsets(top: 8 * WidthRatio, left: CalendarCell.sideInset, bottom: 36 * WidthRatio, right: CalendarCell.sideInset)
   static let babyContentInset = UIEdgeInsets(top: 8 * WidthRatio, left: CalendarCell.sideInset, bottom: 8 * WidthRatio, right: CalendarCell.sideInset)
   
   override func awakeFromNib()
   {
      super.awakeFromNib()
      
      collectionFlowLayout.itemSize = CGSize(width: CalendarCell.itemWidth, height: CalendarCell.itemHeight)
      collectionFlowLayout.minimumLineSpacing = CalendarCell.itemSpacing
      collectionFlowLayout.minimumInteritemSpacing = floor(CalendarCell.itemSpacing)
   }
   
   class func collectionNeededHeight(_ type : CalendarCellType) -> CGFloat
   {
      switch type
      {
      case .pregnant:
         let rowCount : CGFloat = 5
         return rowCount * CalendarCell.itemHeight + (rowCount - 1) * CalendarCell.itemSpacing + CalendarCell.pregnantContentInset.top + CalendarCell.pregnantContentInset.bottom
         
      case .baby(let month, _):
         let rowCount = CGFloat(month.days.count / 7)
         return rowCount * CalendarCell.itemHeight + (rowCount - 1) * CalendarCell.itemSpacing + CalendarCell.babyContentInset.top + CalendarCell.babyContentInset.bottom
      }
   }
   
   public func update()
   {
      switch type
      {
         case .pregnant: collectionView.contentInset = CalendarCell.pregnantContentInset
         case .baby: collectionView.contentInset = CalendarCell.babyContentInset
      }
      
      mediasUpdateToken?.stop()
      mediasUpdateToken = medias.addNotificationBlock
      {
         [unowned self]
         (changes: RealmCollectionChange<AnyRealmCollection<Media>>) in
         switch changes
         {
            case .initial: break
            case .update: self.collectionView.reloadData()
            case .error(let error): dlog(error.localizedDescription)
         }
      }
      collectionView.reloadData()
   }
   
   deinit
   {
      mediasUpdateToken?.stop()
   }
   
   //MARK: - CollectionView
   
   func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
   {
      switch type
      {
         case .pregnant: return 35
         case .baby(let month, _): return month.days.count
      }
   }
   
   func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
   {
      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CalendarDayCell", for: indexPath) as! CalendarDayCell
      
      switch type
      {
      case .pregnant(let currentWeek):
         let weekNum = indexPath.item + 5
         cell.dayLabel.text = String(weekNum)
         cell.canShowTakePhotoIcon = false
         let media = medias.first { m in m.pregnancyWeek == weekNum}
         
         cell.isActiveDay = true
         cell.isCurrent = (currentWeek != nil && personaStatus == .pregnant && weekNum == currentWeek)

         cell.media = media
         cell.dayButton.isEnabled = false
         
      case .baby(let month, let currentDate):
         let day = month.days[indexPath.item]
         cell.canShowTakePhotoIcon = false
         cell.dayLabel.text = String(day.date.day)
         
         cell.isActiveDay = day.belongsToMonth
         cell.isCurrent = (personaStatus == .baby && day.date == currentDate)
         
         cell.media = medias.first { m in m.date == day.date}
         cell.dayButton.isEnabled = false
      }
      
      return cell      
   }
}
