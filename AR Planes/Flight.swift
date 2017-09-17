//
//  Flight.swift
//  AR Planes
//
//  Created by Cal Stephens on 9/16/17.
//  Copyright © 2017 Hack the North. All rights reserved.
//

import Foundation
import CoreLocation
import SceneKit
import Kanna

struct Flight {
    
    //{"call":"DAL137  ","lat":44.4364,"lng":-80.4109,"alt":10888.98,"hdg":216.01,"gvel":253.75,"vvel":-5.2}]
    static let mock = Flight(icao: "--", callsign: "DAL432", longitude: -80.4109, latitude: 44.4364, altitude: 10888.98, heading: 180)
    
    // MARK: - Properties
    
    let icao: String
    let callsign: String
    let longitude: Double
    let latitude: Double
    let altitude: Double
    let noseHeading: Double
    
    var location: CLLocation {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        //note: CLLocation also accepts heading and speed, could be useful?
        return CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: 1,
            verticalAccuracy: 1,
            timestamp: Date())
    }
    
    func sceneKitCoordinate(relativeTo userLocation: CLLocation) -> SCNVector3 {
        let distance = location.distance(from: userLocation)
        let heading = userLocation.coordinate.getHeading(toPoint: location.coordinate)
        let headingRadians = heading * (.pi/180)
        
        let distanceScale: Double = 1/140
        let eastWestOffset = distance * sin(headingRadians) * distanceScale
        let northSouthOffset = distance * cos(headingRadians)  * distanceScale
        
        let altitudeScale: Double = 1/140 //1/20
        let upDownOffset = altitude * altitudeScale
        
        //in .gravityAndHeading, (1, 1, 1) is (east, up, south)
        return SCNVector3(eastWestOffset, upDownOffset, -northSouthOffset)
    }
    
    func sceneKitRotation() -> SCNVector4 {
        return SCNVector4(0, 1, 0, noseHeading * (.pi/180))
    }
    
    // MARK: - Initializers
    
    init(icao: String,
         callsign: String,
         longitude: Double,
         latitude: Double,
         altitude: Double,
         heading: Double)
    {
        self.icao = icao
        self.callsign = callsign.trimmingCharacters(in: .whitespacesAndNewlines)
        self.longitude = longitude
        self.latitude = latitude
        self.altitude = altitude
        self.noseHeading = heading
    }
    
    // MARK: - Scrape additional info from flightaware.com
    
    struct FlightInformation {
        let originAirportCode: String
        let originAirport: String
        let destinationAirportCode: String
        let destinationAirport: String
        
        let departureTime: String
        let arrivalTime: String
        
        let aircraftType: String
        let airlineName: String
        let airlineLogoUrl: String
        
        static let privatePlaneIdentifier = FlightInformation(
            originAirportCode: "private",
            originAirport: "private",
            destinationAirportCode: "private",
            destinationAirport: "private",
            departureTime: "private",
            arrivalTime: "private",
            aircraftType: "private",
            airlineName: "private",
            airlineLogoUrl: "private")
        
        var isPrivatePlane: Bool {
            return originAirportCode == "private" && destinationAirportCode == "private"
        }
    }
    
    static var cachedFlightInfo = [String: FlightInformation]() //[ICAO: FlightInformation]
    
    func loadAdditionalInformation(handler: @escaping (FlightInformation?) -> Void) {
        if let cachedFlightInfo = Flight.cachedFlightInfo[icao] {
            handler(cachedFlightInfo.isPrivatePlane ? nil : cachedFlightInfo)
            return
        }
        
        loadJsonFromFlightAware(handler: { json in
            
            guard let flights = json?["flights"] as? [String: Any],
                let firstFlight = flights.keys.first,
                let masterFlight = flights[firstFlight] as? [String: Any],
                let activityLog = masterFlight["activityLog"] as? [String: Any],
                let flightBody = (activityLog["flights"] as? [[String: Any]])?.first else
            {
                handler(nil)
                Flight.cachedFlightInfo[self.icao] = FlightInformation.privatePlaneIdentifier
                return
            }
            
            guard let origin = flightBody["origin"] as? [String: Any],
                let originAirportCode = origin["iata"] as? String,
                let originAirport = origin["friendlyName"] as? String else
            {
                handler(nil)
                return
            }
            
            guard let destination = flightBody["destination"] as? [String: Any],
                let destinationAirportCode = destination["iata"] as? String,
                let destinationAirport = destination["friendlyName"] as? String else
            {
                handler(nil)
                return
            }
            
            guard let takeoffTimes = flightBody["takeoffTimes"] as? [String: Any],
                let estimatedTakeoffTimeDouble = takeoffTimes["estimated"] as? Double else
            {
                handler(nil)
                return
            }
            
            guard let landingTimes = flightBody["landingTimes"] as? [String: Any],
                let estimatedLandingTimeDouble = landingTimes["estimated"] as? Double else
            {
                handler(nil)
                return
            }
            
            guard let airline = masterFlight["airline"] as? [String: Any],
                let airlineCode = airline["icao"] as? String,
                let airlineName = airline["shortName"] as? String else
            {
                handler(nil)
                return
            }
            
            guard let aircraftType = flightBody["aircraftTypeFriendly"] as? String else {
                handler(nil)
                return
            }
            
            let estimatedTakeoffTime = Date(timeIntervalSince1970: estimatedTakeoffTimeDouble)
            let estimatedLandingTime = Date(timeIntervalSince1970: estimatedLandingTimeDouble)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .short
            
            let info = FlightInformation.init(
                originAirportCode: originAirportCode,
                originAirport: originAirport,
                destinationAirportCode: destinationAirportCode,
                destinationAirport: destinationAirport,
                departureTime: dateFormatter.string(from: estimatedTakeoffTime),
                arrivalTime: dateFormatter.string(from: estimatedLandingTime),
                aircraftType: aircraftType,
                airlineName: airlineName,
                airlineLogoUrl: "https://flightaware.com/images/airline_logos/90p/\(airlineCode).png")
            
            Flight.cachedFlightInfo[self.icao] = info
            handler(info)
        })
    }
    
    private var additionalInfoUrl: URL {
        return URL(string: "https://flightaware.com/live/flight/\(callsign)")!
    }
    
    private func loadJsonFromFlightAware(handler: @escaping ([String: Any]?) -> Void) {
        let task = URLSession.shared.dataTask(with: additionalInfoUrl) { (data, _, _) in
            guard let data = data else {
                handler(nil)
                return
            }
            
            guard let html = Kanna.HTML(html: data, encoding: .utf8) else {
                return
            }
            
            let scripts = html.css("script")
            for script in scripts {
                //the json we want is a variable `rosettaBootstrap` inside a script
                guard let scriptText = script.innerHTML,
                    scriptText.hasPrefix("var trackpollBootstrap = ") else
                {
                    continue
                }
                
                let jsonText = scriptText
                    .replacingOccurrences(of: "var trackpollBootstrap = ", with: "")
                    .replacingOccurrences(of: ";", with: "")
                
                guard let json = try? JSONSerialization.jsonObject(with: jsonText.data(using: .utf8)!, options: []) as? [String: Any] else {
                    handler(nil)
                    return
                }
                
                handler(json)
            }
        }
        
        task.resume()
    }
    
}

// MARK: - CLLocationCoordinate2D + Heading

extension CLLocationCoordinate2D {
    
    func getHeading(toPoint point: CLLocationCoordinate2D) -> Double {
        func degreesToRadians(_ degrees: Double) -> Double { return degrees * .pi / 180.0 }
        func radiansToDegrees(_ radians: Double) -> Double { return radians * 180.0 / .pi }
        
        let lat1 = degreesToRadians(latitude)
        let lon1 = degreesToRadians(longitude)
        
        let lat2 = degreesToRadians(point.latitude);
        let lon2 = degreesToRadians(point.longitude);
        
        let dLon = lon2 - lon1;
        
        let y = sin(dLon) * cos(lat2);
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
        let radiansBearing = atan2(y, x);
        
        return radiansToDegrees(radiansBearing)
    }
}
