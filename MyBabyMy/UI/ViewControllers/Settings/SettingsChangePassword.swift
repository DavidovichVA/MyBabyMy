//
//  SettingsChangePassword.swift
//  MyBabyMy
//
//  Created by Dmitry on 04.01.17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import UIKit

class SettingsChangePassword: UIViewController {


	@IBOutlet weak var scrollView: UIScrollView!
	@IBOutlet weak var confirmPasswordField: UITextField!
	@IBOutlet weak var newPasswordField: UITextField!
	@IBOutlet weak var currentPasswordField: UITextField!
	
   override func viewDidLoad()
   {
      super.viewDidLoad()
	   setupForKeyboard()
   }
   
	//MARK: - Keyboard
	private var keyboardObserver : NSObjectProtocol?
	private var activeInputView : UIView?
	private func setupForKeyboard()
	{
		keyboardObserver = NotificationCenter.default.addObserver(forName: .UIKeyboardWillChangeFrame, object: nil, queue: OperationQueue.main)
		{
         [unowned self]
         notification in
			let keyboardRect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
			let duration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
			let curve = UIViewAnimationCurve(rawValue: (notification.userInfo?[UIKeyboardAnimationCurveUserInfoKey] as! NSNumber).intValue)!
			
			let keyboardWillHide = (keyboardRect.origin.y >= ScreenHeight)
			
			UIView.beginAnimations(nil, context: nil)
			UIView.setAnimationDuration(duration)
			UIView.setAnimationCurve(curve)
			
			if keyboardWillHide {
				self.scrollView.contentInset = UIEdgeInsets.zero
			}
			else
			{
				self.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardRect.size.height, right: 0)
				if let activeView = self.activeInputView {
					self.scrollView.scrollViewToVisible(activeView, animated: false)
				}
			}
			
			UIView.commitAnimations()
		}
	}
	
   deinit {
      if keyboardObserver != nil {
         NotificationCenter.default.removeObserver(keyboardObserver!)
      }
   }

   //MARK: - Methods
   
   private func validateInput() -> String?
   {
      let currentPassword = currentPasswordField.text
      let newPassword = newPasswordField.text
      let confirmPassword = confirmPasswordField.text
      
      if isNilOrEmpty(currentPassword) || isNilOrEmpty(newPassword) { return loc("Please enter password")}
      if let errorDesc = passwordCheck(newPassword!) { return errorDesc}
      if isNilOrEmpty(confirmPassword) { return loc("Please confirm password")}
      if newPassword != confirmPassword { return loc("Password does not match confirm password")}
      if newPassword == currentPassword { return loc("Current and new passwords are identical")}
      
      return nil
   }
   
   private func changePassword(oldPassword: String, newPassword : String)
   {
      RequestManager.editPass(oldPassword: oldPassword, newPassword: newPassword, success:
      {
         AlertManager.showAlert(loc("Password changed"), completion: { 
            self.dismiss(animated: true, completion: nil)
         })
      },
      failure:
      {
         errorDescription in
         AlertManager.showAlert(errorDescription)
      })
   }
   
   
	//MARK: - Actions

	@IBAction func backgroundTapped(_ sender: UITapGestureRecognizer)
   {
      if self.activeInputView == nil {
         self.dismiss(animated: true, completion: nil)
      }
		else {
			self.view.endEditing(true)
		}
	}

	@IBAction func confirmButtonTapped(_ sender: Any)
   {
      view.endEditing(true)
      
      if let errorDesc = validateInput()
      {
         AlertManager.showAlert(errorDesc)
         return
      }
      
      let oldPassword = currentPasswordField.text ?? ""
      let newPassword = newPasswordField.text ?? ""
      
      changePassword(oldPassword: oldPassword, newPassword : newPassword)
	}
	
	//MARK: - TextField
	
	public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool
	{
		self.activeInputView = textField
		return true
	}
	
	public func textFieldDidEndEditing(_ textField: UITextField)
	{
		if activeInputView == textField {
			self.activeInputView = nil
		}
	}
	
	public func textFieldShouldReturn(_ textField: UITextField) -> Bool
	{
		view.endEditing(true)
		return true
	}
}
