import Alamofire
import RealmSwift
import SwiftyJSON
import CoreLocation

private let ApiBaseUrl = ""
private let ServerHostName = ""
private let GoogleApiKey = ""
private let OpenWeatherMapApiKey = ""

private let ApiMethodRegister = "registration"
private let ApiMethodAuth = "auth"
private let ApiMethodLogout = "logout"
private let ApiMethodRestorePassword = "restorePassword"
private let ApiMethodSetPro = "setPro"
private let ApiMethodUnsetPro = "unsetPro"
private let ApiMethodMusicList = "getMusicList"
private let ApiMethodChangePassword = "editPass"
private let ApiMethodEditSocialAuthData = "setAnotherAuthData"
private let ApiMethodAddPersona = "addBaby"
private let ApiMethodEditPersona = "editBaby"
private let ApiMethodDeletePersona = "deleteBaby"
private let ApiMethodUserData = "getUserProfileData"
private let ApiMethodGetMediaList = "getMedia"
private let ApiMethodAddMedia = "addMedia"
private let ApiMethodEditMedia = "editMedia"
private let ApiMethodDeleteMedias = "deleteMedia"
private let ApiMethodProStatusPurchases = "getProStatusPurchases"
private let ApiMethodAcceptUserAgreements = "setUserAgreementsAccepted"

private let ApiPathFileUpload = ""


typealias SuccessCallback = () -> Void
typealias FailureCallback = (_ errorDescription : String) -> Void
typealias UserCallback = (_ user : User) -> Void

// Reachability
let serverReachabilityManager: NetworkReachabilityManager? = {
   let manager = NetworkReachabilityManager(host: ServerHostName)
   manager?.startListening()
   return manager
}()
let networkReachabilityManager: NetworkReachabilityManager? = {
   let manager = NetworkReachabilityManager()
   manager?.startListening()
   return manager
}()

var isServerConnection : Bool {
   return serverReachabilityManager?.isReachable ?? false
}
var isServerWiFiConnection : Bool {
   return serverReachabilityManager?.isReachableOnEthernetOrWiFi ?? false
}
var isInternetConnection : Bool {
   return networkReachabilityManager?.isReachable ?? false
}
var isInternetWiFiConnection : Bool {
   return networkReachabilityManager?.isReachableOnEthernetOrWiFi ?? false
}

final class RequestManager
{
   class func startReachability() {
      _ = serverReachabilityManager
      _ = networkReachabilityManager
   }
   
   // MARK: - General functions for API
   
   static var sessionManager : SessionManager =
   {
      let configuration = URLSessionConfiguration.default
      configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders
      
      let manager = SessionManager(configuration: configuration)
      manager.adapter = UserTokenAdapter()
      
      return manager
   }()
   
   @discardableResult
   private class func genericPostRequest(method : String,
                                         params : [String : Any] = [:],
                                         headers: HTTPHeaders? = nil,
                                         responseDataType : Type = .dictionary,
                                         showSpinner : Bool = false,
                                         dispatchQueue : DispatchQueue = DispatchQueue.main,
                                         success: @escaping (_ responseData: [String : JSON]) -> Void = {_ in },
                                         failure: @escaping FailureCallback = {error in AlertManager.showAlert(title: loc("Error"), message: error)}) -> DataRequest
   {
      if showSpinner
      {
         performOnMainThread {
            showAppSpinner()
         }
      }
      
      let urlString = ApiBaseUrl + method
      return sessionManager.request(urlString, method: .post, parameters: params, encoding: JSONEncoding.default, headers : headers).responseJSON(queue: dispatchQueue, completionHandler:
      {
         response in
         
         let handled = handleGenericResponse(response, responseDataType: responseDataType)
         
         if showSpinner
         {
            performOnMainThread {
               hideAppSpinner()
            }
         }
         
         if let error = handled.error
         {
            failure(loc(error))
            return
         }
         
         let data = handled.data ?? [:]
         success(data)
      })
   }
   
