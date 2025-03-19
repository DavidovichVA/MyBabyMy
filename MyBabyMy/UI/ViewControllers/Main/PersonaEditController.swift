//
//  PersonaEditController.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/2/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit
import RealmSwift

class PersonaEditController: UIViewController, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource
{
   public var editedPersona : Persona?
   
   @IBOutlet weak var avatarContainerView: UIView!
   @IBOutlet weak var avatarImageView: UIImageView!
   
   @IBOutlet weak var scrollview: UIScrollView!   
   @IBOutlet weak var futureMomButton: UIButton!
   @IBOutlet weak var momButton: UIButton!
   @IBOutlet weak var futureMomLabel: UILabel!
   @IBOutlet weak var momLabel: UILabel!   
   @IBOutlet weak var babyNameView: UIView!
   @IBOutlet weak var babyNameLabel: UILabel!
   @IBOutlet weak var babyBirthdayView: UIView!
   @IBOutlet weak var babyBirthdayLabel: UILabel!
   @IBOutlet weak var momPregnancyWeekView: UIView!
   @IBOutlet weak var momPregnancyWeekLabel: UILabel!
   @IBOutlet weak var momBeginningOfWeekView: UIView!   
   @IBOutlet weak var momBeginningOfWeekLabel: UILabel!
   @IBOutlet weak var deleteButton: UIButton!
   @IBOutlet weak var createButton: UIButton!
   @IBOutlet weak var bottomButton: UIButton!
   
   @IBOutlet weak var pickersTitleLabel: UILabel!
   @IBOutlet weak var babyNameTextField: UITextField!
   @IBOutlet weak var birthdayDatePicker: UIDatePicker!
   @IBOutlet weak var pregnancyWeekPicker: UIPickerView!   
   @IBOutlet weak var beginningOfWeekPicker: UIPickerView!
   
   //model for fields and pickers
   private var babyName : String?
   private var babyBirthday : DMYDate?
   private var pregnancyStartDate : DMYDate?
   
   private var personaStatusChanged : Bool
   {
      if let persona = editedPersona
      {
         return (persona.status == .pregnant) != isFutureMom
      }
      else {
         return false
      }
   }
   
   private var personaFieldsChanged : Bool
   {
      if let persona = editedPersona
      {
         if isFutureMom {
            return (pregnancyStartDate != persona.pregnancyStartDate)
         }
         else {
            return (babyName != persona.name) || (babyBirthday != persona.birthday)
         }
      }
      else {
         return false
      }
   }
   
   private var dateFormatter : DateFormatter = DateFormatter()
   private var pickersShown = false
   
   private var currentPicker : FieldType = .babyName {
      didSet
      {
         switch currentPicker {
         case .babyName:
            babyNameTextField.isHidden = false
            birthdayDatePicker.isHidden = true
            pregnancyWeekPicker.isHidden = true
            beginningOfWeekPicker.isHidden = true
            pickersTitleLabel.text = loc("BABY NAME")
         case .babyBirthday:
            babyNameTextField.isHidden = true
            birthdayDatePicker.isHidden = false
            pregnancyWeekPicker.isHidden = true
            beginningOfWeekPicker.isHidden = true
            pickersTitleLabel.text = loc("BIRTHDAY")
         case .pregnancyWeek:
            babyNameTextField.isHidden = true
            birthdayDatePicker.isHidden = true
            pregnancyWeekPicker.isHidden = false
            beginningOfWeekPicker.isHidden = true
            pickersTitleLabel.text = loc("CURRENT PREGNANCY WEEK")
         case .beginningOfWeek:
            babyNameTextField.isHidden = true
            birthdayDatePicker.isHidden = true
            pregnancyWeekPicker.isHidden = true
            beginningOfWeekPicker.isHidden = false
            pickersTitleLabel.text = loc("BEGINNING OF WEEK")
         }
      }
   }
   
   private enum FieldType {
      case babyName
      case babyBirthday
      case pregnancyWeek
      case beginningOfWeek
   }
   
