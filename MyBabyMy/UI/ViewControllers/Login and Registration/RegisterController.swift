//
//  RegisterController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/1/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit

class RegisterController: UIViewController, UITextFieldDelegate
{
   @IBOutlet weak var scrollview: UIScrollView!
   @IBOutlet weak var emailTextField: UITextField!
   @IBOutlet weak var passwordTextField: UITextField!
   @IBOutlet weak var confirmTextField: UITextField!
   
   @IBOutlet weak var registerButton: UIButton!
   
   @IBOutlet weak var errorView: UIView!
   @IBOutlet weak var errorLabel: UILabel!
   
   
    override func viewDidLoad()
    {
      super.viewDidLoad()
      errorView.alpha = 0
      setupForKeyboard()
      updateRegisterButton()
    }

   override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)
      navigationController?.setNavigationBarHidden(false, animated: animated)
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
   
   @objc private func hideKeyboardTap() {
      view.endEditing(true)
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
      
      guard let password = passwordTextField.text, !password.isEmpty else {
         return loc("Please enter password")
      }
      if let errorDesc = passwordCheck(password) { return errorDesc }
      
      guard let confirmPassword = confirmTextField.text, !confirmPassword.isEmpty else {
         return loc("Please confirm password")
      }
      if password != confirmPassword { return loc("Password does not match confirm password")}
      
      return nil
   }
   
   private func showErrorMessage(_ message : String, time : TimeInterval)
   {
      let errorKey = showErrorMessage(message)
      delay(time)
      {
         if errorKey == self.errorMessageKey {
            self.hideErrorMessage()
         }
      }
   }

   private var errorMessageKey : String = ""
   private func showErrorMessage(_ message : String) -> String
   {
      errorLabel.text = message

      UIView.animateIgnoringInherited(withDuration: 0.4, animations:{
         self.errorView.alpha = 1
      })
      
      errorMessageKey = NSUUID().uuidString
      return errorMessageKey
   }
   
   private func hideErrorMessage()
   {
      UIView.animateIgnoringInherited(withDuration: 0.4, animations: {
         self.errorView.alpha = 0
      },
      completion: { finished in
         self.errorLabel.text = ""
      })
      
      errorMessageKey = ""
   }

   private func updateRegisterButton()
   {
      let isEmptyFields = isNilOrEmpty(emailTextField.text) || isNilOrEmpty(passwordTextField.text) || isNilOrEmpty(confirmTextField.text)
      if isEmptyFields {
         registerButton.setTitleColor(rgb(137, 141, 152), for: .normal)
         registerButton.isEnabled = false
      }
      else {
         registerButton.setTitleColor(rgb(255, 120, 154), for: .normal)
         registerButton.isEnabled = true
      }
   }
   
   private func register(login: String, password : String)
   {
      showAppSpinner()
      
      RequestManager.register(email: login, password: password,
      success:
      {
         user in         
         User.current = user
         user.modifyWithTransactionIfNeeded {
            user.authorizationWithEmail = true
            user.email = login
         }
         
         if user.acceptedUserAgreements
         {
            RequestManager.updateUserData(
            success:
            {
               hideAppSpinner()
               
               if user.personas.isEmpty {
                  AppWindow.rootViewController = Storyboard.instantiateViewController(withIdentifier: "PersonaEditController")
               }
               else {
                  AppWindow.rootViewController = Storyboard.instantiateViewController(withIdentifier: "MainTabBarController")
               }
            },
            failure:
            {
               errorDescription in
               hideAppSpinner()
               self.showErrorMessage(errorDescription, time: 10)
            })
         }
         else
         {
            hideAppSpinner()
            self.performSegue(withIdentifier: "ShowTerms", sender: self)
         }
      },
      failure: {
         errorDescription in
         hideAppSpinner()
         self.showErrorMessage(errorDescription, time: 10)
      })
   }
   
   //MARK: - Actions
   
   @IBAction func backTap(_ sender: UIBarButtonItem) {
      _ = navigationController?.popViewController(animated: true)
   }
   
   @IBAction func registerTap()
   {
      view.endEditing(true)
      
      if let errorDesc = validateInput()
      {
         showErrorMessage(errorDesc, time: 5)
         return
      }
      
      let login = emailTextField.text ?? ""
      let password = passwordTextField.text ?? ""
      
      register(login: login, password: password)
   }
   
   
   //MARK: - TextField
   
   @IBAction func textFieldEditingChanged(_ sender: UITextField)
   {
      updateRegisterButton()
   }
   
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
      switch textField {
      case emailTextField:
         if isNilOrEmpty(passwordTextField.text) {
            passwordTextField.becomeFirstResponder()
         }
         else if isNilOrEmpty(confirmTextField.text) {
            confirmTextField.becomeFirstResponder()
         }
         else {
            view.endEditing(true)
         }
      case passwordTextField:
         if isNilOrEmpty(confirmTextField.text) {
            confirmTextField.becomeFirstResponder()
         }
         else if isNilOrEmpty(emailTextField.text) {
            emailTextField.becomeFirstResponder()
         }
         else {
            view.endEditing(true)
         }
      case confirmTextField:
         if isNilOrEmpty(emailTextField.text) {
            emailTextField.becomeFirstResponder()
         }
         else if isNilOrEmpty(passwordTextField.text) {
            passwordTextField.becomeFirstResponder()
         }
         else {
            view.endEditing(true)
         }
      default: break;
      }
      
      return true
   }
}

func emailCheck(_ email : String) -> String?
{
   if !email.isValidEmail { return loc("Incorrect email address")}
   
   let charactersCount = email.characters.count
   if charactersCount < 8 { return loc("Email must be at least 8 characters long")}
   if charactersCount > 35 { return loc("Email must be no more than 35 characters long")}
   
   return nil
}

func passwordCheck(_ password : String) -> String?
{
   if password.characters.count < 6 { return loc("Password must be at least 6 characters long")}
   if password.characters.count > 18 { return loc("Password must be no more than 18 characters long")}
   
   let letters = CharacterSet.letters
   let digits = CharacterSet.decimalDigits
   var letterCount = 0
   var digitCount = 0
   for uni in password.unicodeScalars
   {
      if letters.contains(uni) {
         letterCount += 1
      }
      else if digits.contains(uni) {
         digitCount += 1
      }
      else {
         return loc("Password must contain letters and digits only")
      }
   }
   if letterCount == 0 { return loc("Password must contain at least one letter")}
   if digitCount == 0 { return loc("Password must contain at least one digit")}
   
   return nil
}
