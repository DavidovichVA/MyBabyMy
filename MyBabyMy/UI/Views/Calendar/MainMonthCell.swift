//
//  MainMonthCell.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/19/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit
import RealmSwift

protocol MainMonthCellDelegate : AnyObject
{
   func cellDidSelect(day : DMYDate, type : BabyMediaType)
}

let weekdayNames : [String] =
{
   var names = calendar.shortStandaloneWeekdaySymbols
   let sunday = names.removeFirst()
   names.append(sunday)
   names = names.map { name in name.uppercased(with: locale) }
   return names
}()

class MainMonthCell: UICollectionViewCell, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, CalendarDayCellDelegate
{
   static let itemWidth = 48 * WidthRatio
   static let itemHeight = itemWidth
   static let itemSpacing = 4 * WidthRatio
   static let sideInset = (ScreenWidth - itemWidth * 7 - itemSpacing * 6) / 2
   static let contentInset = UIEdgeInsets(top: 8 * WidthRatio, left: MainMonthCell.sideInset, bottom: 36 * WidthRatio, right: MainMonthCell.sideInset)
   
   @IBOutlet weak var monthCollectionView: UICollectionView!
   @IBOutlet weak var monthFlowLayout: UICollectionViewFlowLayout!
   @IBOutlet weak var monthCollectionHeight: NSLayoutConstraint!
   
   weak var delegate : MainMonthCellDelegate?
   
   /// отображать ли заголовки дней недель
   public var showWeekdays : Bool = true
   
   public var currentDate = DMYDate.currentDate()
   
   private var persona : Persona!
   private var mediaList : Results<Media>!
   private var type : BabyMediaType = .photo
   private var isPro = false
   
   private var month : DisplayedMonth!
   
   private var mediaListUpdateToken : NotificationToken?
   
   //MARK: - Lifecycle
   
   override func awakeFromNib()
   {
      super.awakeFromNib()
      
      monthFlowLayout.itemSize = CGSize(width: MainMonthCell.itemWidth, height: MainMonthCell.itemHeight)
      monthFlowLayout.minimumLineSpacing = MainMonthCell.itemSpacing
      monthFlowLayout.minimumInteritemSpacing = floor(MainMonthCell.itemSpacing)
      
      monthCollectionView.contentInset = MainMonthCell.contentInset
   }
   
   override func prepareForReuse()
   {
      super.prepareForReuse()
      var contentOffset = monthCollectionView.contentOffset
      contentOffset.y = -monthCollectionView.contentInset.top
      monthCollectionView.contentOffset = contentOffset
   }
   
   override func layoutSubviews()
   {
      let rowCount = CGFloat((month.days.count / 7) + (showWeekdays ? 1 : 0))
      monthCollectionHeight.constant = rowCount * MainMonthCell.itemHeight + (rowCount - 1) * MainMonthCell.itemSpacing + MainMonthCell.contentInset.top + MainMonthCell.contentInset.bottom
      
      let overHeight = monthCollectionHeight.constant - self.height
      if overHeight > 0 && overHeight < MainMonthCell.contentInset.bottom
      {
         var contentInset = MainMonthCell.contentInset
         contentInset.bottom -= overHeight
         monthCollectionView.contentInset = contentInset
      }
      else
      {
         monthCollectionView.contentInset = MainMonthCell.contentInset
      }
      super.layoutSubviews()
   }
   
   deinit
   {
      mediaListUpdateToken?.stop()
   }
   
   //MARK: - Methods
   
   public func updateData(_ type : BabyMediaType, displayedMonth : DisplayedMonth = DisplayedMonth.monthForDate(Date()))
   {
      currentDate = DMYDate.currentDate()
      month = displayedMonth
      isPro = User.current!.isPro
      self.type = type
      persona = User.current!.mainPersona
      mediaList = persona.medias(.baby, type).filter("date.year == %d AND date.month == %d", displayedMonth.year, displayedMonth.month)
      
      setNeedsLayout()
      
      mediaListUpdateToken?.stop()      
      mediaListUpdateToken = mediaList.addNotificationBlock
      {
         [unowned self]
         (changes: RealmCollectionChange<Results<Media>>) in
         switch changes
         {
            case .initial: break
            case .update: if !self.persona.isInvalidated { self.monthCollectionView.reloadData() }
            case .error(let error): dlog(error.localizedDescription)
         }
      }
      monthCollectionView.reloadData()
   }
   
   private func isWeekday(_ section : Int) -> Bool {
      return showWeekdays && section == 0
   }
   
   
   //MARK: - CollectionView
   
   func numberOfSections(in collectionView: UICollectionView) -> Int {
      return showWeekdays ? 2 : 1
   }
   
   func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
   {
      if isWeekday(section) {
         return 7
      }
      else {
         return month.days.count
      }
   }
   
   func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
   {
      if isWeekday(indexPath.section)
      {
         let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CalendarWeekdayCell", for: indexPath) as! CalendarWeekdayCell
         cell.weekdayLabel.text = weekdayNames[indexPath.row]
         return cell
      }
      else
      {
         let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CalendarDayCell", for: indexPath) as! CalendarDayCell         
         let day = month.days[indexPath.item]
         
         cell.dayLabel.text = String(day.date.day)
         cell.isActiveDay = day.belongsToMonth
         cell.isCurrent = (day.date == currentDate)
         cell.media = mediaList?.first { m in m.date == day.date}
         
         var isButtonEnabled = false
         if cell.isActiveDay && cell.media != nil {
            isButtonEnabled = true
         }
         else if day.belongsToMonth
         {
            if cell.isCurrent {
               isButtonEnabled = true
            }
            else if !persona.isInvalidated, let birthday = persona.birthday, !birthday.isInvalidated, day.date < birthday {
               isButtonEnabled = false
            }
            else {
               isButtonEnabled = isPro && day.date <= currentDate
            }
         }
         cell.dayButton.isEnabled = isButtonEnabled

         cell.delegate = self
         return cell
      }
   }
   
   //MARK: Cell delegate
   
   func calendarDayCellSelect(_ cell : CalendarDayCell)
   {
      guard let indexPath = monthCollectionView.indexPath(for: cell) else { return }
      let day = month.days[indexPath.item]
      delegate?.cellDidSelect(day : day.date, type : type)
   }
}
