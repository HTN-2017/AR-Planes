//
//  Flight.swift
//  AR Planes
//
//  Created by Cal Stephens on 9/16/17.
//  Copyright © 2017 Hack the North. All rights reserved.
//

import Foundation
import CoreLocation

struct Flight {
    
    let callsign: String
    
    let longitude: Double
    let latitude: Double
    let altitude: Double
    
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
