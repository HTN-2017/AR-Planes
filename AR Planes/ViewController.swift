//
//  ViewController.swift
//  AR Planes
//
//  Created by Cal Stephens on 9/16/17.
//  Copyright © 2017 Hack the North. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import CoreLocation
import Starscream

class ViewController: UIViewController, ARSCNViewDelegate {

    var socket = WebSocket(url: URL(string: "ws://34.232.80.41/")!)
    
    @IBOutlet var sceneView: ARSCNView!
    fileprivate let locationManager = CLLocationManager()
    
    var userLatitude: CLLocationDegrees = 0
    var userLongitude: CLLocationDegrees = 0
    var airplaneArray: [Flight] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Connect to web socket
        socket.delegate = self
        socket.connect()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
        
        setUpLocationManager()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: - ARSCNViewDelegate
    
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }

}

// MARK: - CLLocationManagerDelegate

extension ViewController: CLLocationManagerDelegate {
    
    func setUpLocationManager() {
        // Initialize
        locationManager.delegate = self
        
        // Highest accuracy
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Request location when app is in use
        locationManager.requestWhenInUseAuthorization()
        
        // Update location if authorized
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    // Called every time location changes
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation:CLLocation = locations[0] as CLLocation
        
        // Print coordinates
        guard let altitude = locations.last?.altitude else { return }
        userLatitude = userLocation.coordinate.latitude
        userLongitude = userLocation.coordinate.longitude
    }
    
    // Called if location manager fails to update
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("\(error)")
    }
}

// MARK: - WebSocketDelegate
extension ViewController: WebSocketDelegate {
    func websocketDidConnect(socket: WebSocket) {
        socket.write(string: "\(userLatitude),\(userLongitude)")
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        print("disconnected")
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        let json = text.toJSON()
        print(json)
        if let flights = json as? [String: Any] {
            for i in flights {
                let call = flights["call"] as! String
                let lat = flights["lat"] as! Double
                let lng = flights["lng"] as! Double
                let alt = flights["alt"] as! Double
                let hdg = flights["hdg"]
                let gvel = flights["gvel"]
                let vvel = flights["vvel"]
                
                let airplane: Flight = Flight(callsign: call, longitude: lng, latitude: lat, altitude: alt)!
                print(airplane)
                
                airplaneArray.append(airplane)
            }
        }
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: Data) {
        print("data")
    }
}

extension String {
    func toJSON() -> Any? {
        guard let data = self.data(using: .utf8, allowLossyConversion: false) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    }
}
