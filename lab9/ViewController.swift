//
//  ViewController.swift
//  lab9
//
//  Created by Arturo on 05/11/21.
//

import UIKit
import CoreLocation
import Charts

class ViewController: UIViewController, CLLocationManagerDelegate  {

    @IBOutlet weak var location: UILabel!
    @IBOutlet weak var weatDesc: UILabel!
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var temp: UILabel!
    @IBOutlet weak var humidity: UILabel!
    @IBOutlet weak var windSpeed: UILabel!
    
    @IBOutlet weak var chart: BarChartView!
    
    var locationManager: CLLocationManager!
    var usrLocation:String = ""
    var hrTemps:[Double] = []
    var hrHr:[Double] = []
    var lastLat: Double!
    var lastLon: Double!
    
    
    let apiID = "appid=YourIdGoesHere" //replace with your id
    let url = "https://api.openweathermap.org/data/2.5/onecall?"
    let iconUrl = "https://openweathermap.org/img/wn/"
    let iconExt = "png"
    let iconSufix = "@2x"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        getLocation()
        
    }
    
    func getLocation(){
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled(){
            locationManager.startUpdatingLocation()
            locationManager.distanceFilter = 10
            
        }else{
            print("Location Services Disabled")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        //get current location
        let userLocation = locations[0] as CLLocation
        let lat = userLocation.coordinate.latitude
        let lon = userLocation.coordinate.longitude
        
        
        
        let geocoder  = CLGeocoder()
        geocoder.reverseGeocodeLocation(userLocation){ (placemarks, error) in
            if (error != nil || placemarks == nil){
                print("Error in reverseGeocodeLocation")
                return
            }
            let placemark = placemarks! as [CLPlacemark]
            if (placemark.count>0){
                let placemark = placemarks![0]
                
                let locality = placemark.locality ?? ""
                let country = placemark.isoCountryCode ?? ""
                let administrativeArea = placemark.administrativeArea ?? ""
            
            //set to address UI label
                self.usrLocation = "\(locality), \(administrativeArea), \(country)"
                print(self.usrLocation)
                self.location.text = self.usrLocation
                if(!((self.lastLat==lat) && (self.lastLon==lon))){
                    self.getWeather(lat: lat, lon: lon)
                    self.lastLat = lat
                    self.lastLon = lon
                }
            }
        }
    }
    func getWeather(lat:Double, lon:Double){
        let session = URLSession.shared
        let query = "lat=\(lat)&lon=\(lon)&units=metric&exclude=minutely,daily,alerts"
        
        let queryUrl = URL(string: url+query+"&"+apiID)!
        
        print(url+query+"&"+apiID)
        
        let task = session.dataTask(with: queryUrl){
            data, response, error in
            if error != nil || data == nil {
                print ("Client error!")
                return
            }
            let r = response as? HTTPURLResponse
            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode)else{
                print("Server error \(String(describing: r?.statusCode))")
                return
            }
            guard let mime = response.mimeType, mime == "application/json" else {
                print("Incorrect MIME type: \(String(describing: r?.mimeType))")
                return
            }
            do{
                let json = try JSONSerialization.jsonObject(with: data!, options: []) as? [String:Any]
                
                let current = (json?["current"] as? [String:Any])?["weather"] as? [Any]
                
                let desc = (current?[0] as? [String:Any])?["description"] as? String
                let icon = (current?[0] as? [String:Any])?["icon"] as? String
                
                let temp = (json?["current"] as? [String:Any])?["temp"] as? Double
                
                let humidity = (json?["current"] as? [String:Any])?["humidity"] as? Int
                
                let windSpeed = (json?["current"] as? [String:Any])?["wind_speed"] as? Double
                
                let hourlyTmp = json?["hourly"] as? [Any]
                self.hrHr.removeAll()
                self.hrTemps.removeAll()
                for i in 1...8 {
                    self.hrHr.append(((hourlyTmp![i] as? [String:Any])?["dt"] as? Double)!)
                    print(self.hrHr[i-1])
                    self.hrTemps.append(((hourlyTmp![i] as? [String:Any])?["temp"] as? Double)!)
                    print(self.hrTemps[i-1])
                    
                }
                
                print(self.iconUrl+icon!+self.iconSufix+"."+self.iconExt)
                
                DispatchQueue.main.async {
                    self.weatDesc.text = desc
                    self.temp.text = "\(temp!) C"
                    self.humidity.text = "Humidity: \(humidity!) %"
                    self.windSpeed.text = String(format: "Wind speed: %.2f", windSpeed!*3.6) + " km/h"
                    print(windSpeed!)
                    let symbolUrl = URL(string:self.iconUrl+icon!+self.iconSufix+"."+self.iconExt)!
                                        self.image.imageFrom(url: symbolUrl)
                    self.updateGraph()
                }
                
                
            }catch{
                print("Error in JSON")
                return
            }
        }
        task.resume()
    }

    func utcToLocal(utc: String) -> String {
        var startStr = ""
            
        if let utcTime = Double(utc) {
            let date = Date(timeIntervalSince1970: utcTime)
            let formatDate = DateFormatter()
            let localTime = TimeZone.current.abbreviation() ?? "EST"
            formatDate.timeZone = TimeZone(abbreviation: localTime)
            formatDate.locale = NSLocale.current
            formatDate.dateFormat = "HH:00"
            startStr = formatDate.string(from: date)
        }
            
        return startStr
    }
    
    func updateGraph(){
        var barChartEntry = [BarChartDataEntry]()
        var hrs:[String] = []
        for i in 0..<hrHr.count{
            hrs.append(utcToLocal(utc: String(hrHr[i])))
            let val = BarChartDataEntry(x: Double(i), y: hrTemps[i])
            barChartEntry.append(val)
        }
            
        let line1 = BarChartDataSet(entries: barChartEntry, label: "Hourly Temp")
        
        line1.colors = [NSUIColor.orange]
        
        let data = BarChartData()
        
        data.addDataSet(line1)
        chart.data = data
        chart.xAxis.valueFormatter = IndexAxisValueFormatter(values:hrs)
        chart.xAxis.granularity = 1
        chart.chartDescription?.text="Temperature for the next 8 hours"
        

        
        
    }
}


extension UIImageView{
    func imageFrom(url:URL){
        DispatchQueue.global().async {
            [weak self] in
            if let data = try? Data(contentsOf: url){
                if let image = UIImage(data: data){
                    DispatchQueue.main.async {
                        self?.image = image
                    }
                }
            }
        }
    }
}