   private class func handleGenericResponse(_ response : DataResponse<Any>, responseDataType : Type = .dictionary) -> (error : String?, data : [String : JSON]?)
   {
      guard response.result.isSuccess else
      {
         var errorDescription : String
         
         if !isInternetConnection {
            errorDescription = "No internet connection"
         }
         else if !isServerConnection {
            errorDescription = "No server connection"
         }
         else if let code = response.response?.statusCode, ((code == 400) || (500...504 ~= code))
         {
            if code == 400 {
               errorDescription = "Incorrect request"
            }
            else {
               errorDescription = "Service temporary unavailable"
            }
         }
         else if let localizedDescription = response.result.error?.localizedDescription {
            errorDescription = localizedDescription
         }
         else {
            errorDescription = "Connection error"
         }
         
         return (errorDescription, nil)
      }
      
      guard let value = response.result.value else {
         return ("No data received", nil)
      }
      let json = JSON(value)
      
      if json.type != .dictionary {
         return ("Wrong response data", nil)
      }
      
      let status = json["status"].stringValue
      if status != "Success"
      {
         var errorDescription = json["errorMessage"].stringValue
         if errorDescription.isEmpty {
            errorDescription = "Server error"
         }
         else if errorDescription == "ERROR_AUTH" && User.authorized
         {
            dlog("logout due to authorization error")
            performOnMainThread {
               AppDelegate.logout()
            }            
         }
         return (errorDescription, nil)
      }
      
      if responseDataType == .null {
         return (nil, [:])
      }
      
      let responseData = json["response"]
      let type = responseData.type

      if type != responseDataType {
         return ("Wrong response data", nil)
      }
      
      switch type
      {
         case .dictionary: return (nil, responseData.dictionary)
         case .null, .unknown : return (nil, [:])
         default : return (nil, ["value" : responseData])
      }
   }
   
   class func uploadFile(_ fileUrl : URL, isVideo : Bool, dispatchQueue: DispatchQueue = DispatchQueue.main, success: @escaping (_ link : String) -> Void, failure : @escaping FailureCallback)
   {
      sessionManager.upload(multipartFormData:
      {
         multipartFormData in
         multipartFormData.append(fileUrl, withName: "file")
         
         //let isVideoParamBytes: Array<UInt8> = isVideo ? [1] : [0]
         //let isVideoParamData = Data(bytes: isVideoParamBytes)
         let isVideoParamData = (isVideo ? "true" : "false").data(using: .utf8)!
         multipartFormData.append(isVideoParamData, withName: "isVideo")
      },
      to: ApiPathFileUpload,
      encodingCompletion:
      {
         multipartFormDataEncodingResult in
         switch multipartFormDataEncodingResult
         {
         case .failure(let error):
            failure(error.localizedDescription)
            
         case .success(let uploadRequest, _, _):
            uploadRequest.responseJSON(queue: dispatchQueue, completionHandler:
            {
               response in
               
               guard response.result.isSuccess else
               {
                  var errorDescription : String
                  
                  if !isInternetConnection {
                     errorDescription = "No internet connection"
                  }
                  else if !isServerConnection {
                     errorDescription = "No server connection"
                  }
                  else if let code = response.response?.statusCode, ((code == 400) || (500...504 ~= code))
                  {
                     if code == 400 {
                        errorDescription = "Incorrect request"
                     }
                     else {
                        errorDescription = "Service temporary unavailable"
                     }
                  }
                  else if let localizedDescription = response.result.error?.localizedDescription {
                     errorDescription = localizedDescription
                  }
                  else {
                     errorDescription = "Connection error"
                  }
                  
                  failure(loc(errorDescription))
                  return
               }
               
               guard let value = response.result.value else {
                  failure(loc("No data received"))
                  return
               }
               
               let json = JSON(value)
               
               guard let dataDict = json.dictionary else
               {
                  failure(loc("Wrong response data"))
                  return
               }
               
               let path = dataDict["path"]?.stringValue ?? ""
               if !path.isEmpty, URL(string: path) != nil
               {
                  success((path as NSString).deletingPathExtension)
               }
               else {
                  failure(loc("Wrong response data"))
               }
            })
         }
      })
   }
   
