//
//  DMYDate.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/16/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import RealmSwift
import Realm.Private

let DMYDateFormatter : DateFormatter =
{
   let dateFormatter = DateFormatter()
   dateFormatter.locale = locale
   dateFormatter.calendar = calendar
   dateFormatter.dateFormat = "dd/MM/y"
   return dateFormatter
}()

fileprivate let DMYCalendarComponents : Set<Calendar.Component> = [.year, .month, .day]

/// Day-Month-Year Date components
class DMYDate: Object, Comparable
{
   dynamic var id = 0
   dynamic var day = 0
   dynamic var month = 0
   dynamic var year = 0
   
   override var description: String {
      return String(format: "%02d/%02d/%d", day, month, year)
   }
   
   //MARK: - Date conversion
   
   func getDate() -> Date
   {
      let dateComponents = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: year, month: month, day: day)
      return calendar.date(from: dateComponents)!
   }
   
   class func currentDate() -> DMYDate {
      return fromDate(Date())
   }
   
   class func fromDate(_ date : Date) -> DMYDate
   {
      let dateComponents = calendar.dateComponents(DMYCalendarComponents, from: date)
      
      let date = DMYDate()
      date.day = dateComponents.day!
      date.month = dateComponents.month!
      date.year = dateComponents.year!
      date.id = date.hash
      return date
   }
   
   class func dateFromString(_ dateString : String) -> DMYDate?
   {
      let components = dateString.components(separatedBy: "/")
      guard components.count == 3 else { return nil }
      
      if let day = Int(components[0]), 0...31 ~= day, let month = Int(components[1]), 0...12 ~= month, let year = Int(components[2]), year > 0
      {
         return date(day: day, month: month, year: year)
      }
      else {
         return nil
      }
   }
   
   class func date(day : Int = 0, month : Int = 0, year : Int = 0) -> DMYDate
   {
      let date = DMYDate()
      date.day = day
      date.month = month
      date.year = year
      date.id = date.hash
      return date
   }
   
   //MARK: - Date functions
   
   func addDays(_ count : Int)
   {
      let date = getDate().addingDays(count)
      let dateComponents = calendar.dateComponents(DMYCalendarComponents, from: date)
      
      modifyWithTransactionIfNeeded
      {
         day = dateComponents.day!
         month = dateComponents.month!
         year = dateComponents.year!
         id = hash
      }
   }
   
   func addingDays(_ count : Int) -> DMYDate {
      return DMYDate.fromDate(getDate().addingDays(count))
   }
   
   //MARK: - Hash
   
   override var hash: Int {
      return year * 10000 + month * 100 + day
   }
   
   override var hashValue: Int {
      return hash
   }
   
   //MARK: - Comparable
   
   func compare(_ other: DMYDate) -> ComparisonResult
   {
      if self.year < other.year {
         return .orderedAscending
      }
      else if self.year > other.year {
         return .orderedDescending
      }
      
      if self.month < other.month {
         return .orderedAscending
      }
      else if self.month > other.month {
         return .orderedDescending
      }
      
      if self.day < other.day {
         return .orderedAscending
      }
      else if self.day > other.day {
         return .orderedDescending
      }
      
      return .orderedSame
   }
   
   override func isEqual(_ object: Any?) -> Bool
   {
      if let other = object as? DMYDate {
         return self == other
      } else {
         return false
      }
   }
   
   public static func ==(lhs: DMYDate, rhs: DMYDate) -> Bool {
      return lhs.compare(rhs) == .orderedSame
   }
   
   public static func <(lhs: DMYDate, rhs: DMYDate) -> Bool {
      return lhs.compare(rhs) == .orderedAscending
   }
   
   public static func <=(lhs: DMYDate, rhs: DMYDate) -> Bool {
      return lhs.compare(rhs) != .orderedDescending
   }

   public static func >=(lhs: DMYDate, rhs: DMYDate) -> Bool {
      return lhs.compare(rhs) != .orderedAscending
   }
   
   public static func >(lhs: DMYDate, rhs: DMYDate) -> Bool {
      return lhs.compare(rhs) == .orderedDescending
   }
}
