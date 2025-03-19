//
//  Weather.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 3/14/17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import CoreLocation
import EDSunriseSet

typealias WeatherTime = (weatherType: WeatherType, daytime: DayTime)
typealias WeatherData = (timestamp: TimeInterval, temperature: Double, weatherIds: [Int], sunrise: TimeInterval, sunset: TimeInterval)

enum WeatherType : String
{
   case clear = "Clear"
   case rain = "Rain"
   case storm = "Storm"
   case snow = "Snow"
   
   static let allTypes : [WeatherType] = [clear, rain, storm, snow]
}

enum DayTime
{
   case morning
   case day
   case evening
   case night
}

class Weather
{
   let weatherDate : Date
   let checkDate : Date
   let type : WeatherType
   let temperature : Double
   
   static var lastKnown : Weather?
   static var sunRiseAndSet : (day : DMYDate, sunrise: Date, sunset: Date)?
   
   init(weatherDate: Date = Date(), checkDate: Date = Date(), temperature: Double, weatherIds: [Int] = [0])
   {
      self.weatherDate = weatherDate
      self.checkDate = checkDate
      self.temperature = temperature
      
      var weatherType : WeatherType = .clear
      weatherIdsLoop: for weatherId in weatherIds
      {
         //http://openweathermap.org/weather-conditions
         switch weatherId
         {
            case 200...299, 900...902, 957...962: weatherType = .storm; break weatherIdsLoop
            case 300...399, 500...599, 804: weatherType = .rain; break weatherIdsLoop
            case 600...699: weatherType = .snow; break weatherIdsLoop
            case 800...899: weatherType = .clear; break weatherIdsLoop
            default: weatherType = .clear
         }
      }
      self.type = weatherType
   }
   
   var isActual : Bool {
      return abs(checkDate.timeIntervalSinceNow) < 600
   }
   var isMoreOrLessActual : Bool {
      return abs(checkDate.timeIntervalSinceNow) < 3600
   }
   
   class func currentDayTime() -> DayTime
   {
      let currentTime = Date()
      let currentDay = DMYDate.fromDate(currentTime)
      
      if (sunRiseAndSet == nil || sunRiseAndSet!.day != currentDay), let location = LocationManager.location
      {
         if let sunriseSet = EDSunriseSet(timezone: calendar.timeZone, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
         {
            sunriseSet.calculateSunriseSunset(currentTime)
            sunRiseAndSet = (currentDay, sunriseSet.sunrise, sunriseSet.sunset)
         }
      }
      
      if let sunriseSunset = sunRiseAndSet, sunriseSunset.day == DMYDate.fromDate(currentTime)
      {
         let morningBegin = sunriseSunset.sunrise.addingHours(-1)
         if currentTime < morningBegin { return .night }
         
         let morningEnd = sunriseSunset.sunrise.addingHours(3)
         if currentTime < morningEnd { return .morning }
         
         let eveningBegin = sunriseSunset.sunset.addingHours(-2)
         if currentTime < eveningBegin { return .day }
         
         let eveningEnd = sunriseSunset.sunset.addingHours(2)
         if currentTime < eveningEnd { return .evening }
      }
      
      if let hour = calendar.dateComponents([.hour], from: currentTime).hour
      {
         if hour < 6 { return .night }
         else if hour < 10 { return .morning }
         else if hour < 18 { return .day }
         else if hour < 22 { return .evening }
         else { return .night }
      }
      
      return .day
   }
   
   class func getCurrentWeatherTime(_ callback : @escaping (WeatherTime) -> ())
   {
      if let lastWeather = lastKnown, lastWeather.isActual
      {
         callback((weatherType: lastWeather.type, daytime: currentDayTime()))
         return
      }
      
      let updateWithoutLocation =
      {
         if let lastWeather = lastKnown {
            callback((weatherType: lastWeather.type, daytime: currentDayTime()))
         }
         else {
            callback((weatherType: .clear, daytime: currentDayTime()))
         }
      }
      
      let updateWithLocation : (CLLocation) -> () =
      {
         location in
         RequestManager.getCurrentWeather(location.coordinate,
         success:
         {
            weatherData in
            
            let weather = Weather(weatherDate: Date(timeIntervalSince1970: weatherData.timestamp), checkDate: Date(), temperature: weatherData.temperature, weatherIds: weatherData.weatherIds)
            lastKnown = weather
            
            sunRiseAndSet = (DMYDate.fromDate(Date(timeIntervalSince1970: weatherData.timestamp)),
                             Date(timeIntervalSince1970: weatherData.sunrise),
                             Date(timeIntervalSince1970: weatherData.sunset))
            
            callback((weatherType: weather.type, daytime: currentDayTime()))
         },
         failure:
         {
            errorDescription in
            dlog(errorDescription)
            updateWithoutLocation()
         })
      }
      
      if geolocationPermission == .forbidden
      {
         if let location = LocationManager.location {
            updateWithLocation(location)
         }
         else {
            updateWithoutLocation()
         }
      }
      else
      {
         LocationManager.getCurrentPosition(updateWithLocation)
      }
   }
   
   class func image(for weatherTime : WeatherTime) -> UIImage?
   {
      var imageName = "mainWeather"
      switch weatherTime.daytime
      {
         case .morning, .evening: imageName += "Evening"
         case .day: imageName += "Day"
         case .night: imageName += "Night"
      }
      imageName += weatherTime.weatherType.rawValue
      
      return UIImage(named: imageName)
   }
}
