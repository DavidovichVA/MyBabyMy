import UIKit

final class AlertManager
{
   private static var rootController : UIViewController {
      return AppWindow.rootViewController!
   }
   
   private static var controllersToShow : [UIAlertController] = []
   private static var runningShow = false
   
   private static let alertColor = rgb(255, 120, 154)
   private static let alertButtonColor = rgb(137, 141, 152)
   private static let alertMessageFont = UIFont.systemFont(ofSize: 16, weight: UIFontWeightBold)
   
   // MARK: - Public functions
   
   public class func showAlert (_ message : String, completion: @escaping () -> Void = {}) {
      showAlert(title: nil, message: message, completion: completion)
   }
   
   public class func showAlert (title : String?, message : String, style: UIAlertControllerStyle = .alert, completion: @escaping () -> Void = {})
   {
      let alertController = UIAlertController(title: title, message: message, preferredStyle: style)
      let ok = UIAlertAction(title: loc("OK"), style: .default, handler: { alertAction in completion() })
      alertController.addAction(ok)
      
//      let attributes = [NSForegroundColorAttributeName : alertColor, NSFontAttributeName : alertMessageFont]
//      let attrMessage = NSMutableAttributedString(string: message, attributes: attributes)
//      alertController.setValue(attrMessage, forKey: "attribu" + "tedMessage")
      
      showAlert(alertController)
   }
   
   public class func showAlert (_ controller : UIAlertController)
   {
      controllersToShow.append(controller)
      if !runningShow
      {
         runningShow = true
         performOnMainThread {
            showNextController()
         }
      }
   }
   
   // MARK: - Private functions
   
   private class func showNextController ()
   {
      guard let controller = controllersToShow.first else {
         runningShow = false
         return
      }
      
      var showingAlertController = false
      var presentingController = rootController
      while let presentedController = presentingController.presentedViewController
      {
         if presentedController is UIAlertController {
            showingAlertController = true
            break
         }
         presentingController = presentedController
      }
      
      if !showingAlertController
      {
         presentingController.present(controller, animated: true)
//         controller.view.tintColor = alertButtonColor
         controllersToShow.removeFirst()
         if controllersToShow.isEmpty
         {
            runningShow = false
            return
         }
      }
      
      delay(0.15) {
         showNextController()
      }
   }
}
