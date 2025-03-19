//
//  TabCell.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/7/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit

protocol TabCellDelegate : AnyObject
{
   func tabCellSelectMediaType(_ cell : TabCell, _ mediaType : BabyMediaType)
}

class TabCell: UICollectionViewCell
{
   static let mainColor = rgb(255, 120, 154)
   static let backColor = rgb(137, 141, 152)
   
   private static let selectionColorsCount = 256
   private static let selectionColorsLastIndex = CGFloat(selectionColorsCount - 1)
   private static let selectionColors : [UIColor] =
   {
      var colors : [UIColor] = []
      var mainFr : CGFloat
      var backFr : CGFloat
      for i in 0..<selectionColorsCount
      {
         mainFr = CGFloat(i) / selectionColorsLastIndex
         backFr = 1 - mainFr
         let color = rgb(mainFr * 255 + backFr * 137,
                         mainFr * 120 + backFr * 141,
                         mainFr * 154 + backFr * 152)
         colors.append(color)
      }
      return colors
   }()
   
   weak var delegate : TabCellDelegate!
   
   @IBOutlet weak var tabImageView: UIImageView!
   @IBOutlet weak var tabLabel: UILabel!
   @IBOutlet weak var tabIndicatorLine: UIView!
   
   override func awakeFromNib()
   {
      super.awakeFromNib()
      
      let scale = WidthRatio * 1.1
      tabImageView.transform = CGAffineTransform(scaleX: scale, y: scale)
      
      tabIndicatorLine.layer.masksToBounds = false
      tabIndicatorLine.layer.shadowOpacity = 0.5
      tabIndicatorLine.layer.shadowOffset = CGSize(width: 0, height: 2.2 * WidthRatio)
      tabIndicatorLine.layer.shadowRadius = 2.2 * WidthRatio
      tabIndicatorLine.layer.shadowColor = TabCell.mainColor.cgColor
   }
   
   var mediaType : BabyMediaType = .photo
   {
      didSet
      {
         switch mediaType
         {
         case .photo:
            tabImageView.image = #imageLiteral(resourceName: "photoEveryday")
            tabLabel.text = loc("PHOTO EVERYDAY")
         case .video:
            tabImageView.image = #imageLiteral(resourceName: "videoEveryday")
            tabLabel.text = loc("VIDEO EVERYDAY")
         case .photoInDynamics:
            tabImageView.image = #imageLiteral(resourceName: "photoInDynamics")
            tabLabel.text = loc("PHOTO IN DYNAMICS")
         }
      }
   }
   
   var selection : CGFloat = 0
   {
      didSet
      {
         let selectedFraction = minmax(0.0, selection, 1.0)
         let color = selectionColor(selectedFraction)
         tabImageView.tintColor = color
         tabLabel.textColor = color
         tabIndicatorLine.alpha = selectedFraction
      }
   }
   
   private func selectionColor(_ selectedFraction : CGFloat) -> UIColor
   {
      let index = Int(round(selectedFraction * TabCell.selectionColorsLastIndex))
      return TabCell.selectionColors[index]
   }
   
   @IBAction func buttonTap() {
      delegate.tabCellSelectMediaType(self, mediaType)
   }
}