   // MARK: - Authorization
   
   class func register(email : String, password : String, success: @escaping UserCallback, failure : @escaping FailureCallback)
   {
      let params = ["email" : email, "pass" : password, "device" : "IOS"]
      let urlString = ApiBaseUrl + ApiMethodRegister
      sessionManager.request(urlString, method: .post, parameters: params, encoding: JSONEncoding.default).responseJSON
      {
         response in
         
         let handled = handleGenericResponse(response)
         if let error = handled.error
         {
            failure(loc(error))
            return
         }
         
         let data = handled.data ?? [:]
         
         if let user = RequestModelHelper.userFromAuthData(data) {
            success(user)
         }
         else {
            failure(loc("Wrong response data"))
         }
      }
   }
   
   class func authorize(socialNetwork : SocialNetwork, socialId: String, success: @escaping UserCallback, failure : @escaping FailureCallback)
   {
      var params = ["device" : "IOS"]
      
      switch socialNetwork {
         case .instagram: params["instagramId"] = socialId
         case .facebook: params["facebookId"] = socialId
         case .vk: params["vkId"] = socialId
      }
      
      authorize(params: params, success: success, failure: failure)
   }
   
   class func authorize(email : String, password : String, success: @escaping UserCallback, failure : @escaping FailureCallback)
   {
      let params = ["email" : email, "pass" : password, "device" : "IOS"]
      authorize(params: params, success: success, failure: failure)
   }
   
   private class func authorize(params : [String : String], success: @escaping UserCallback, failure : @escaping FailureCallback)
   {
      let urlString = ApiBaseUrl + ApiMethodAuth
      sessionManager.request(urlString, method: .post, parameters: params, encoding: JSONEncoding.default).responseJSON
      {
         response in
         print(response.description)
         let handled = handleGenericResponse(response)
         if let error = handled.error
         {
            failure(loc(error))
            return
         }
         
         let data = handled.data ?? [:]
         
         if let user = RequestModelHelper.userFromAuthData(data) {
            success(user)
         }
         else {
            failure(loc("Wrong response data"))
         }
      }
   }
   
   class func logout()
   {
      let urlString = ApiBaseUrl + ApiMethodLogout
      sessionManager.request(urlString, method: .post, parameters: nil, encoding: JSONEncoding.default).responseJSON
      {
         response in
         
         let handled = handleGenericResponse(response, responseDataType : .null)
         if let error = handled.error {
            dlog(error)
         }
      }
   }
   
   class func restorePassword(email : String, success: @escaping SuccessCallback)
   {
      genericPostRequest(method: ApiMethodRestorePassword, headers: ["email" : email], responseDataType: .null, showSpinner: true, success:
      {
         _ in
         success()
      })
   }
	
	class func editPass(oldPassword : String , newPassword : String , success : @escaping SuccessCallback, failure : @escaping FailureCallback){
		
		let params = ["oldPass":oldPassword, "newPass": newPassword]
		
		genericPostRequest(method: ApiMethodChangePassword, params: params, responseDataType: .null, showSpinner: true, success: { _ in success()}, failure: failure)
	}
	
   class func editSocialAuthData(_ authData : [SocialNetwork : (socialId : String, name : String?, email : String?)], success: @escaping SuccessCallback = {}, failure : @escaping FailureCallback = { _ in })
   {
      guard !authData.isEmpty else { return }
      
      var params : [String : String] = [:]
      for (network, networkData) in authData
      {
         switch network
         {
         case .instagram:
            params["instagramId"] = networkData.socialId
            params["instaName"] = networkData.name
            params["instaEmail"] = networkData.email
         case .facebook:
            params["facebookId"] = networkData.socialId
            params["fbName"] = networkData.name
            params["fbEmail"] = networkData.email
         case .vk:
            params["vkId"] = networkData.socialId
            params["vkName"] = networkData.name
            params["vkEmail"] = networkData.email
         }
      }
      
