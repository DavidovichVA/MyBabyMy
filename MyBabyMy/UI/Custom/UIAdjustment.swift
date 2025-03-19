import UIKit

//MARK: - Adjustment for Screen Size

extension UIView
{
   @IBInspectable var adjustsForScreenSize : Bool
   {
      get {
         return false
      }
      set {
         if newValue {
            adjustForScreenSize()
         }
      }
   }
   
   func adjustForScreenSize()
   {
      for constraint in constraints {
         constraint.constant *= WidthRatio
      }
      for subview in subviews {
         subview.adjustForScreenSize()
      }
   }
}

extension UILabel
{
   override func adjustForScreenSize()
   {
      if let currentFont = font {
         font = UIFont(name: currentFont.fontName, size: currentFont.pointSize * WidthRatio)
      }
      for constraint in constraints {
         constraint.constant *= WidthRatio
      }
   }
}
extension UITextField
{
   override func adjustForScreenSize()
   {
      if let currentFont = font {
         font = UIFont(name: currentFont.fontName, size: currentFont.pointSize * WidthRatio)
      }
      for constraint in constraints {
         constraint.constant *= WidthRatio
      }
   }
}
extension UITextView
{
   override func adjustForScreenSize()
   {
      if let currentFont = font {
         font = UIFont(name: currentFont.fontName, size: currentFont.pointSize * WidthRatio)
      }
      for constraint in constraints {
         constraint.constant *= WidthRatio
      }
   }
}
extension UIButton
{
   override func adjustForScreenSize()
   {
      if let currentFont = titleLabel?.font {
         titleLabel?.font = UIFont(name: currentFont.fontName, size: currentFont.pointSize * WidthRatio)
      }
      imageView?.contentMode = .scaleAspectFit      
      for constraint in constraints {
         constraint.constant *= WidthRatio
      }
   }
}

extension UISwitch
{
   override func adjustForScreenSize() {
      transform = CGAffineTransform(scaleX: WidthRatio, y: WidthRatio)
   }
}

extension UIStackView
{
   override func adjustForScreenSize()
   {
      for constraint in constraints {
         constraint.constant *= WidthRatio
      }
   }
}

//MARK: - Localization

extension UILabel
{
   @IBInspectable var locKey : String
   {
      get {
         return ""
      }
      set {
         if !newValue.isEmpty {
            text = loc(newValue)
         }
      }
   }
}

extension UIButton
{
   @IBInspectable var locKey : String
   {
      get {
         return ""
      }
      set {
         if !newValue.isEmpty
         {
            UIView.performWithoutAnimation
            {
               setTitle(loc(newValue), for: .normal)
               layoutIfNeeded()
            }
         }
      }
   }
}

extension UINavigationItem
{
   @IBInspectable var locKey : String
   {
      get {
         return ""
      }
      set {
         if !newValue.isEmpty {
            title = loc(newValue)
         }
      }
   }
}

extension UIBarButtonItem
{
   @IBInspectable var locKey : String
   {
      get {
         return ""
      }
      set {
         if !newValue.isEmpty {
            title = loc(newValue)
         }
      }
   }
}

extension UITabBarItem
{
   @IBInspectable var locKey : String
   {
      get {
         return ""
      }
      set {
         if !newValue.isEmpty {
            title = loc(newValue)
         }
      }
   }
}
