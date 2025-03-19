//
//  Spinner.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 3/9/17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import MBProgressHUD

let appSpinnerImage : UIImage? = UIImage.gif("spinner", size: CGSize.square(round(120 * WidthRatio)))

@discardableResult
func showAppSpinner(addedTo view: UIView = AppWindow, animated: Bool = true, dimBackground: Bool = true) -> MBProgressHUD
{
   if let hud = MBProgressHUD(for: view)
   {
      hud.show(animated: animated)
      return hud
   }
   
   let hud = MBProgressHUD(view: view)
   
   let imageView = UIImageView(image: appSpinnerImage)
   imageView.backgroundColor = UIColor.clear
   
   hud.customView = imageView
   hud.mode = .customView
   
   hud.removeFromSuperViewOnHide = true
   hud.margin = 0
   hud.backgroundView.style = .solidColor
   hud.backgroundView.color = dimBackground ? UIColor.gray.withAlphaComponent(0.25) : UIColor.clear
   hud.bezelView.style = .solidColor
   hud.bezelView.color = UIColor.clear
   hud.bezelView.backgroundColor = UIColor.clear
   hud.bezelView.clipsToBounds = false
   
   view.addSubview(hud)
   hud.show(animated: animated)
   return hud
}

func hideAppSpinner(for view: UIView = AppWindow, animated: Bool = true)
{
   MBProgressHUD.hide(for: view, animated: animated)
}
