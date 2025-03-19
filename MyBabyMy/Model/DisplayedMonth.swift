//
//  DisplayedMonth.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/19/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import RealmSwift

/// отображаемый в календаре месяц
class DisplayedMonth: Object
{
   dynamic var id = 0
   
   dynamic var year = 0
   dynamic var month = 0

   let days = List<DisplayedMonthDay>()
   
   override class func primaryKey() -> String? {
      return "id"
   }
   
   private static let components : Set<Calendar.Component> = [.year, .month]
   
   /// получает отображаемый месяц по дате в нем
   class func monthForDMYDate(_ date : DMYDate = DMYDate.currentDate()) -> DisplayedMonth {
      return month(monthNum: date.month, yearNum: date.year)
   }
   
   /// получает отображаемый месяц по дате в нем
   class func monthForDate(_ date : Date = Date()) -> DisplayedMonth
   {
      let dateComponents = calendar.dateComponents(components, from: date)
      
      let dateMonth = dateComponents.month!
      let dateYear = dateComponents.year!
      
      return month(monthNum: dateMonth, yearNum: dateYear)
   }
   
   /// получает отображаемый месяц
   class func month(monthNum : Int, yearNum : Int) -> DisplayedMonth
   {
      let key = yearNum * 100 + monthNum
      
      let defaultRealm = Realm.main
      if let month = defaultRealm.object(ofType: DisplayedMonth.self, forPrimaryKey: key) {
         return month
      }
      
      let dateComponents = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: yearNum, month: monthNum)
      let date = calendar.date(from: dateComponents)!
      
      var periodStartDate = date
      var interval : TimeInterval = 0
      _ = calendar.dateInterval(of: .month, start: &periodStartDate, interval: &interval, for: date)
      let monthStartDate = periodStartDate
      let monthEndDate = monthStartDate.addingTimeInterval(interval - 18000)
      
      _ = calendar.dateInterval(of: .weekOfYear, start: &periodStartDate, interval: &interval, for: monthStartDate)
      let displayedMonthStartDate = periodStartDate
      
      _ = calendar.dateInterval(of: .weekOfYear, start: &periodStartDate, interval: &interval, for: monthEndDate)
      let displayedMonthEndDate = periodStartDate.addingTimeInterval(interval - 18000)
      
      
      let month = DisplayedMonth()
      month.id = key
      month.year = yearNum
      month.month = monthNum
      
      var cycleDate = DMYDate.fromDate(displayedMonthStartDate)
      let endDate = DMYDate.fromDate(displayedMonthEndDate)
      while cycleDate <= endDate
      {
         let day = DisplayedMonthDay()
         day.date = cycleDate
         day.belongsToMonth = (cycleDate.month == monthNum)
         month.days.append(day)
         
         cycleDate = cycleDate.addingDays(1)
      }
      
      defaultRealm.writeWithTransactionIfNeeded {
         defaultRealm.add(month)
      }
      
      return month
   }
}

class DisplayedMonthDay: Object
{
   dynamic var date : DMYDate!
   dynamic var belongsToMonth = false
}