      genericPostRequest(method: ApiMethodEditSocialAuthData, params: params, responseDataType: .null,
      success:
      {
         _ in
         success()
      },
      failure: failure)
   }
   
   class func acceptUserAgreements()
   {
      guard let user = User.current else { return }
      let userId = user.id
      
      let urlString = ApiBaseUrl + ApiMethodAcceptUserAgreements
      sessionManager.request(urlString, method: .post, parameters: nil, encoding: JSONEncoding.default).responseJSON
      {
         response in
         
         let handled = handleGenericResponse(response, responseDataType : .null)
         if let error = handled.error {
            dlog(error)
         }
         else if let user = User.current, user.id == userId
         {
            user.modifyWithTransactionIfNeeded {
               user.acceptedUserAgreements = true
            }
         }
      }
   }
   
   // MARK: - Purchases
   
   class func getProStatusPurchases(success : @escaping (_ set:Set<String>) -> Void, failure : @escaping FailureCallback)
   {
      genericPostRequest(method: ApiMethodProStatusPurchases, responseDataType: .array, success:
      {
         responseData in
         if let array = responseData["value"]?.array
         {
            var set = Set<String>()
            for purhase in array {
               set.insert(purhase["name"].description)
            }
            success(set)
         }
         else
         {
            failure(loc("Wrong response data"))
         }
      },
      failure: failure)
   }
   
   class func purchasePro(_ purchase : Purchase, success : @escaping SuccessCallback, failure : @escaping FailureCallback)
   {
      guard	let userId = User.currentUserId else { return }
      
      let params : [String : Any] = ["days": purchase.days,
                                     "months": purchase.months,
                                     "years": purchase.years,
                                     "currentTime": String(Int(purchase.timestamp)),
                                     "transactionId": purchase.transactionId]
      
      genericPostRequest(method: ApiMethodSetPro, params: params, responseDataType: .string,
      success:
      {
         responseData in
         if let string = responseData["value"]?.string, let dmyDate = DMYDate.dateFromString(string)
         {
            if User.currentUserId == userId, let user = Realm.main.object(ofType: User.self, forPrimaryKey: userId)
            {
               let date = dmyDate.getDate()
               user.modifyWithTransactionIfNeeded
               {
                  if let index = user.purchasesQueue.index(of: purchase) {
                     user.purchasesQueue.remove(objectAtIndex: index)
                  }
                  user.setPro(date)
               }
               success()
            }
            else
            {
               failure("User changed")
            }
         }
         else
         {
            failure(loc("Wrong response data"))
         }
      },
      failure: failure)
   }
   
   class func unSetPro(success : @escaping SuccessCallback, failure : @escaping FailureCallback)
   {
      genericPostRequest(method: ApiMethodUnsetPro, responseDataType: .null, showSpinner: true, success: { _ in success()}, failure: failure)
   }
   
   // MARK: - Persona
   
   class func createPersona(name : String, date : DMYDate, status : PersonaStatus, success: @escaping SuccessCallback)
   {
      var params = ["name" : name]
      
      switch status {
      case .baby:
         params["birthday"] = date.description
         params["babyStatus"] = "Baby"
      case .pregnant:
         params["pregnancyStartDate"] = date.description
         params["babyStatus"] = "Pregnant"
      }
      
      genericPostRequest(method: ApiMethodAddPersona, params: params, showSpinner: true, success:
      {
         responseData in
         
         if RequestModelHelper.createPersonaWithData(responseData, status: status) != nil {
            success()
         }
         else {
            AlertManager.showAlert(title: loc("Error"), message: loc("Wrong response data"))
         }
      })
   }
   
   class func editPersona(_ persona : Persona, name : String, date : DMYDate, status : PersonaStatus, success: @escaping SuccessCallback, failure : @escaping FailureCallback)
   {
      var params : [String : Any] = ["id" : persona.id, "name" : name]
      
