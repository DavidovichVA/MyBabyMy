import UIKit

/// always scrolls, even if tap is over button
class AlwaysDraggingCollectionView: UICollectionView
{
   //scroll scrollview when dragging touch on its content
   override func touchesShouldCancel(in view: UIView) -> Bool {
      return true
   }
}
