import CoreLocation
import UIKit

///разрешение на геолокацию
var geolocationPermission : PermissionState
{
   let authStatus = CLLocationManager.authorizationStatus()
   switch authStatus
   {
      case .restricted, .denied : return .forbidden
      case .authorizedWhenInUse, .authorizedAlways : return .allowed
      case .notDetermined: return .undetermined
   }
}
///разрешена ли геолокация
var geolocationAllowed : Bool {
   return (geolocationPermission == .allowed)
}


public typealias LocationClosure = (_ location: CLLocation) -> Void

///менеджер для работы с геолокацией
public final class LocationManager
{
   //MARK: - Public
   
   ///последнее местоположение
   public fileprivate(set) static var location : CLLocation?
   
   ///получить своё местоположение; возвращает в callback текущую позицию один раз
   @discardableResult
   public class func getCurrentPosition(_ callback : @escaping LocationClosure) -> String?
   {
      let key = NSUUID().uuidString
 
      switch geolocationPermission
      {
      case .allowed:
         getterLock.synchronized {
            getterClosures[key] = callback
         }
         locManager.stopUpdatingLocation()
         locManager.startUpdatingLocation()
         return key
         
      case .undetermined:
         getterLock.synchronized {
            getterClosures[key] = callback
         }
         showAlert()
         return key
         
      case .forbidden:
         showAlert()
         return nil
      }
   }
   
   ///отказаться от получения позиции
   public class func cancelGetCurrentPosition(_ key : String)
   {
      getterLock.synchronized {
         getterClosures.removeValue(forKey: key)
      }
   }
   
   ///подписаться на наблюдение за своим положением; вызывает callback с новой позицией каждый раз при её изменении
   public class func watchCurrentPosition(_ callback : @escaping LocationClosure) -> String?
   {
      let key = NSUUID().uuidString
      
      switch geolocationPermission
      {
      case .allowed:
         watcherLock.synchronized {
            watcherClosures[key] = callback
         }
         locManager.stopUpdatingLocation()
         locManager.startUpdatingLocation()
         return key
         
      case .undetermined:
         watcherLock.synchronized {
            watcherClosures[key] = callback
         }
         showAlert()
         return key
         
      case .forbidden:
         showAlert()
         return nil
      }
   }
   
   ///отписаться от наблюдения
   public class func stopWatchingPosition(_ key : String)
   {
      watcherLock.synchronized {
         watcherClosures.removeValue(forKey: key)
      }
   }
   
   ///показать запрос о разрешении на геолокацию
   public class func showAlert()
   {
      let title = loc("Geolocation service unavailable")
      let message = locInfo("NSLocationWhenInUseUsageDescription", defaultValue: loc("Allow MyBabyMy access your location"))
      
      if CLLocationManager.authorizationStatus() == .notDetermined {
         locManager.requestWhenInUseAuthorization()
      }
      else
      {
         let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
         
         let cancel = UIAlertAction(title: loc("Cancel"), style: .cancel)
         alertController.addAction(cancel)
         
         let settings = UIAlertAction(title: loc("Settings"), style: .default, handler: { _ in
            UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
         })
         alertController.addAction(settings)
         
         AlertManager.showAlert(alertController)
      }
   }
}

//MARK: - Private

fileprivate var getterClosures : [String : LocationClosure] = [:]
fileprivate var watcherClosures : [String : LocationClosure] = [:]
fileprivate let getterLock = NSLock()
fileprivate let watcherLock = NSLock()

fileprivate let delegate : LocationManagerDelegate = LocationManagerDelegate()

fileprivate let locManager : CLLocationManager =
{
   let locManager = CLLocationManager()
   locManager.delegate = delegate
   locManager.distanceFilter = kCLDistanceFilterNone
   locManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
   
   return locManager
}()

//MARK: - LocationManagerDelegate

fileprivate class LocationManagerDelegate : NSObject, CLLocationManagerDelegate
{
   func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus)
   {
      switch status {
      case .notDetermined, .restricted, .denied : break
      case .authorizedWhenInUse, .authorizedAlways :
         
         var needToUpdateLocation = false
         getterLock.synchronized {
            watcherLock.synchronized {
               if !getterClosures.isEmpty || !watcherClosures.isEmpty {
                  needToUpdateLocation = true
               }
            }
         }
         
         if needToUpdateLocation {
            locManager.startUpdatingLocation()
         }
      }
   }
   
   func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
   {
      guard let currentLocation = locations.last, currentLocation.horizontalAccuracy > 0, currentLocation.horizontalAccuracy <= 500 else { return }
      LocationManager.location = currentLocation
      
      getterLock.synchronized
      {
         if !getterClosures.isEmpty
         {
            for closure in getterClosures.values {
               closure(currentLocation)
            }
            getterClosures.removeAll()
         }
      }
      
      watcherLock.synchronized
      {
         if !watcherClosures.isEmpty
         {
            for closure in watcherClosures.values {
               closure(currentLocation)
            }
         }
         else {
            locManager.stopUpdatingLocation()
         }
      }
   }

   func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
   {
      dlog(error)
   }
}
