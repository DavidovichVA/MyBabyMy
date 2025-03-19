//
//  MBMSlider.swift
//  MyBabyMy
//
//  Created by Dmitry on 20.01.17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import UIKit

let sliderThumbImage = #imageLiteral(resourceName: "sliderThumb").scaled(by: WidthRatio)
let sliderTrackHeight = 4.5 * WidthRatio

class MBMSlider : UISlider
{
	override func trackRect(forBounds bounds: CGRect) -> CGRect
   {
		//keeps original origin and width, changes height
		let customBounds = CGRect(x: 0, y: bounds.height/2 - sliderTrackHeight/2, width: bounds.size.width, height: sliderTrackHeight)
		return customBounds
	}
	
	override func awakeFromNib()
   {
      super.awakeFromNib()
		self.setThumbImage(sliderThumbImage, for: .normal)
	}
}
