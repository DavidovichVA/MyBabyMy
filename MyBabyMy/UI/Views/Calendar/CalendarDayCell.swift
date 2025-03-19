//
//  CalendarDayCell.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/19/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit

@objc protocol CalendarDayCellDelegate : AnyObject
{
   @objc optional func calendarDayCellSelect(_ cell : CalendarDayCell)
}

class CalendarDayCell: UICollectionViewCell
{
   static let activeLabelColor = rgb(84, 93, 120)
   static let inactiveLabelColor = rgb(231, 233, 239)
   
   weak var delegate : CalendarDayCellDelegate?
   
   @IBOutlet weak var dayContainerView: UIView!
   @IBOutlet weak var dayLabel: UILabel!
   @IBOutlet weak var dayImageView: UIImageView!
   @IBOutlet weak var dayButton: UIButton!
   @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
   
   public var canShowTakePhotoIcon = true
   
   public var isActiveDay : Bool = true
   {
      didSet
      {
         if isActiveDay
         {
            dayLabel.textColor = CalendarDayCell.activeLabelColor
            dayImageView.isHidden = false
         }
         else
         {
            dayLabel.textColor = CalendarDayCell.inactiveLabelColor
            dayImageView.isHidden = true
         }
      }
   }
   
   public var isCurrent : Bool = false
   {
      didSet
      {
         dayContainerView.layer.borderWidth = (isCurrent && isActiveDay) ? 2 * WidthRatio : 0
      }
   }
   
   public var media : Media?
   {
      didSet
      {
         if let md = media
         {
            if md.fileLoaded
            {
               let id = md.id
               md.getThumbnailImage
               {
                  image in
                  if let newMedia = self.media, newMedia.id == id {
                     self.dayImageView.image = image
                  }
               }
            }
            else
            {
               if md.id != 0, Synchronization.mediasDownloadingFileIds.contains(md.id)
               {
                  loadingIndicator.startAnimating()
                  dayLabel.isHidden = true
                  isUserInteractionEnabled = false
               }
            }
         }
         else if isCurrent && canShowTakePhotoIcon {
            dayImageView.image = #imageLiteral(resourceName: "calendarTakePhoto")
            dayContainerView.layer.borderWidth = 0
         }
         else {
            dayImageView.image = nil
         }
      }
   }
   
   override func awakeFromNib()
   {
      super.awakeFromNib()
      dayContainerView.layer.cornerRadius = 5 * WidthRatio
   }
   
   override func prepareForReuse()
   {
      super.prepareForReuse()
      loadingIndicator.stopAnimating()
      dayLabel.isHidden = false
      dayImageView.image = nil
      isUserInteractionEnabled = true
   }
   
   @IBAction func dayTap() {
      delegate?.calendarDayCellSelect?(self)
   }
}
