import UIKit

class RoundView: UIView
{
   override func layoutSubviews()
   {
      super.layoutSubviews()
      layer.cornerRadius = bounds.width / 2
      isOpaque = false
   }
}