   ///  mom / future mom
   private var isFutureMom : Bool = false {
      didSet
      {
         if isFutureMom
         {
            futureMomButton.setImage(UIImage(named: "futureMomSelected"), for: .normal)
            momButton.setImage(UIImage(named: "momUnselected"), for: .normal)
            
            futureMomLabel.textColor = rgb(255, 120, 154)
            momLabel.textColor = rgb(137, 141, 152)
               
            babyNameView.isHidden = true
            babyBirthdayView.isHidden = true
            momPregnancyWeekView.isHidden = false
            momBeginningOfWeekView.isHidden = false
         }
         else
         {
            futureMomButton.setImage(UIImage(named: "futureMomUnselected"), for: .normal)
            momButton.setImage(UIImage(named: "momSelected"), for: .normal)
            
            futureMomLabel.textColor = rgb(137, 141, 152)
            momLabel.textColor = rgb(255, 120, 154)
               
            babyNameView.isHidden = false
            babyBirthdayView.isHidden = false
            momPregnancyWeekView.isHidden = true
            momBeginningOfWeekView.isHidden = true
         }
      }
   }
   
   override func viewDidLoad()
   {
      super.viewDidLoad()
      
      birthdayDatePicker.locale = locale
      birthdayDatePicker.calendar = calendar
      birthdayDatePicker.setValue(rgb(84, 93, 120), forKeyPath: "textColor")
      birthdayDatePicker.setValue(false, forKeyPath: "highlightsToday")
      dateFormatter.locale = locale
      dateFormatter.calendar = calendar
      dateFormatter.timeStyle = .none
      dateFormatter.dateStyle = .short
      
      let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideKeyboardTap))
      view.addGestureRecognizer(tapRecognizer)
      
      updateForPersona()
   }

   //MARK: - Methods
 
   private func showPickers() {
      scrollview.setContentOffset(CGPoint(x : scrollview.width, y : 0), animated: true)
      pickersShown = true
   }
   
   private func hidePickers() {
      scrollview.setContentOffset(CGPoint.zero, animated: true)
      pickersShown = true
   }
   
   private func updateForPersona()
   {
      if let persona = editedPersona
      {
         avatarContainerView.isHidden = false
         deleteButton.isHidden = false
         createButton.isHidden = true
         
         isFutureMom = (persona.status == .pregnant)
         let deletePossible = (persona.user.personas.count > 1)
         if deletePossible {
            deleteButton.setTitleColor(rgb(137, 141, 152), for: .normal)
            deleteButton.isEnabled = true
         }
         else {
            deleteButton.setTitleColor(rgb(204, 208, 221), for: .normal)
            deleteButton.isEnabled = false
         }
         
         bottomButton.setImage(#imageLiteral(resourceName: "checkPinkIcon"), for: .normal)
         bottomButton.addTarget(self, action: #selector(confirmTap), for: .touchUpInside)
         
         babyName = persona.name
         babyBirthday = persona.birthday
         pregnancyStartDate = persona.pregnancyStartDate
         
         if let lastMedia = persona.lastMedia
         {
            lastMedia.getThumbnailImage {
               image in
               self.avatarImageView.image = image ?? #imageLiteral(resourceName: "defaultAvatar")
            }
         }
         else {
            avatarImageView.image = #imageLiteral(resourceName: "defaultAvatar")
         }
         
         editedPersona!.addObserver(self, forKeyPath: "invalidated", context: nil)
      }
      else
      {
         avatarContainerView.isHidden = true
         deleteButton.isHidden = true
         createButton.isHidden = false
         isFutureMom = true
         
         bottomButton.setImage(#imageLiteral(resourceName: "closePinkIcon"), for: .normal)
         bottomButton.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
      }
      
      updateFields(.babyName, .babyBirthday, .pregnancyWeek, .beginningOfWeek)
   }
   
   private func updateFromCurrentField()
   {
      switch currentPicker
      {
      case .babyName:
         babyName = babyNameTextField.text
      case .babyBirthday:
         babyBirthday = DMYDate.fromDate(birthdayDatePicker.date)
      case .pregnancyWeek, .beginningOfWeek:
         let pregnancyWeek = pregnancyWeekPicker.selectedRow(inComponent: 0) + 5
         let offsetFromCurrentWeekday = beginningOfWeekPicker.selectedRow(inComponent: 0)
         pregnancyStartDate = DMYDate.fromDate(Date().addingDays(offsetFromCurrentWeekday - 7 * pregnancyWeek))
      }
      
      updateFields(currentPicker)
   }
   
   private func updateFields(_ fields : FieldType...)
   {
      let currentDate = Date()
      
      if fields.contains(.babyName)
      {
         babyNameLabel.text = isNilOrEmpty(babyName) ? " " : babyName
         babyNameTextField.text = babyName
      }
      
      if fields.contains(.babyBirthday)
      {
         let text = babyBirthday?.description
         babyBirthdayLabel.text = isNilOrEmpty(text) ? " " : text
         birthdayDatePicker.date = babyBirthday?.getDate() ?? currentDate
      }
      
      if fields.contains(.pregnancyWeek) || fields.contains(.beginningOfWeek)
      {
         if let startDate = pregnancyStartDate?.getDate()
         {
            let components : Set<Calendar.Component> = [.day]
            let dateComponents = calendar.dateComponents(components, from: startDate, to: currentDate)
            
            let pregnancyDays = dateComponents.day!
            let pregnancyWeek: Int = minmax(5, Int(ceil(Double(pregnancyDays) / 7)), 39)
            
            //Sunday 1, Monday 2, Tuesday 3, Wednesday 4, Thursday 5, Friday 6, Saturday 7
            let pregnancyBeginWeekDay = calendar.component(.weekday, from: startDate)
            
            momPregnancyWeekLabel.text = String(pregnancyWeek)
            pregnancyWeekPicker.selectRow(pregnancyWeek - 5, inComponent: 0, animated: false)
            
            let weekdayNum = calendar.component(.weekday, from: currentDate)
            var weekdayRow = pregnancyBeginWeekDay - weekdayNum
            if weekdayRow < 0 { weekdayRow += 7 }
            beginningOfWeekPicker.selectRow(weekdayRow, inComponent: 0, animated: false)
            
            let beginningOfWeekDate = currentDate.addingDays(weekdayRow - 7)
            momBeginningOfWeekLabel.text = DMYDateFormatter.string(from: beginningOfWeekDate)
         }
         else
         {
            momPregnancyWeekLabel.text = " "
            pregnancyWeekPicker.selectRow(0, inComponent: 0, animated: false)
            momBeginningOfWeekLabel.text = " "
            beginningOfWeekPicker.selectRow(0, inComponent: 0, animated: false)
         }
      }
   }
   
   /*
   private func updateBottomButtonVisibility()
   {
      if editedPersona != nil {
         bottomButton.isHidden = !personaStatusChanged
      }
      else {
         bottomButton.isHidden = false
      }
   }
   */
   
   private func validateInput() -> Bool
   {
      var errorDesc = ""
      
      if isFutureMom
      {
         if pregnancyStartDate == nil {errorDesc = loc("Please enter pregnancy week")}
      }
      else
      {
         if isNilOrEmpty(babyName) {errorDesc = loc("Please enter baby name")}
         else if babyBirthday == nil {errorDesc = loc("Please enter baby birthday")}
      }
      
      if errorDesc.isEmpty {
         return true
      }
      else {
         AlertManager.showAlert(errorDesc)
         return false
      }
   }
   
   private func createNewPersona()
   {
      var name : String
      var date : DMYDate
      var status : PersonaStatus
      
      if isFutureMom
      {
         name = babyName ?? editedPersona?.name ?? ""
         date = pregnancyStartDate!
         status = .pregnant
      }
      else
      {
         name = babyName!
         date = babyBirthday!
         status = .baby
      }
      
      createPersona(name: name, date: date, status: status)
   }
   
   private func createPersonaOrChangeExistingStatus()
   {
      guard !isFutureMom else { createNewPersona(); return }
      
      let pregnants = User.current!.personas.filter {
         persona in
         persona.status == .pregnant && persona.pregnancyStartDate != nil
      }
      guard !pregnants.isEmpty else { createNewPersona(); return }
      
      
      let alertController = UIAlertController(title: nil, message: loc("Create baby from existing pregnancy?"), preferredStyle: .actionSheet)
      
      let cancel = UIAlertAction(title: loc("CANCEL"), style: .cancel)
      alertController.addAction(cancel)
      
      let createNew = UIAlertAction(title: loc("CREATE NEW"), style: .default, handler: {
         _ in
         self.createNewPersona()
      })
      alertController.addAction(createNew)
      
      for persona in pregnants
      {
         let title = String(format: loc("Pregnancy started on %@"), persona.pregnancyStartDate!.description)
         let action = UIAlertAction(title: title, style: .default, handler: {
            _ in
            self.editPersona(persona, name: self.babyName!, date: self.babyBirthday!, status: .baby, closeOnCompletion: false)
         })
         alertController.addAction(action)
      } 
      
      AlertManager.showAlert(alertController)
   }
   
   private func editPersonaData(closeOnCompletion : Bool)
   {
      guard let persona = editedPersona else { return }
      if !validateInput() { return }
      
      var name : String
      var date : DMYDate
      var status : PersonaStatus
      
      if isFutureMom
      {
         name = babyName ?? editedPersona?.name ?? ""
         date = pregnancyStartDate!
         status = .pregnant
      }
      else
      {
         name = babyName!
         date = babyBirthday!
         status = .baby
      }
      
      editPersona(persona, name: name, date: date, status: status, closeOnCompletion: closeOnCompletion)
   }
   
   private func deletePersonaWithConfirmation()
   {
      guard let persona = editedPersona else { return }
      
      let alertController = UIAlertController(title: nil, message: loc("You really want to delete?"), preferredStyle: .alert)
      
      let cancel = UIAlertAction(title: loc("CANCEL"), style: .cancel)
      alertController.addAction(cancel)
      
      let delete = UIAlertAction(title: loc("DELETE"), style: .destructive, handler: {
         _ in
         self.deletePersona(persona)
      })
      alertController.addAction(delete)
      
      AlertManager.showAlert(alertController)
   }
   
   private func closeScreen(completion: (() -> Void)? = nil)
   {
      if let controller = presentingViewController {
         controller.dismiss(animated: true, completion: completion)
      }
      else {
         AppWindow.rootViewController = Storyboard.instantiateViewController(withIdentifier: "MainTabBarController")
         if let completion = completion {
            MainQueue.async { completion() }
         }
      }
   }
   
   override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
   {
      if let persona = editedPersona, persona.isInvalidated {
         closeScreen()
      }
   }
   
   deinit
   {
      editedPersona?.removeObserver(self, forKeyPath: "invalidated")
   }
   
   //MARK: - Requests
   
   private func createPersona(name : String, date : DMYDate, status : PersonaStatus)
   {
      RequestManager.createPersona(name: name, date: date, status: status, success:
      {
         self.closeScreen()
      })
   }
   
   private func editPersona(_ persona : Persona, name : String, date : DMYDate, status : PersonaStatus, closeOnCompletion : Bool)
   {
      RequestManager.editPersona(persona, name: name, date: date, status: status,
      success:
      {
         if closeOnCompletion
         {
            self.closeScreen()
         }
         else
         {
            if persona.id != (self.editedPersona?.id ?? 0)
            {
               self.editedPersona?.removeObserver(self, forKeyPath: "invalidated")
               self.editedPersona = persona
               self.updateForPersona()
            }
            
            AlertManager.showAlert(loc("Changes saved"))
         }
      },
      failure:
      {
         errorDescription in
         if closeOnCompletion
         {
            self.closeScreen(completion: { 
               AlertManager.showAlert(title: loc("Changes were not saved"), message: errorDescription)
            })
         }
         else {
            AlertManager.showAlert(title: loc("Error"), message: errorDescription)
         }
      }
      )
   }
   
   private func deletePersona(_ persona : Persona)
   {
      RequestManager.deletePersona(persona, success:
      {
         self.closeScreen()
      })
   }
   
   //MARK: - Actions
   
   @objc func hideKeyboardTap() {
      view.endEditing(true)
   }
   
   @IBAction func futureMomTap()
   {
      if !isFutureMom
      {
         isFutureMom = true
      }
      
   }
   
   @IBAction func momTap()
   {
      if isFutureMom
      {
         isFutureMom = false
      }
   }
   
   @IBAction func babyNameTap()
   {
      currentPicker = .babyName
      showPickers()
   }
   
   @IBAction func babyBirthdayTap()
   {
      currentPicker = .babyBirthday
      birthdayDatePicker.maximumDate = Date()
      showPickers()
   }
   
   @IBAction func beginningOfWeekTap()
   {
      currentPicker = .beginningOfWeek
      showPickers()
   }
   
   @IBAction func pregnancyWeekTap()
   {
      currentPicker = .pregnancyWeek
      showPickers()
   }
   
   @IBAction func closePickersTap()
   {
      view.endEditing(true)
      updateFromCurrentField()
      hidePickers()
   }   
   
   @IBAction func avatarTap()
   {
      if pickersShown {
         updateFromCurrentField()
      }
      
      if personaStatusChanged || personaFieldsChanged {
         editPersonaData(closeOnCompletion: true)
      }
      else {
         closeScreen()
      }
   }
   
   @IBAction func deleteTap() {
      deletePersonaWithConfirmation()
   }
   
   @IBAction func createTap()
   {
      if !validateInput() { return }
      createPersonaOrChangeExistingStatus()
   }
   
   @objc func confirmTap()
   {
      if pickersShown {
         updateFromCurrentField()
      }
      
      if personaStatusChanged || personaFieldsChanged {
         editPersonaData(closeOnCompletion: true)
      }
      else {
         closeScreen()
      }
   }
   
   @objc func cancelTap()
   {
      if let user = User.current, !user.personas.isEmpty {
         closeScreen()
      }
      else {
         AppDelegate.logout()
      }
   }
   
   //MARK: - Picker
   
   public func numberOfComponents(in pickerView: UIPickerView) -> Int {
      return 1
   }
   
   public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int
   {
      if pickerView === pregnancyWeekPicker {
         return 35
      }
      else {
         return 7
      }
   }
   
   public func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView
   {
      var pickerLabel : UILabel! = view as? UILabel;
      
      if (pickerLabel == nil)
      {
         pickerLabel = UILabel()
         pickerLabel.font = UIFont.systemFont(ofSize: 15.45 * WidthRatio)
         pickerLabel.textAlignment = .center
         pickerLabel.textColor = rgb(84, 93, 120)
      }
      
      var text = ""
      if pickerView === pregnancyWeekPicker {
         text = String(5 + row)
      }
      else
      {
         let date = Date().addingDays(row - 7)
         let weekdayNum = calendar.component(.weekday, from: date)
         text = "\(dateFormatter.weekdaySymbols[weekdayNum - 1]) \(dateFormatter.string(from: date))"
      }
      
      pickerLabel.text = text
      
      return pickerLabel
   }
   
   //MARK: - DatePicker
   
   @IBAction func birthdayChanged(_ sender: UIDatePicker)
   {
      
   }
   
   //MARK: - TextField
   
   public func textFieldShouldReturn(_ textField: UITextField) -> Bool
   {
      view.endEditing(true)
      updateFromCurrentField()
      hidePickers()
      return true
   }
}
