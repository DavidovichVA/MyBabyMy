import UIKit

extension UIView
{
   //MARK: - Layer Properties
   
   @IBInspectable var cornerRadius : CGFloat
   {
      get {
         return layer.cornerRadius
      }
      set {
         layer.cornerRadius = newValue
      }
   }
   
   @IBInspectable var borderWidth : CGFloat
   {
      get {
         return layer.borderWidth
      }
      set {
         layer.borderWidth = newValue
      }
   }
   
   @IBInspectable var borderColor : UIColor
   {
      get {
         if let layerBorderColor = layer.borderColor {
            return UIColor(cgColor: layerBorderColor)
         }
         else {
            return UIColor.black
         }
      }
      set {
         layer.borderColor = newValue.cgColor
      }
   }
   
   var shadowColor : UIColor
   {
      get {
         if let layerShadowColor = layer.shadowColor {
            return UIColor(cgColor: layerShadowColor)
         }
         else {
            return UIColor.black
         }
      }
      set {
         layer.shadowColor = newValue.cgColor
      }
   }
   
   //MARK: - Position & size
   
   var origin : CGPoint
   {
      get {
         return frame.origin
      }
      set {
         frame = CGRect(origin: newValue, size: size)
      }
   }
   
   var size : CGSize
   {
      get {
         return frame.size
      }
      set {
         frame = CGRect(origin: origin, size: newValue)
      }
   }
   
   var x : CGFloat
   {
      get {
         return origin.x
      }
      set {
         frame = CGRect(origin: CGPoint(x: newValue, y: origin.y), size: size)
      }
   }
   
   var y : CGFloat
   {
      get {
         return origin.y
      }
      set {
         frame = CGRect(origin: CGPoint(x: origin.x, y: newValue), size: size)
      }
   }
   
   var width : CGFloat
   {
      get {
         return size.width
      }
      set {
         frame = CGRect(origin: origin, size: CGSize(width: newValue, height: size.height))
      }
   }
   
   var height : CGFloat
   {
      get {
         return size.height
      }
      set {
         frame = CGRect(origin: origin, size: CGSize(width: size.width, height: newValue))
      }
   }
   
   var left : CGFloat
   {
      get {
         return x
      }
      set {
         x = newValue
      }
   }
   
   var right : CGFloat
   {
      get {
         return x + width
      }
      set {
         x = newValue - width
      }
   }
   
   var top : CGFloat
   {
      get {
         return y
      }
      set {
         y = newValue
      }
   }
   
   var bottom : CGFloat
   {
      get {
         return y + height
      }
      set {
         y = newValue - height
      }
   }
}

//MARK: - TableViewCell Separator Insets
extension UITableViewCell
{
   @IBInspectable var removedSeparatorInsets : Bool
   {
      get {
         return separatorInset == .zero &&
         preservesSuperviewLayoutMargins == false &&
         layoutMargins == .zero
      }
      set {
         if newValue {
            separatorInset = .zero
            preservesSuperviewLayoutMargins = false
            layoutMargins = .zero
         }
      }
   }
}

//MARK: - Scrollview scroll to make view visible
extension UIScrollView
{
   func scrollViewToVisible(_ view: UIView, animated: Bool)
   {
      let origin = convert(CGPoint.zero, from: view)
      scrollRectToVisible(CGRect(origin: origin, size: view.size), animated: animated)
   }
}

//MARK: - ImageTweak
extension UIImage
{
   func resized(_ newWidth: CGFloat, _ newHeight : CGFloat, useDeviceScale : Bool = false) -> UIImage {
      return resized(CGSize(width: newWidth, height: newHeight), useDeviceScale : useDeviceScale)
   }
   
   func resized(_ newSize : CGSize, useDeviceScale : Bool = false) -> UIImage
   {
      UIGraphicsBeginImageContextWithOptions(newSize, false, (useDeviceScale ? UIScreen.main.scale : self.scale))
      draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
      let destImage = UIGraphicsGetImageFromCurrentImageContext()!
      UIGraphicsEndImageContext()
      return destImage.withRenderingMode(renderingMode)
   }
   
   func scaled(by ratio: CGFloat, useDeviceScale : Bool = false) -> UIImage
   {
      let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
      return resized(newSize, useDeviceScale : useDeviceScale)
   }
   
   func constrained(to size : CGSize, mode : UIViewContentMode, useDeviceScale : Bool = true) -> UIImage
   {
      let imageView = UIImageView(image: self)
      imageView.bounds = CGRect(origin: .zero, size: size)
      imageView.contentMode = mode
      imageView.backgroundColor = UIColor.clear
      
      UIGraphicsBeginImageContextWithOptions(size, false, (useDeviceScale ? UIScreen.main.scale : self.scale))
      imageView.layer.render(in: UIGraphicsGetCurrentContext()!)
      let destImage = UIGraphicsGetImageFromCurrentImageContext()!
      UIGraphicsEndImageContext()
      return destImage.withRenderingMode(renderingMode)
   }
   
