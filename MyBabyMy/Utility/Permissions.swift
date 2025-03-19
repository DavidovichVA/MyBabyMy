import UIKit
import Photos
import AVFoundation

typealias AccessGrantedCallback = (_ accessGranted : Bool) -> Void

enum PermissionState {
   case allowed
   case forbidden
   case undetermined
}


var galleryPermission : PermissionState
{
   let authStatus = PHPhotoLibrary.authorizationStatus()
   switch authStatus
   {
      case .authorized: return .allowed
      case .denied, .restricted: return .forbidden
      case .notDetermined: return .undetermined
   }
}
var galleryAccessAllowed : Bool {
   return (galleryPermission == .allowed)
}

var cameraPermission : PermissionState
{
   let authStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
   switch authStatus
   {
      case .authorized: return .allowed
      case .denied, .restricted: return .forbidden
      case .notDetermined: return .undetermined
   }
}
var cameraAccessAllowed : Bool {
   return (cameraPermission == .allowed)
}

var microphonePermission : PermissionState
{
   let authStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio)
   switch authStatus
   {
      case .authorized: return .allowed
      case .denied, .restricted: return .forbidden
      case .notDetermined: return .undetermined
   }
}
var microphoneAccessAllowed : Bool {
   return (microphonePermission == .allowed)
}

func checkGalleryAccess(_ completion : @escaping AccessGrantedCallback)
{
   let authStatus = PHPhotoLibrary.authorizationStatus()
   
   switch authStatus
   {
      case .authorized: completion(true)
      
      case .denied, .restricted:
         let title = loc("Photos unavailable")
         let message = locInfo("NSPhotoLibraryUsageDescription", defaultValue: loc("Allow MyBabyMy access Photos"))
         
         let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
         
         let cancel = UIAlertAction(title: loc("Cancel"), style: .cancel)
         alertController.addAction(cancel)
         
         let settings = UIAlertAction(title: loc("Settings"), style: .default, handler: { _ in
            UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
         })
         alertController.addAction(settings)
         
         AlertManager.showAlert(alertController)
         completion(false)
      
      case .notDetermined:
         PHPhotoLibrary.requestAuthorization
         {
            status in
            performOnMainThread { completion(status == .authorized) }
         }
   }
}

func checkCameraAccess(_ completion : @escaping AccessGrantedCallback)
{
   let authStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
   
   switch authStatus
   {
      case .authorized: completion(true)
      
      case .denied, .restricted:
         let title = loc("Camera unavailable")
         let message = locInfo("NSCameraUsageDescription", defaultValue: loc("Allow MyBabyMy access camera"))
         
         let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
         
         let cancel = UIAlertAction(title: loc("Cancel"), style: .cancel)
         alertController.addAction(cancel)
         
         let settings = UIAlertAction(title: loc("Settings"), style: .default, handler: { _ in
            UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
         })
         alertController.addAction(settings)
         
         AlertManager.showAlert(alertController)
         completion(false)
         
      case .notDetermined:
         AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler:
         {
            granted in
            performOnMainThread { completion(granted) }
         })
   }
}

func checkMicrophoneAccess(_ completion : @escaping AccessGrantedCallback)
{
   let authStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio)
   
   switch authStatus
   {
   case .authorized: completion(true)
      
   case .denied, .restricted:
      let title = loc("Microphone unavailable")
      let message = locInfo("NSMicrophoneUsageDescription", defaultValue: loc("Allow MyBabyMy access microphone"))
      
      let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
      
      let cancel = UIAlertAction(title: loc("Cancel"), style: .cancel)
      alertController.addAction(cancel)
      
      let settings = UIAlertAction(title: loc("Settings"), style: .default, handler: { _ in
         UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
      })
      alertController.addAction(settings)
      
      AlertManager.showAlert(alertController)
      completion(false)
      
   case .notDetermined:
      AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeAudio, completionHandler:
      {
         granted in
         performOnMainThread { completion(granted) }
      })
   }
}

func checkCameraAndMicrophoneAccess(_ completion : @escaping AccessGrantedCallback)
{
   checkCameraAccess
   {
      cameraAccess in
      
      guard cameraAccess else {
         completion(false)
         return
      }
      
      checkMicrophoneAccess
      {
         microphoneAccess in
         completion(true) // we can capture video even without sound
      }
   }
}
