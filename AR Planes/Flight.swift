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

struct Flight {
    
    //{"call":"DAL137  ","lat":44.4364,"lng":-80.4109,"alt":10888.98,"hdg":216.01,"gvel":253.75,"vvel":-5.2}]
    static let mock = Flight(callsign: "DAL137", longitude: -80.4109, latitude: 44.4364, altitude: 10888.98, heading: 216.01)
    
    // MARK: - Properties
    
    let callsign: String
    
    let longitude: Double
    let latitude: Double
    let altitude: Double
    let heading: Double
    
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
        
        let altitudeScale: Double = 1/20
        let upDownOffset = altitude * altitudeScale
        
        //in .gravityAndHeading, (1, 1, 1) is (east, up, south)
        return SCNVector3(eastWestOffset, upDownOffset, -northSouthOffset)
    }
    
    // MARK: - Initializers
    
    init(callsign: String,
         longitude: Double,
         latitude: Double,
         altitude: Double,
         heading: Double)
    {
        self.callsign = callsign
        self.longitude = longitude
        self.latitude = latitude
        self.altitude = altitude
        self.heading = heading
    }
    
    init?(fromOpenSkyArray data: [Any]) {
        guard let callsign = data[1] as? String,
            let longitude = data[5] as? Double,
            let latitude = data[6] as? Double,
            let altitude = data[7] as? Double else
        {
            return nil
        }
        
        self.callsign = callsign.trimmingCharacters(in: .whitespacesAndNewlines)
        self.longitude = longitude
        self.latitude = latitude
        self.altitude = altitude
        self.heading = 0 //this method is gonna get deleted anyway
    }
    
    // MARK: - Networking
    
    private static let openSkyURL = URL(string: "https://opensky-network.org/api/states/all")!
    
    static func loadAllFromOpenSky(_ handler: @escaping ([Flight]) -> Void) {
        let request = URLSession.shared.dataTask(with: openSkyURL) { data, _, _ in
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []),
                let root = json as? [String : Any],
                let flightData = root["states"] as? [[Any]] else
            {
                print("failed")
                handler([])
                return
            }
            
            let flights = flightData.flatMap(Flight.init(fromOpenSkyArray:))
            handler(flights)
        }
        
        request.resume()
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
