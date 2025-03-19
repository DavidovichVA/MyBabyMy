//
//  ForgotPasswordController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/2/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit

class ForgotPasswordController: UIViewController
{
   @IBOutlet weak var scrollview: UIScrollView!
   @IBOutlet weak var emailTextField: UITextField!   
   
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
      let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideKeyboardTap))
      view.addGestureRecognizer(tapRecognizer)
      
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
            self.scrollview.contentInset = UIEdgeInsets.zero
         }
         else
         {
            self.scrollview.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardRect.size.height, right: 0)
            if let activeView = self.activeInputView {
               self.scrollview.scrollViewToVisible(activeView, animated: false)
            }
         }
         
         UIView.commitAnimations()
      }
   }
   
   @objc private func hideKeyboardTap()
   {
      if activeInputView != nil {
         view.endEditing(true)
      }
      else {
         dismiss(animated: true, completion: nil)
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
      guard let login = emailTextField.text, !login.isEmpty else {
         return loc("Please enter email address")
      }
      if let errorDesc = emailCheck(login) { return errorDesc }
      
      return nil
   }
   
   private func restorePassword(email : String)
   {
      RequestManager.restorePassword(email: email, success:
      {
         AlertManager.showAlert(loc("Instructions for password recovery were sent to your email"), completion: {
            self.dismiss(animated: true, completion: nil)
         })
      })
   }
   
   //MARK: - Actions
   
   @IBAction func cancelTap()
   {
      dismiss(animated: true, completion: nil)
   }
   
   @IBAction func sendTap()
   {
      view.endEditing(true)
      
      if let errorDesc = validateInput()
      {
         AlertManager.showAlert(errorDesc)
         return
      }
      
      let email = emailTextField.text!
      restorePassword(email: email)
   }
   
   //MARK: - TextField
   
   public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool
   {
      activeInputView = textField
      return true
   }
   
   public func textFieldDidEndEditing(_ textField: UITextField)
   {
      if activeInputView == textField {
         activeInputView = nil
      }
   }
   
   public func textFieldShouldReturn(_ textField: UITextField) -> Bool
   {
      view.endEditing(true)
      return true
   }
}