      switch status {
      case .baby:
         params["birthday"] = date.description
         params["babyStatus"] = "Baby"
      case .pregnant:
         params["pregnancyStartDate"] = date.description
         params["babyStatus"] = "Pregnant"
      }
      
      let personaId = persona.id
      
      genericPostRequest(method: ApiMethodEditPersona, params: params, responseDataType: .null, showSpinner: true,
      success:
      {
         _ in
         
         guard let persona = Realm.main.object(ofType: Persona.self, forPrimaryKey: personaId) else {
            failure("Persona deleted")
            return
         }
         
         persona.modifyWithTransactionIfNeeded
         {
            persona.name = name
            persona.status = status
            
            switch status {
               case .baby: persona.birthday = date
               case .pregnant: persona.pregnancyStartDate = date
            }
         }
         success()
      },
      failure: failure
      )
   }
   
   class func deletePersona(_ persona : Persona, success: @escaping SuccessCallback)
   {
      let personaId = persona.id
      
      let method = ApiMethodDeletePersona + "?id=" + String(persona.id)
      genericPostRequest(method: method, responseDataType: .null, showSpinner: true, success:
      {
         _ in
         if let persona = Realm.main.object(ofType: Persona.self, forPrimaryKey: personaId) {
            RequestModelHelper.deletePersona(persona)
         }
         success()
      })
   }

	@discardableResult
   class func updateUserData(success: @escaping SuccessCallback, failure : @escaping FailureCallback) -> DataRequest?
   {
      guard User.authorized else { failure("No authorized user"); return nil }
      
      return genericPostRequest(method: ApiMethodUserData, success:
      {
         responseData in
         
         if RequestModelHelper.updateUserData(responseData) {
            success()
         }
         else {
            failure(loc("Wrong response data"))
         }
      },
      failure: failure
      )
   }
   
   // MARK: - Media
   
   class func getMediaList(personaId : Int, dispatchQueue : DispatchQueue = DispatchQueue.main, success: @escaping (_ mediaList : [Media]) -> Void, failure : @escaping FailureCallback)
   {
      let method = ApiMethodGetMediaList + "?id=" + String(personaId)
      
      genericPostRequest(method: method, dispatchQueue: dispatchQueue, success:
      {
         responseData in
         if let array = responseData["list"]?.array
         {
            let medias = RequestModelHelper.mediasFromData(array)
            success(medias)
         }
         else {
            failure(loc("Wrong response data"))
         }
      },
      failure: failure)
   }
   
   class func addMedia(_ media : Media, dispatchQueue : DispatchQueue = DispatchQueue.main, success: @escaping SuccessCallback, failure : @escaping FailureCallback)
   {
      guard media.checkLoadedFile() else { failure("No media file"); return }
      
      uploadFile(media.fileURL, isVideo: (media.type == .video), dispatchQueue: dispatchQueue,
      success:
      {
         link in
         
         guard !media.isInvalidated else { failure("Media deleted"); return }
         
         var params : [String : Any] = ["babyId" : media.personaId,
                                        "url" : link,
                                        "place" : media.place,
                                        "weather" : media.weather,
                                        "bestMoment" : media.isBestMoment,
                                        "mirrored" : media.mirrored,
                                        "date" : media.timestamp]
         
         let mediaTypeString : String
         switch media.type
         {
            case .photo: mediaTypeString = "Photo"
            case .video: mediaTypeString = "Video"
            case .photoInDynamics: mediaTypeString = "PhotoDynamic"
         }
         params["mediaType"] = mediaTypeString
         
         switch media.status
         {
            case .baby: params["dateString"] = media.date.description
            case .pregnant: params["pregnancyWeek"] = media.pregnancyWeek
         }
         
         genericPostRequest(method: ApiMethodAddMedia, params: params, dispatchQueue: dispatchQueue, success:
         {
            responseData in
            
            guard !media.isInvalidated else { failure("Media deleted"); return }
            
            let mediaId = responseData["id"]?.intValue ?? 0
            if mediaId == 0 {
               failure("Media was not added")
            }
            else {
               media.modifyWithTransactionIfNeeded {
                  media.id = mediaId
                  media.link = link
               }
               success()
            }
         },
         failure: failure)
      },
      failure: failure)
   }
   
