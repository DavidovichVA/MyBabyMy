import Foundation

public let locLanguage : String = Bundle.main.preferredLocalizations.first!
public let locLanguageBase : String = locLanguage.components(separatedBy: "-").first!

public let locale : Locale = Locale(identifier: locLanguage)

public let calendar : Calendar =
{
   var calendar = Calendar(identifier: .gregorian)
   calendar.locale = locale
   calendar.timeZone = TimeZone.current
   calendar.firstWeekday = 2 // Monday
   return calendar
}()

public let locBundle : Bundle =
{
   if let path = Bundle.main.path(forResource: locLanguage, ofType: "lproj"), let bundle = Bundle(path: path) {
      return bundle
   }
   return Bundle.main
}()

public func loc(_ key : String) -> String
{
   return locBundle.localizedString(forKey: key, value: nil, table: nil)
}

public func locInfo(_ key : String, defaultValue : String? = nil) -> String
{
   var value = locBundle.object(forInfoDictionaryKey: key) as? String
   if value == nil { value = Bundle.main.localizedInfoDictionary?[key] as? String } else { return value! }
   if value == nil { value = Bundle.main.object(forInfoDictionaryKey: key) as? String } else { return value! }
   if value == nil { value = defaultValue ?? key }
   return value!
}
