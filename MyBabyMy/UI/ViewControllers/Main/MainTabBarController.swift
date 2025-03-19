//
//  MainTabBarController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/6/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit

fileprivate let videoButtonSize : CGSize = CGSize.square(82 * WidthRatio)

class MainTabBarController: UITabBarController
{
   override func viewDidLoad()
   {
      super.viewDidLoad()
      
      let videoButton = UIButton(type: .custom)
      videoButton.setTitle(nil, for: .normal)
      videoButton.setImage(#imageLiteral(resourceName: "videoButtonImage"), for: .normal)
      videoButton.addTarget(self, action: #selector(videoButtonTap), for: .touchUpInside)
      
      videoButton.contentMode = .scaleAspectFill
      videoButton.contentHorizontalAlignment = .fill
      videoButton.contentVerticalAlignment = .fill
      videoButton.imageView?.contentMode = .scaleAspectFill
      videoButton.imageView?.clipsToBounds = false
      videoButton.clipsToBounds = false
      
      tabBar.addSubview(videoButton)
      (tabBar as! MainTabBar).videoButton = videoButton
      tabBar.setNeedsLayout()
   }
   
   @objc private func videoButtonTap()
   {
      guard let user = User.current else { return }
      VideoMaker.persona = user.mainPersona
      if let main = mainController {
         VideoMaker.mediaType = main.displayedMediaType
      }
      performSegue(withIdentifier: "createVideo", sender: self)
   }
}


class MainTabBar: UITabBar
{
   var videoButton : UIButton!
   
   override func point(inside point: CGPoint, with event: UIEvent?) -> Bool
   {
      return super.point(inside: point, with: event) || videoButton.frame.contains(point)
   }
   
   override func layoutSubviews()
   {
      super.layoutSubviews()
      videoButton.frame = CGRect(origin: CGPoint(x: bounds.width / 2 - videoButtonSize.width / 2,
                                                 y: bounds.height - videoButtonSize.height - 26.4 * (1 - min(1, WidthRatio))),
                                 size: videoButtonSize)
      bringSubview(toFront: videoButton)
   }
}