   func normalizingOrientation() -> UIImage
   {
      if imageOrientation == .up { return self }
      
      UIGraphicsBeginImageContextWithOptions(size, false, scale)
      draw(in: CGRect(origin: .zero, size: size))
      let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
      UIGraphicsEndImageContext()
      return normalizedImage.withRenderingMode(renderingMode)
   }
   
   func tinted(_ color : UIColor) -> UIImage
   {
      let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
      imageView.tintColor = color;
      imageView.image = self.withRenderingMode(.alwaysTemplate)
      
      UIGraphicsBeginImageContextWithOptions(size, false, scale)
      imageView.layer.render(in: UIGraphicsGetCurrentContext()!)

      let tintedImage = UIGraphicsGetImageFromCurrentImageContext()!
      UIGraphicsEndImageContext()
      
      return tintedImage
   }
   
   ///1x1 pixel image of color
   class func pixelImage(_ color : UIColor) -> UIImage
   {
      let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
      UIGraphicsBeginImageContext(rect.size)
      let context = UIGraphicsGetCurrentContext()!
      
      context.setFillColor(color.cgColor)
      context.fill(rect)
      
      let image = UIGraphicsGetImageFromCurrentImageContext()!
      UIGraphicsEndImageContext()
      
      return image
   }
}

//MARK: - UIView animation
extension UIView
{
   class func animateIgnoringInherited(withDuration duration: TimeInterval, animations: @escaping () -> Void)
   {
      animateIgnoringInherited(withDuration: duration, animations: animations, completion: nil)
   }
   
   class func animateIgnoringInherited(withDuration duration: TimeInterval, animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil)
   {
      UIView.animate(withDuration: duration, delay: 0, options: [.overrideInheritedCurve, .overrideInheritedDuration, .overrideInheritedOptions], animations: animations, completion: completion)
   }
   
   class func animateIgnoringInherited(withDuration duration: TimeInterval, delay: TimeInterval, options: UIViewAnimationOptions = [], animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil)
   {
      let newOptions = options.union([.overrideInheritedCurve, .overrideInheritedDuration, .overrideInheritedOptions])
      UIView.animate(withDuration: duration, delay: delay, options: newOptions, animations: animations, completion: completion)
   }
   
   class func transitionIgnoringInherited(with view: UIView, duration: TimeInterval, options: UIViewAnimationOptions = [], animations: (() -> Void)?, completion: ((Bool) -> Void)? = nil)
   {
      let newOptions = options.union([.overrideInheritedCurve, .overrideInheritedDuration, .overrideInheritedOptions])
      UIView.transition(with: view, duration: duration, options: newOptions, animations: animations, completion: completion)
   }
   
   class func transitionIgnoringInherited(from fromView: UIView, to toView: UIView, duration: TimeInterval, options: UIViewAnimationOptions = [], completion: ((Bool) -> Void)? = nil)
   {
      let newOptions = options.union([.overrideInheritedCurve, .overrideInheritedDuration, .overrideInheritedOptions])
      UIView.transition(from: fromView, to: toView, duration: duration, options: newOptions, completion: completion)
   }
}

//MARK: - Find view
extension UIView
{
   func findSubview(onlyDirectSubviews : Bool = false, criteria : (UIView) -> Bool) -> UIView?
   {
      for subview in subviews
      {
         if criteria(subview) {
            return subview
         }
      }
      
      if !onlyDirectSubviews
      {
         for subview in subviews
         {
            if let foundView = subview.findSubview(onlyDirectSubviews: false, criteria: criteria) {
               return foundView
            }
         }
      }
      
      return nil
   }
   
   func findSubview(onlyDirectSubviews : Bool = false, ofClass searchedClass: AnyClass) -> UIView?
   {
      return findSubview(onlyDirectSubviews: onlyDirectSubviews, criteria: {
         return $0.isKind(of: searchedClass)
      })
   }
   
   func findSuperview(criteria : (UIView) -> Bool) -> UIView?
   {
      var view = self
      while true
      {
         if let superview = view.superview
         {
            if criteria(superview) {
               return superview
            }
            else {
               view = superview
            }
         }
         else
         {
            return nil
         }
      }
   }
   
   func findSuperview(ofClass searchedClass: AnyClass) -> UIView?
   {
      return findSuperview(criteria: {
         return $0.isKind(of: searchedClass)
      })
   }
}

//MARK: - CG Extensions
extension CGSize
{
   static func square(_ length: Int) -> CGSize {
      return CGSize(width: length, height: length)
   }
   static func square(_ length: CGFloat) -> CGSize {
      return CGSize(width: length, height: length)
   }
   static func square(_ length: Double) -> CGSize {
      return CGSize(width: length, height: length)
   }
}
