//
//  Purchase.swift
//  MyBabyMy
//
//  Created by Dmitry on 13.01.17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import RealmSwift

class Purchase: Object
{
   dynamic var timestamp : Double = 0
	dynamic var transactionId = ""
	dynamic var productId = ""
   
   dynamic var days = 0
   dynamic var months = 0
   dynamic var years = 0
   
   class func purchase(timestamp : Double, transactionId : String, productId : String) -> Purchase?
   {
      guard timestamp > 0, !transactionId.isEmpty, !productId.isEmpty else { return nil }
      
      let purchase = Purchase()
      
      purchase.timestamp = timestamp
      purchase.transactionId = transactionId
      purchase.productId = productId
      
      let components = productId.components(separatedBy: ".")
      for component in components
      {
         let idComponents = component.components(separatedBy: "_")
         guard idComponents.count == 2 else { return nil }
         
         guard let count = Int(idComponents[0]) else { return nil }
         let periodString = idComponents[1]
         
         if periodString.contains("day") {
            purchase.days = count
         }
         else if periodString.contains("month") {
            purchase.months = count
         }
         else if periodString.contains("year") {
            purchase.years = count
         }
         else {
            return nil
         }
      }
      
      guard (purchase.days >= 0 && purchase.months >= 0 && purchase.years >= 0) else { return nil }
      guard (purchase.days > 0 || purchase.months > 0 || purchase.years > 0) else { return nil }
      
      return purchase
   }
}
