//
//  CalendarController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 2/22/17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import UIKit
import RealmSwift

let monthNames : [String] =
{
   var names = calendar.standaloneMonthSymbols
   names = names.map { name in name.capitalized(with: locale) }
   return names
}()

class CalendarController: UITableViewController
{
   var persona : Persona!
   var mediaType : BabyMediaType!
   
   var startMonth : DisplayedMonth?
   
   private var currentPregnancyWeek : Int?
   private var currentDate = DMYDate.currentDate()
   
   private var pregnancyMedias : AnyRealmCollection<Media>!
   private var babyMonthMedias : [(displayedMonth : DisplayedMonth, medias : AnyRealmCollection<Media>)] = []
   
   var showBabyMonthMedias : Bool = false
   
   override func viewDidLoad()
   {
      super.viewDidLoad()
      
      currentPregnancyWeek = persona.getCurrentPregnancyStats()?.pregnancyWeek
      pregnancyMedias = AnyRealmCollection<Media>(persona.medias(.pregnant, mediaType))
      
      showBabyMonthMedias = (persona.status == .baby || persona.birthday != nil)
      
      if showBabyMonthMedias
      {
         let allBabyMedias = persona.medias(.baby, mediaType)
         
         let endDate = DMYDate.currentDate()
         
         let startDate : DMYDate
         if let date = persona.birthday {
            startDate = min(date, endDate)
         }
         else
         {
            let dateComponents = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2000, month: 1)
            let date = DMYDate.fromDate(calendar.date(from: dateComponents)!)
            startDate = min(date, endDate)
         }
         
         var monthNum = startDate.month
         var yearNum = startDate.year
         
         while true
         {
            if yearNum > endDate.year { break }
            if (yearNum == endDate.year) && (monthNum > endDate.month) { break }
            
            let displayedMonth = DisplayedMonth.month(monthNum: monthNum, yearNum: yearNum)
            let babyMedias = AnyRealmCollection<Media>(allBabyMedias.filter("date.year == %d AND date.month == %d", yearNum, monthNum))
            babyMonthMedias.append((displayedMonth, babyMedias))
            
            if monthNum < 12 {
               monthNum += 1
            }
            else {
               monthNum = 1
               yearNum += 1
            }
         }
      }
      
      let nib = UINib(nibName: "CalendarWeekdaysHeader", bundle: nil)
      tableView.register(nib, forHeaderFooterViewReuseIdentifier: "CalendarWeekdaysHeader")
      
      tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 12 * WidthRatio, right: 0)
   }

   override func viewWillAppear(_ animated: Bool)
   {
      super.viewWillAppear(animated)
      tableView.reloadData()
      if let month = startMonth, showBabyMonthMedias, let index = babyMonthMedias.index(where: { monthMedias in monthMedias.displayedMonth.id == month.id })
      {
         tableView.scrollToRow(at: IndexPath(row: index, section: 1), at: .middle, animated: false)
      }
   }
   
   // MARK: - Table view

   override func numberOfSections(in tableView: UITableView) -> Int
   {
      return showBabyMonthMedias ? 2 : 1
   }

   override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
   {
      switch section
      {
         case 0: return 1
         case 1: return babyMonthMedias.count
         default: return 0
      }
   }
   
   override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
   {
      let type : CalendarCell.CalendarCellType
      
      switch indexPath.section
      {
      case 0:
         type = .pregnant(currentWeek : currentPregnancyWeek)
      case 1:
         let monthMedias = babyMonthMedias[indexPath.row]
         type = .baby(month : monthMedias.displayedMonth, currentDate : currentDate)
      default:
         type = .pregnant(currentWeek : nil)
      }
      
      return CalendarCell.collectionNeededHeight(type) + 70 * WidthRatio
   }
   
   override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
   {
      let cell = tableView.dequeueReusableCell(withIdentifier: "CalendarCell", for: indexPath) as! CalendarCell
      
      switch indexPath.section
      {
      case 0:
         cell.type = .pregnant(currentWeek : currentPregnancyWeek)
         cell.medias = pregnancyMedias
         cell.headerLabel.text = loc("Pregnancy Weeks")
         
      case 1:
         let monthMedias = babyMonthMedias[indexPath.row]
         cell.type = .baby(month : monthMedias.displayedMonth, currentDate : currentDate)
         cell.medias = monthMedias.medias
         cell.headerLabel.text = String(format: "%@ %d", monthNames[monthMedias.displayedMonth.month - 1], monthMedias.displayedMonth.year)
         
      default: break
      }
      
      cell.personaStatus = persona.status
      cell.update()
      return cell
   }
   
   override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
   {
      switch section
      {
         case 1: return CalendarCell.itemHeight
         default: return 0
      }
   }
   
   override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
   {
      switch section
      {
         case 1: return tableView.dequeueReusableHeaderFooterView(withIdentifier: "CalendarWeekdaysHeader") as! CalendarWeekdaysHeader
         default: return nil
      }
   }
   
   override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
   {
      switch indexPath.section
      {
      case 0:
         mainController?.dataType = .pregnancy
         
      case 1:
         let monthMedias = babyMonthMedias[indexPath.row]
         let displayedMonth = monthMedias.displayedMonth
         let currentMonth = DisplayedMonth.monthForDate()
         if displayedMonth.id == currentMonth.id {
            mainController?.dataType = .currentData
         }
         else {
            mainController?.dataType = .month(displayedMonth: displayedMonth)
         }
      default: break
      }

      presentingViewController?.dismiss(animated: true, completion: nil)
   }
   
   //MARK: - Actions
   @IBAction func backTap(_ sender: UIBarButtonItem)
   {
      mainController?.dataType = .currentData
      presentingViewController?.dismiss(animated: true, completion: nil)
   }
}
