//
//  HighlightedColorButton.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 11/30/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit

class HighlightedColorButton: UIButton
{
   @IBInspectable var higlightedBackgroundColor : UIColor?
   var normalBackgroundColor : UIColor?
   
   override func awakeFromNib()
   {
      super.awakeFromNib()
      normalBackgroundColor = backgroundColor
   }
   
   func setColor(normal: UIColor?, higlighted: UIColor?)
   {
      self.normalBackgroundColor = normal
      self.higlightedBackgroundColor = higlighted
      updateColor()
   }
   
   func updateColor()
   {
      if isTracking {
         backgroundColor = higlightedBackgroundColor
      }
      else {
         backgroundColor = normalBackgroundColor
      }
   }
   
   override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool
   {
      let begin = super.beginTracking(touch, with: event)
      if begin {
         backgroundColor = higlightedBackgroundColor
      }
      return begin
   }
   
   override func endTracking(_ touch: UITouch?, with event: UIEvent?)
   {
      super.endTracking(touch, with: event)
      backgroundColor = normalBackgroundColor
   }
   
   override func cancelTracking(with event: UIEvent?)
   {
      super.cancelTracking(with: event)
      backgroundColor = normalBackgroundColor
   }
}
