//
//  CreateVideoSpeedController.swift
//  MyBabyMy
//
//  Created by Dmitry on 23.01.17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import UIKit

enum VideoPhotoSpeed
{
   case slow
   case normal
   case fast
   case veryFast
   
   static let allValues = [slow, normal, fast, veryFast]
   static let photosSpeed : [VideoPhotoSpeed : Double] = [slow : 5, normal : 3, fast : 2, veryFast : 1]
   static let photosInDynamicSpeed : [VideoPhotoSpeed : Double] = [slow : 2, normal : 1, fast : 0.65, veryFast : 0.45]
   
   func speedValue(_ mediaType : BabyMediaType) -> Double
   {
      switch mediaType
      {
         case .photo: return VideoPhotoSpeed.photosSpeed[self]!
         case .photoInDynamics: return VideoPhotoSpeed.photosInDynamicSpeed[self]!
         default: return 0
      }
   }
   
   var description: String
   {
      switch self
      {
         case .slow: return loc("Slow")
         case .normal: return loc("Normal")
         case .fast: return loc("Fast")
         case .veryFast: return loc("Very fast")
      }
   }
}

class CreateVideoSpeedController: UITableViewController
{
   private var speedIndex : Int = VideoPhotoSpeed.allValues.index(of: VideoMaker.videoPhotoSpeed)!
   {
      didSet {
         VideoMaker.videoPhotoSpeed = VideoPhotoSpeed.allValues[speedIndex]
      }
   }
   
	override func viewDidLoad()
   {
      super.viewDidLoad()
      tableView.rowHeight = 63 * WidthRatio
   }

    // MARK: - Table view data source

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
   {
      tableView.deselectRow(at: indexPath, animated: true)
      
      let newSpeedIndex = indexPath.row
      guard newSpeedIndex != speedIndex else { return }
      
      if let cell = tableView.cellForRow(at: indexPath) as? VideoSpeedCell {
         cell.pickImageView.image = #imageLiteral(resourceName: "radioButtonChecked")
      }
      
      if let oldSelectedCell = tableView.cellForRow(at: IndexPath(row: speedIndex, section: 0)) as? VideoSpeedCell {
         oldSelectedCell.pickImageView.image = #imageLiteral(resourceName: "radioButtonEmpty")
      }
      
      speedIndex = newSpeedIndex
	}
   
   override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
   {
      return VideoPhotoSpeed.allValues.count
   }
   
   override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
   {
      let cell = tableView.dequeueReusableCell(withIdentifier: "VideoSpeedCell", for: indexPath) as! VideoSpeedCell
      
      let selected = (speedIndex == indexPath.row)
      cell.pickImageView.image = selected ? #imageLiteral(resourceName: "radioButtonChecked") : #imageLiteral(resourceName: "radioButtonEmpty")
      
      let cellSpeed = VideoPhotoSpeed.allValues[indexPath.row]
      let speedValue = cellSpeed.speedValue(VideoMaker.mediaType)
      
      cell.speedLabel.text = String(format: "\(cellSpeed.description) (\(loc("%g sec per photo")))", speedValue)
      
      return cell
   }
	
	// MARK: - Actions
	
   @IBAction func backTap(_ sender: Any) {
      _ = navigationController?.popViewController(animated: true)
   }

}


class VideoSpeedCell: UITableViewCell
{   
   @IBOutlet weak var speedLabel: UILabel!
	@IBOutlet weak var pickImageView: UIImageView!
}
