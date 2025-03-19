//
//  CalendarWeekdaysHeader.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 2/23/17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import UIKit

class CalendarWeekdaysHeader: UITableViewHeaderFooterView
{
   @IBOutlet var weekdayLabels: [UILabel]!
   
   override func awakeFromNib()
   {
      super.awakeFromNib()
      
      for (i, label) in weekdayLabels.enumerated() {
         label.text = weekdayNames[i]
      }
   }
}