   class func editMedia(_ media : Media, loadMediaFile : Bool, link : String? = nil, dispatchQueue : DispatchQueue = DispatchQueue.main, success: @escaping SuccessCallback, failure : @escaping FailureCallback)
   {
      guard media.id != 0 else { failure("Wrong media id"); return }
      
      if loadMediaFile
      {
         guard media.checkLoadedFile() else
         {
            editMedia(media, loadMediaFile: false, dispatchQueue: dispatchQueue, success: success, failure: failure)
            return
         }
         
         uploadFile(media.fileURL, isVideo: (media.type == .video), dispatchQueue: dispatchQueue,
         success:
         {
            newLink in
            
            guard !media.isInvalidated else { failure("Media deleted"); return }

            editMedia(media, loadMediaFile: false, link: newLink, dispatchQueue: dispatchQueue,
            success:
            {
               guard !media.isInvalidated else { failure("Media deleted"); return }
               
               media.modifyWithTransactionIfNeeded {
                  media.link = newLink
               }
               
               success()
            },
            failure: failure)
         },
         failure: failure)
      }
      else
      {
         var params : [String : Any] = ["id" : media.id,
                                        "place" : media.place,
                                        "weather" : media.weather,
                                        "bestMoment" : media.isBestMoment,
                                        "mirrored" : media.mirrored,
                                        "date" : media.timestamp]
         if let fileLink = link ?? media.link {
            params["url"] = fileLink
         }
         
         genericPostRequest(method: ApiMethodEditMedia, params: params, responseDataType: .null, dispatchQueue: dispatchQueue, success: { _ in success() }, failure: failure)
      }
   }
   
   class func deleteMedias(_ mediaIds : [Int], dispatchQueue : DispatchQueue = DispatchQueue.main, success: @escaping SuccessCallback, failure : @escaping FailureCallback)
   {
      genericPostRequest(method: ApiMethodDeleteMedias, params: ["ids" : mediaIds], responseDataType: .null, dispatchQueue: dispatchQueue, success: { _ in success() }, failure: failure)
   }
   
   // MARK: - Server data lists
   
   class func updateMusicList(success: @escaping SuccessCallback, failure : @escaping FailureCallback = {_ in })
   {
      genericPostRequest(method: ApiMethodMusicList, responseDataType: .array,
      success:
      {
         responseData in
         if let array = responseData["value"]?.array, RequestModelHelper.updateMusicList(array) {
            success()
         }
         else {
            failure(loc("Wrong response data"))
         }
      },
      failure: failure)
   }
   
   // MARK: - Other
   
   @discardableResult
   class func googleAutocompletionCities(_ text : String, coordinate : CLLocationCoordinate2D? = nil, success: @escaping ([String]) -> (), failure : @escaping FailureCallback = {_ in }) -> DataRequest
   {
      var params : [String : String] = ["input" : text,
                                        "types" : "(cities)",
                                        "language" : locLanguageBase,
                                        "key" : GoogleApiKey]
      
      if let coord = coordinate, CLLocationCoordinate2DIsValid(coord) {
         params["location"] = "\(coord.latitude),\(coord.longitude)"
         params["radius"] = "50000"
      }
      
