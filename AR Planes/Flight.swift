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
    
    init?(callsign: String, longitude: Double, latitude: Double, altitude: Double) {
        self.callsign = callsign.trimmingCharacters(in: .whitespacesAndNewlines)
        self.longitude = longitude
        self.latitude = latitude
        self.altitude = altitude
    }
}
