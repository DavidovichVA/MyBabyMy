//
//  RangeSlider.swift
//  MyBabyMy
//
//  Created by Dmitry on 16.01.17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import UIKit
import QuartzCore

class RangeSlider: UIControl
{
   private let trackBackgroundLayer = CALayer()
	private let trackLayer = CALayer()
	private let lowerThumbLayer = CALayer()
	private let upperThumbLayer = CALayer()
	private var previousLocation = CGPoint()
   
   private var trackingLowerThumb = false
   private var trackingUpperThumb = false
   
   private let trackingThumbInsets : UIEdgeInsets = UIEdgeInsets(top: -40, left: -40, bottom: -40, right: -40)
   
   private let thumbHeight: CGFloat = sliderThumbImage.size.height
   private let thumbWidth: CGFloat = sliderThumbImage.size.width
   
   
	@IBInspectable var minimumValue: CGFloat = 0.0 {
		didSet {
			setNeedsLayout()
		}
	}
 
	@IBInspectable var maximumValue: CGFloat = 1.0 {
		didSet {
			setNeedsLayout()
		}
	}
 
	@IBInspectable var lowerValue: CGFloat = 0.2 {
		didSet {
			setNeedsLayout()
		}
	}
 
	@IBInspectable var upperValue: CGFloat = 0.8 {
		didSet {
			setNeedsLayout()
		}
	}
   
	@IBInspectable var trackTintColor: UIColor = UIColor.white {
		didSet {
         trackBackgroundLayer.backgroundColor = trackTintColor.cgColor
		}
	}
 
	@IBInspectable var trackHighlightTintColor: UIColor = UIColor.red {
		didSet {
			trackLayer.backgroundColor = trackHighlightTintColor.cgColor
		}
	}
   
   @IBInspectable var continuous: Bool = true
   
   private var slidingWidth : CGFloat {
      return bounds.width - thumbWidth * 2
   }
   
   var valueInterval : CGFloat {
      return maximumValue - minimumValue
   }
   
	override init(frame: CGRect) {
		super.init(frame: frame)
      setup()
	}
 
	required init(coder: NSCoder) {
		super.init(coder: coder)!
      setup()
	}
   
   private func setup()
   {
      trackBackgroundLayer.contentsScale = UIScreen.main.scale
      layer.addSublayer(trackBackgroundLayer)
      
      trackLayer.contentsScale = UIScreen.main.scale
      trackBackgroundLayer.addSublayer(trackLayer)
      
      lowerThumbLayer.frame = CGRect(origin: .zero, size: sliderThumbImage.size)
      lowerThumbLayer.contentsScale = UIScreen.main.scale
      lowerThumbLayer.contents = sliderThumbImage.cgImage
      layer.addSublayer(lowerThumbLayer)
      
      upperThumbLayer.frame = CGRect(origin: .zero, size: sliderThumbImage.size)
      upperThumbLayer.contentsScale = UIScreen.main.scale
      upperThumbLayer.contents = sliderThumbImage.cgImage
      layer.addSublayer(upperThumbLayer)
      
      trackBackgroundLayer.cornerRadius = sliderTrackHeight / 2
   }
   
   override func layoutSubviews()
   {
      validateValues()
      super.layoutSubviews()
      trackBackgroundLayer.frame = bounds.insetBy(dx: 2, dy: (bounds.height - sliderTrackHeight)/2 )
      updateLayerFrames()
   }
 
	private func updateLayerFrames()
   {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
		
      let lowerThumbRight = positionForValue(lowerValue)
      let upperThumbLeft = positionForValue(upperValue)
		
      let originY = (bounds.height - thumbHeight)/2
      lowerThumbLayer.frame = CGRect(x: lowerThumbRight - thumbWidth , y: originY, width: thumbWidth, height: thumbHeight)
		upperThumbLayer.frame = CGRect(x: upperThumbLeft, y: originY, width: thumbWidth , height: thumbHeight)

      trackLayer.frame = CGRect(x: lowerThumbRight - 2, y: 0, width: upperThumbLeft - lowerThumbRight , height: trackBackgroundLayer.bounds.height)

      CATransaction.commit()
	}
   
	private func positionForValue(_ value: CGFloat) -> CGFloat
   {
      if valueInterval > 0 {
         return slidingWidth * (value - minimumValue) / valueInterval + thumbWidth
      }
      else {
         return thumbWidth
      }
	}
   
   private func validateValues()
   {
      var value = minmax(minimumValue, lowerValue, maximumValue)
      if value != lowerValue {
         lowerValue = value
      }
      
      value = minmax(minimumValue, upperValue, maximumValue)
      if value != upperValue {
         upperValue = value
      }
   }
	
   override func point(inside point: CGPoint, with event: UIEvent?) -> Bool
   {
      var extendedRect = bounds
      extendedRect.origin.x += trackingThumbInsets.left
      extendedRect.size.width -= (trackingThumbInsets.left + trackingThumbInsets.right)
      return extendedRect.contains(point)
   }
   
	override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool
   {
		previousLocation = touch.location(in: self)
		
		// Hit test the thumb layers
      
      let middleBetweenThumbs = (lowerThumbLayer.frame.maxX + upperThumbLayer.frame.minX) / 2
      
      var lowerThumbHitRect = UIEdgeInsetsInsetRect(lowerThumbLayer.frame, trackingThumbInsets)
      if lowerThumbHitRect.maxX > middleBetweenThumbs {
         lowerThumbHitRect.size.width = middleBetweenThumbs - lowerThumbHitRect.minX
      }
      if lowerThumbHitRect.contains(previousLocation) {
         trackingLowerThumb = true
         return true
      }
      
      var upperThumbHitRect = UIEdgeInsetsInsetRect(upperThumbLayer.frame, trackingThumbInsets)
      if upperThumbHitRect.minX < middleBetweenThumbs {
         upperThumbHitRect.size.width = upperThumbHitRect.maxX - middleBetweenThumbs
         upperThumbHitRect.origin.x = middleBetweenThumbs
      }
      
		if upperThumbHitRect.contains(previousLocation) {
			trackingUpperThumb = true
         return true
		}
		
		return false
	}
 
	override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool
   {
		let location = touch.location(in: self)
		
		// 1. Determine by how much the user has dragged
		let deltaLocation = location.x - previousLocation.x
		let deltaValue = deltaLocation * valueInterval / slidingWidth
		
      var valueChanged = false
      
		// 2. Update the values
		if trackingLowerThumb
      {
         let value = lowerValue
         lowerValue = minmax(minimumValue, lowerValue + deltaValue, upperValue)
         valueChanged = (lowerValue != value)
		}
      else if trackingUpperThumb
      {
         let value = upperValue
         upperValue = minmax(lowerValue, upperValue + deltaValue, maximumValue)
         valueChanged = (upperValue != value)
		}
      
		// 3. Send Actions
      if continuous && valueChanged {
         sendActions(for: .valueChanged)
      }
      
      previousLocation = location
		
		return true
	}
	
	override func endTracking(_ touch: UITouch?, with event: UIEvent?)
   {
		trackingLowerThumb = false
		trackingUpperThumb = false
      sendActions(for: .valueChanged)
	}
   
   override var isTracking: Bool {
      return trackingLowerThumb || trackingUpperThumb
   }
}