      let urlString = "https://maps.googleapis.com/maps/api/place/autocomplete/json"
      return Alamofire.request(urlString, method: .get, parameters: params).responseJSON
      {
         response in
         
         guard response.result.isSuccess else
         {
            var errorDescription : String
            if !isInternetConnection {
               errorDescription = "No internet connection"
            }
            else if let code = response.response?.statusCode, ((code == 400) || (500...504 ~= code))
            {
               if code == 400 {
                  errorDescription = "Incorrect request"
               }
               else {
                  errorDescription = "Service temporary unavailable"
               }
            }
            else if let localizedDescription = response.result.error?.localizedDescription {
               errorDescription = localizedDescription
            }
            else {
               errorDescription = "Connection error"
            }
            
            failure(loc(errorDescription))
            return
         }
         
         guard let value = response.result.value else {
            failure(loc("No data received"))
            return
         }
         let json = JSON(value)
         
         if json.type != .dictionary {
            failure(loc("Wrong response data"))
            return
         }
         
         let status = json["status"].stringValue
         guard status == "OK" else
         {
            var errorDescription : String = json["error_message"].stringValue
            if errorDescription.isEmpty {
               errorDescription = loc(status)
            }
            if errorDescription.isEmpty {
               errorDescription = loc("Wrong response status")
            }
            failure(errorDescription)
            return
         }
         
         guard let predictions = json["predictions"].array else {
            failure(loc("Wrong response data"))
            return
         }
         
         var results : [String] = []
         for prediction in predictions
         {
            if let result = prediction["structured_formatting"]["main_text"].string, !result.isEmpty {
               results.append(result)
            }
         }
         
         success(results)
      }
   }
   
   class func googleGetCityName(_ coordinate : CLLocationCoordinate2D, success: @escaping (String) -> (), failure : @escaping FailureCallback = {_ in })
   {
      let params : [String : String] = ["latlng" : "\(coordinate.latitude),\(coordinate.longitude)",
                                        "result_type" : "locality|administrative_area_level_3",
                                        "language" : locLanguageBase,
                                        "key" : GoogleApiKey]
      
      let urlString = "https://maps.googleapis.com/maps/api/geocode/json"
      Alamofire.request(urlString, method: .get, parameters: params).responseJSON
      {
         response in
         
         guard response.result.isSuccess else
         {
            var errorDescription : String
            if !isInternetConnection {
               errorDescription = "No internet connection"
            }
            else if let code = response.response?.statusCode, ((code == 400) || (500...504 ~= code))
            {
               if code == 400 {
                  errorDescription = "Incorrect request"
               }
               else {
                  errorDescription = "Service temporary unavailable"
               }
            }
            else if let localizedDescription = response.result.error?.localizedDescription {
               errorDescription = localizedDescription
            }
            else {
               errorDescription = "Connection error"
            }
            
            failure(loc(errorDescription))
            return
         }
         
         guard let value = response.result.value else {
            failure(loc("No data received"))
            return
         }
         let json = JSON(value)
         
         if json.type != .dictionary {
            failure(loc("Wrong response data"))
            return
         }
         
         let status = json["status"].stringValue
         guard status == "OK" else
         {
            var errorDescription : String = json["error_message"].stringValue
            if errorDescription.isEmpty {
               errorDescription = loc(status)
            }
            if errorDescription.isEmpty {
               errorDescription = "Wrong response status"
            }
            failure(errorDescription)
            return
         }
         
         guard let results = json["results"].array else {
            failure(loc("Wrong response data"))
            return
         }
         guard !results.isEmpty else {
            failure("No city found")
            return
         }
         
         if let cityName = results[0]["address_components"][0]["long_name"].string, !cityName.isEmpty {
            success(cityName)
         }
         else {
            failure(loc("Wrong response data"))
            return
         }
      }
   }

   class func getCurrentWeather(_ coordinate : CLLocationCoordinate2D, success: @escaping (WeatherData) -> (), failure : @escaping FailureCallback = {_ in })
   {
      let params : [String : Any] = ["lat" : coordinate.latitude,
                                     "lon" : coordinate.longitude,
                                     "units" : "metric",
                                     "lang" : locLanguageBase,
                                     "appid" : OpenWeatherMapApiKey]
      
