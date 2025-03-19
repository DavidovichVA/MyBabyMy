//
//  SettingsController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/6/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit
import MessageUI

class SettingsController: UIViewController, UITableViewDelegate, UITableViewDataSource, MFMailComposeViewControllerDelegate
{
   @IBOutlet weak var tableView: UITableView!
   @IBOutlet weak var usernameLabel: UILabel!
   @IBOutlet weak var usernameCenterVertically: NSLayoutConstraint!
   @IBOutlet weak var usernameAboveCenter: NSLayoutConstraint!   
   @IBOutlet weak var proAccountView: UIView!
   @IBOutlet weak var proDateLabel: UILabel!
   @IBOutlet weak var footerView: UIView!
   @IBOutlet weak var footerLabel: UILabel!
   
   private enum CellType
   {
      case socialNetworks
      case changePassword
      case proAccount
      case restorePurchases
      case sync
      case feedback
		case deletePro
      case logout
   }
   
   private var cellTypes : [CellType] = []
   
   private let normalColor = rgb(137, 141, 152)
   private let pinkColor = rgb(255, 120, 154)

   override func viewDidLoad()
   {
      super.viewDidLoad()
      tableView.rowHeight = round(66 * WidthRatio)
      tableView.tableFooterView = footerView
      setupUserProObserver()
   }
   
   override func viewWillAppear(_ animated: Bool)
   {
      super.viewWillAppear(animated)
      navigationController?.setNavigationBarHidden(true, animated: animated)
      update()
   }
   
   override var preferredStatusBarStyle: UIStatusBarStyle {
      return .lightContent
   }
   
   func update()
   {
      guard let user = User.current else { return }
      
      var username = user.email
      if username.isEmpty
      {
         if user.instagramConnected && !user.instagramName.isEmpty { username = user.instagramName }
         else if user.facebookConnected && !user.facebookName.isEmpty { username = user.facebookName }
         else if user.vkConnected && !user.vkName.isEmpty { username = user.vkName }
            
         else if user.facebookConnected && !user.facebookEmail.isEmpty { username = user.facebookEmail }
         else if user.vkConnected && !user.vkEmail.isEmpty { username = user.vkEmail }
         else if user.instagramConnected && !user.instagramEmail.isEmpty { username = user.instagramEmail }
      }
      usernameLabel.text = username
      
      proAccountView.isHidden = !user.isPro
      if user.isPro, let proDate = user.proExpirationTime
      {
         usernameCenterVertically.priority = 1
         usernameAboveCenter.priority = 500
         proDateLabel.text = String(format: loc("Valid until %@"), proDateFormatter.string(from: proDate))
      }
      else
      {
         usernameCenterVertically.priority = 500
         usernameAboveCenter.priority = 1
         proDateLabel.text = nil
      }
      
      cellTypes = [.socialNetworks]
      if user.authorizationWithEmail {
         cellTypes.append(.changePassword)
      }
      
      if user.isPro {
         cellTypes.append(contentsOf: [.proAccount, .restorePurchases, .sync, .feedback, /*.deletePro,*/ .logout])
      }
      else {
         cellTypes.append(contentsOf: [.proAccount, .restorePurchases, .sync, .feedback, .logout])
      }
      
      tableView.reloadData()
      
      footerView.height = max(floor(110 * WidthRatio), ScreenHeight - (160 * WidthRatio + CGFloat(cellTypes.count) * tableView.rowHeight + (tabBarController?.tabBar.height ?? 0)))
      footerLabel.text = AppName + " v" + AppVersion
      tableView.tableFooterView = footerView
   }
   
   //MARK: - Pro Observer
   
   private var userProObserver : NSObjectProtocol?
   
   private func setupUserProObserver()
   {
      userProObserver = NotificationCenter.default.addObserver(forName: .MBUserProChanged, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         if let currentUser = User.current, let user = notification.object as? User, user.id == currentUser.id {
            self.update()
         }
      }
   }
   
   deinit
   {
      if userProObserver != nil {
         NotificationCenter.default.removeObserver(userProObserver!)
      }
   }
   
   // MARK: Table view

