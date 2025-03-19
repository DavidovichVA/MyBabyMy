//
//  CreateVideoExtraSettingsController.swift
//  MyBabyMy
//
//  Created by Dmitry on 23.01.17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import UIKit

class CreateVideoExtraSettingsController: UIViewController, UITableViewDelegate, UITableViewDataSource
{
   @IBOutlet weak var musicLabel: UILabel!
   @IBOutlet weak var showAgeSwitch: UISwitch!
   @IBOutlet weak var videoSpeedView: UIView!
   @IBOutlet weak var videoSpeedLabel: UILabel!
   @IBOutlet weak var resolutionView: UIView!
   @IBOutlet weak var resolutionTableView: UITableView!
   @IBOutlet weak var resolutionToVideoSpeedConstraint: NSLayoutConstraint!
   @IBOutlet weak var resolutionToAgeConstraint: NSLayoutConstraint!
   
	override func viewWillAppear(_ animated: Bool)
	{
		super.viewWillAppear(animated)
      
      if let navigationBar = navigationController?.navigationBar
      {
         navigationBar.setBackgroundImage(nil, for: UIBarMetrics.default)
         navigationBar.barTintColor = UIColor.white
         navigationBar.isTranslucent = false
         navigationBar.tintColor = rgb(191, 182, 184)
         navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: rgb(255, 120, 154), NSFontAttributeName : UIFont.systemFont(ofSize: 12, weight: UIFontWeightMedium)]
      }
      
      musicLabel.text = VideoMaker.selectedMusicTitle
      showAgeSwitch.isOn = VideoMaker.showAge
      videoSpeedView.isHidden = (VideoMaker.mediaType == .video)
      videoSpeedLabel.text = VideoMaker.videoPhotoSpeed.description
      
      if videoSpeedView.isHidden {
         resolutionToVideoSpeedConstraint.priority = 1
         resolutionToAgeConstraint.priority = 999
      }
      else {
         resolutionToVideoSpeedConstraint.priority = 999
         resolutionToAgeConstraint.priority = 1
      }
      resolutionTableView.rowHeight = 65 * WidthRatio
      resolutionView.isHidden = (VideoMaker.mediaType == .photoInDynamics)
	}
   
   // MARK: - Table view
   
   func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
      return VideoResolution.allValues.count
   }
   
   func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
   {
      let cell = tableView.dequeueReusableCell(withIdentifier: "VideoResolutionCell", for: indexPath) as! VideoResolutionCell
      
      let resolution = VideoResolution.allValues[indexPath.row]
      cell.resolutionLabel.text = resolution.rawValue
      let selected : Bool = (VideoMaker.selectedVideoSize == resolution)
      cell.checkImageView.image = (selected ? #imageLiteral(resourceName: "radioButtonChecked") : #imageLiteral(resourceName: "radioButtonEmpty"))
      
      return cell
   }
   
   func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
   {
      tableView.deselectRow(at: indexPath, animated: true)
      
      let resolution = VideoResolution.allValues[indexPath.row]
      VideoMaker.selectedVideoSize = resolution
      
      if let indexPaths = tableView.indexPathsForVisibleRows
      {
         for visibleIndexPath in indexPaths
         {
            if let cell = tableView.cellForRow(at: visibleIndexPath) as? VideoResolutionCell
            {
               let selected : Bool = (visibleIndexPath == indexPath)
               cell.checkImageView.image = (selected ? #imageLiteral(resourceName: "radioButtonChecked") : #imageLiteral(resourceName: "radioButtonEmpty"))
            }
         }
      }
   }
   
   // MARK: - Actions
   
   @IBAction func backTap(_ sender: UIBarButtonItem) {
      _ = navigationController?.popViewController(animated: true)
   }
   
   @IBAction func createTap()
   {
      VideoMaker.start(presentingController: self)
   }
   
   @IBAction func showAgeSwitched()
   {
      VideoMaker.showAge = showAgeSwitch.isOn
   }
}


class VideoResolutionCell : UITableViewCell
{
   @IBOutlet weak var resolutionLabel: UILabel!
   @IBOutlet weak var checkImageView: UIImageView!
}