      let urlString = "http://api.openweathermap.org/data/2.5/weather"
      Alamofire.request(urlString, method: .get, parameters: params).responseJSON
      {
         response in
         
         guard response.result.isSuccess else
         {
            var errorDescription : String
            if !isInternetConnection {
               errorDescription = "No internet connection"
            }
            else if let code = response.response?.statusCode, ((code == 400) || (500...504 ~= code))
            {
               if code == 400 {
                  errorDescription = "Incorrect request"
               }
               else {
                  errorDescription = "Service temporary unavailable"
               }
            }
            else if let localizedDescription = response.result.error?.localizedDescription {
               errorDescription = localizedDescription
            }
            else {
               errorDescription = "Connection error"
            }
            
            failure(loc(errorDescription))
            return
         }
         
         guard let value = response.result.value else {
            failure(loc("No data received"))
            return
         }
         let json = JSON(value)
         
         if json.type != .dictionary {
            failure(loc("Wrong response data"))
            return
         }
         
         let cod = json["cod"].intValue
         guard cod == 200 else
         {
            var errorDescription : String = json["message"].stringValue
            if errorDescription.isEmpty {
               errorDescription = loc("Wrong response code")
            }
            failure(errorDescription)
            return
         }
         
         guard let weatherArray = json["weather"].array else {
            failure(loc("Wrong response data"))
            return
         }
         
         var weatherIds : [Int] = []
         var wasValidWeatherId = false
         for weatherData in weatherArray
         {
            let weatherId = weatherData["id"].intValue
            weatherIds.append(weatherId)
            wasValidWeatherId = wasValidWeatherId || weatherId > 0
         }
         
         let timestamp = json["dt"].doubleValue
         let temperature = json["main"]["temp"].doubleValue
         let sunrise = json["sys"]["sunrise"].doubleValue
         let sunset = json["sys"]["sunset"].doubleValue

         guard wasValidWeatherId, timestamp > 0, sunrise > 0, sunset > 0 else {
            failure(loc("Wrong response data"))
            return
         }
         
         success((timestamp, temperature, weatherIds, sunrise, sunset))
      }
   }
   
   class func downloadImage(_ link : String, success: @escaping (UIImage) -> (), failure : @escaping FailureCallback = {_ in })
   {
      Alamofire.request(link).responseData
      {
         response in
         
         guard response.result.isSuccess else
         {
            var errorDescription : String
            if !isInternetConnection {
               errorDescription = "No internet connection"
            }
            else if let code = response.response?.statusCode, ((code == 400) || (500...504 ~= code))
            {
               if code == 400 {
                  errorDescription = "Incorrect request"
               }
               else {
                  errorDescription = "Service temporary unavailable"
               }
            }
            else if let localizedDescription = response.result.error?.localizedDescription {
               errorDescription = localizedDescription
            }
            else {
               errorDescription = "Connection error"
            }
            
            failure(loc(errorDescription))
            return
         }
         
         guard let data = response.result.value else {
            failure(loc("No data received"))
            return
         }
         
         guard let image = UIImage(data: data) else {
            failure(loc("Corrupt image data"))
            return
         }
         
         success(image)
      }
   }
   
   @discardableResult
   class func downloadData(_ link : String, to fileURL : URL, excludeFromBackup : Bool = true, progress: @escaping Request.ProgressHandler = {_ in }, success: @escaping SuccessCallback, failure : @escaping FailureCallback = {_ in }) -> DownloadRequest
   {
      let destination: DownloadRequest.DownloadFileDestination =
      {
         _, _ in
         return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
      }
      
      return Alamofire.download(link, to: destination).downloadProgress(closure: progress).response
      {
         response in
         
         if let error = response.error
         {
            failure(error.localizedDescription)
            return
         }
         
         guard let destinationURL = response.destinationURL, FileManager.default.isReadableFile(atPath: destinationURL.relativePath) else
         {
            failure(loc("Failed to download file"))
            return
         }
         
         if excludeFromBackup {
            exlcudeFromBackup(destinationURL)
         }
         
         success()
      }
   }
}


class UserTokenAdapter: RequestAdapter
{
   func adapt(_ urlRequest: URLRequest) throws -> URLRequest
   {
      var urlRequest = urlRequest
      urlRequest.setValue(User.currentUserToken, forHTTPHeaderField: "token")
      return urlRequest
   }
}
