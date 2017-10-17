//
//  WebSocketManager.swift
//  AR Planes
//
//  Created by Cal Stephens on 9/28/17.
//  Copyright © 2017 Hack the North. All rights reserved.
//

import Starscream
import CoreLocation

// MARK: - WebSocketManager

class WebSocketManager {
    
    // MARK: Static Constants
    
    static let serverPollingInterval = TimeInterval(5)
    static let webSocketURL = URL(string: "ws://server.calstephens.tech:777")!
    
    // MARK: Setup
    
    private let socket = WebSocket(url: WebSocketManager.webSocketURL)
    
    public var location: CLLocation {
        didSet {
            sendLocationToServer()
        }
    }
    
    public var onError: (() -> Void)? //TODO: where can i actually call this from? how do I detect a network error here?
    public var didReceiveFlights: (([Flight]) -> Void)?
    
    init(for location: CLLocation) {
        self.location = location
        
        socket.delegate = self 
        socket.connect()
    }
    
    // MARK: Interface with server
    
    fileprivate func sendLocationToServer() {
        socket.write(string: "\(location.coordinate.latitude),\(location.coordinate.longitude)")
    }
    
    static func processJsonTextFromServer(_ jsonText: String) -> [Flight] {
        guard let flightData = jsonText.toJson() as? [[String: Any]] else {
            return []
        }
        
        let nearbyFlights = flightData.flatMap { flightInfo -> Flight? in
            let icao = flightInfo["icao"] as? String ?? "--"
            
            guard let call = (flightInfo["call"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                !call.isEmpty,
                let lat = flightInfo["lat"] as? Double,
                let lng = flightInfo["lng"] as? Double,
                let alt = flightInfo["alt"] as? Double else
            {
                return nil
            }
            
            let hdg = flightInfo["hdg"] as? Double ?? 0
            let gvel = flightInfo["gvel"] as? Double ?? 0
            let vvel = flightInfo["vvel"] as? Double ?? 0
            
            return Flight(
                icao: icao,
                callsign: call,
                longitude: lng,
                latitude: lat,
                altitude: alt,
                heading: hdg,
                groundVelocity: gvel,
                verticalVelocity: vvel)
        }
        
        return nearbyFlights
    }
    
}

// MARK: - WebSocketDelegate

extension WebSocketManager: WebSocketDelegate {
    
    func websocketDidConnect(socket: WebSocketClient) {
        sendLocationToServer()
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        onError?()
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        let flights = WebSocketManager.processJsonTextFromServer(text)
        didReceiveFlights?(flights)
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        return
    }
    
}


// MARK: - Standard Library Extensions

extension String {
    func toJson() -> Any? {
        guard let data = self.data(using: .utf8, allowLossyConversion: false) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    }
}

extension Dictionary where Value: Equatable {
    func allKeys(forValue val: Value) -> [Key] {
        return self.filter { (keyvalue) in keyvalue.value == val }.map { $0.0 }
    }
}