   func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
      return cellTypes.count
   }
   
   func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
   {
      let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath) as! SettingsCell
      
      let cellType = cellTypes[indexPath.row]
      switch cellType
      {
      case .socialNetworks:
         cell.settingsImageView.image = #imageLiteral(resourceName: "settingsSocial")
         cell.settingsLabel.text = loc("Social Networks")
         cell.settingsLabel.textColor = normalColor
      case .changePassword:
         cell.settingsImageView.image = #imageLiteral(resourceName: "settingsPassword")
         cell.settingsLabel.text = loc("Change Password")
         cell.settingsLabel.textColor = normalColor
      case .proAccount:
         cell.settingsImageView.image = #imageLiteral(resourceName: "settingsPro")
         cell.settingsLabel.text = loc("Pro Account")
         cell.settingsLabel.textColor = pinkColor
      case .restorePurchases:
         cell.settingsImageView.image = #imageLiteral(resourceName: "settingsRestorePurchases")
         cell.settingsLabel.text = loc("Restore Purchases")
         cell.settingsLabel.textColor = normalColor
      case .sync:
         cell.settingsImageView.image = #imageLiteral(resourceName: "settingsSync")
         cell.settingsLabel.text = loc("Sync")
         cell.settingsLabel.textColor = normalColor
      case .feedback:
         cell.settingsImageView.image = #imageLiteral(resourceName: "settingsFeedback")
         cell.settingsLabel.text = loc("Feedback")
         cell.settingsLabel.textColor = normalColor
		case .deletePro:
         cell.settingsImageView.image = #imageLiteral(resourceName: "settingsLogout")
			cell.settingsLabel.text = "Remove Pro (Temp for testing)"
         cell.settingsLabel.textColor = normalColor
      case .logout:
         cell.settingsImageView.image = #imageLiteral(resourceName: "settingsLogout")
         cell.settingsLabel.text = loc("Logout")
         cell.settingsLabel.textColor = normalColor
      }
      
      let scale = WidthRatio
      cell.settingsImageView.transform = CGAffineTransform(scaleX: scale, y: scale)

      return cell
   }
   
   func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
   {
      let cellType = cellTypes[indexPath.row]
      switch cellType
      {
         case .socialNetworks:
            performSegue(withIdentifier: "Social Networks", sender: self)
         
         case .changePassword:
            performSegue(withIdentifier: "Change Password", sender: self)
            tableView.deselectRow(at: indexPath, animated: true)
         
		   case .proAccount:
            performSegue(withIdentifier: "Pro Account", sender: self)
         
         case .restorePurchases:
				showAppSpinner()
				restorePurchases()
				tableView.deselectRow(at: indexPath, animated: true)
         
         case .sync: tableView.deselectRow(at: indexPath, animated: true)
            performSegue(withIdentifier: "Sync", sender: self)         
         
		   case .feedback:
				let mailComposeViewController = configuredMailComposeViewController()
				if MFMailComposeViewController.canSendMail(){
					self.present(mailComposeViewController, animated: true, completion: nil)
				}
				tableView.deselectRow(at: indexPath, animated: true)
         
			case .deletePro:
				RequestManager.unSetPro(
            success:
            {
               if let user = User.current {
                  user.setPro(nil)
               }
            },
            failure: {error in AlertManager.showAlert(title: loc("Error"), message: error)})

         case .logout: AppDelegate.logout()
      }
   }
	
	
	func configuredMailComposeViewController () -> MFMailComposeViewController
   {
		let mailComposeVC = MFMailComposeViewController()
		mailComposeVC.mailComposeDelegate = self
		mailComposeVC.setToRecipients(["mybabymy.app@gmail.com"])
		mailComposeVC.setSubject("MyBabyMy feedback")
      //mailComposeVC.setMessageBody("Hi, this is my feedback\n", isHTML: false)
		return mailComposeVC
	}
   
	func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
   {
		switch result {
		case MFMailComposeResult.sent:
			controller.dismiss(animated: true, completion: {
				AlertManager.showAlert(loc("Thanks for your feedback"))
			})
		case MFMailComposeResult.failed:
			controller.dismiss(animated: true, completion:
         {
            if let errorDescription = error?.localizedDescription, !errorDescription.isEmpty {
               AlertManager.showAlert(title: loc("Failed to send mail"), message: errorDescription)
            }
            else {
               AlertManager.showAlert(loc("Failed to send mail"))
            }
			})
			
		default: controller.dismiss(animated: true, completion: nil)
		}
	}
	
   func restorePurchases()
   {
      guard let user = User.current else { return }
      restorePurchases(Array<Purchase>(user.purchasesQueue), userId : user.id)
   }
   
   private func restorePurchases(_ pendingPurchases : [Purchase], userId : Int)
	{
		if let purchase = pendingPurchases.first
		{
			RequestManager.purchasePro(purchase,
         success:
         {
            [weak self] in
            dlog("purchased")
            if let user = User.current, user.id == userId
            {
               var pendingPurchases = pendingPurchases
               pendingPurchases.removeFirst()
               self?.restorePurchases(pendingPurchases, userId: userId)
            }
			},
         failure:
         {
            [weak self]
            errorDescription in
            dlog(errorDescription)
            if let user = User.current, user.id == userId
            {
               var pendingPurchases = pendingPurchases
               pendingPurchases.removeFirst()
               self?.restorePurchases(pendingPurchases, userId: userId)
            }
			})
		}
      else
		{
			RequestManager.updateUserData(
         success:
         {
            guard let user = User.current, user.id == userId else { return }
            
            if let expirationDate = user.proExpirationTime
            {               
               let str = String(format: loc("You got pro account till %@"), proDateFormatter.string(from: expirationDate))
               AlertManager.showAlert(str)
            }
            else
            {
               AlertManager.showAlert(loc("You have no purchases"))
            }
            hideAppSpinner()
			},
			failure:
         {
            error in
            dlog(error)
            hideAppSpinner()
			})
		}
	}
	
}

class SettingsCell : UITableViewCell
{  
   @IBOutlet weak var settingsImageView: UIImageView!   
   @IBOutlet weak var settingsLabel: UILabel!
}
