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
import ModelIO
import SceneKit.ModelIO

class ViewController: UIViewController, ARSCNViewDelegate {

    let socket = WebSocket(url: URL(string: "ws://34.232.80.41/")!)
    private let serverPollingInterval = TimeInterval(5)
    
    @IBOutlet var sceneView: ARSCNView!
    var statusCardView: FlightStatusCardView?
    fileprivate let locationManager = CLLocationManager()
    
    var mostRecentUserLocation: CLLocation? {
        didSet {
            print("LOADED USER LOCATION")
            sendLocation()
        }
    }
    
    // MARK: - Flights
    
    var nearbyFlights: [Flight] = [] {
        didSet {
            guard let userLocation = mostRecentUserLocation else {
                return
            }
            
            for flight in nearbyFlights {
                //update existing node if it exists
                if let existingNode = planeNodes[flight.icao] {
                    let move = SCNAction.move(
                        to: flight.sceneKitCoordinate(relativeTo: userLocation),
                        duration: serverPollingInterval)
                    
                    /*let rotate = SCNAction.rotate(
                        toAxisAngle: flight.sceneKitRotation(),
                        duration: serverPollingInterval)*/
                    
                    existingNode.runAction(.group([move/*, rotate*/]))
                }
                
                //otherwise, make a new node
                else {
                    let newNode = newPlaneNode()
                    planeNodes[flight.icao] = newNode
                    
                    newNode.position = flight.sceneKitCoordinate(relativeTo: userLocation)
                    newNode.rotation = flight.sceneKitRotation()
                    sceneView.scene.rootNode.addChildNode(newNode)
                }
            }
        }
    }
    
    var planeNodes = [String: SCNNode]()
    
    lazy var planeModel: MDLObject = {
        let planeAssetUrl = Bundle.main.url(forResource: "777", withExtension: "obj")!
        return MDLAsset(url: planeAssetUrl).object(at: 0)
    }()
    
    func newPlaneNode() -> SCNNode {
        let planeNode = SCNNode(mdlObject: planeModel)
        
        let planeMaterial = SCNMaterial()
        planeMaterial.diffuse.contents = UIColor.red
        planeNode.geometry?.materials = [planeMaterial]
        
        return planeNode
    }
    
    // MARK: - User interaction
    
    func setupTap() {
        let tapRecognizer = UITapGestureRecognizer()
        tapRecognizer.numberOfTapsRequired = 1
        tapRecognizer.numberOfTouchesRequired = 1
        tapRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        sceneView.gestureRecognizers = [tapRecognizer]
    }

    // @objc & #selector should be cleaner
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: sceneView)

        let hitResults = sceneView.hitTest(location, options: nil)
        if hitResults.count > 0 {
            let result = hitResults[0]
            let node = result.node
            guard let identifier = planeNodes.allKeys(forValue: node).first else {
                return
            }
            
            print(identifier)
            
            guard let flight = nearbyFlights.first(where: { $0.icao == identifier }) else {
                return
            }
            
            addInformationView(for: flight, in: node)
        }
    }
    
    func addInformationView(for flight: Flight, in node: SCNNode) {
        let statusCardView: FlightStatusCardView
        
        if let existingCardView = self.statusCardView {
            statusCardView = existingCardView
        } else {
            statusCardView = FlightStatusCardView()
            self.statusCardView = statusCardView
            self.view.addSubview(statusCardView)
            
            statusCardView.widthAnchor.constraint(equalToConstant: statusCardView.intrinsicContentSize.width).isActive = true
            statusCardView.heightAnchor.constraint(equalToConstant: statusCardView.intrinsicContentSize.height).isActive = true
            
            statusCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            statusCardView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        }
        
        UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            
            statusCardView.transform = .init(scaleX: 0.2, y: 0.2)
            statusCardView.alpha = 0.0
            
        }, completion: nil)
        
        flight.loadAdditionalInformation(handler: { info in
            guard let flightInfo = info else { return }
            
            DispatchQueue.main.sync {
                statusCardView.update(with: flight, and: flightInfo)
                
                UIView.animate(withDuration: 0.5, animations: {
                    statusCardView.transform = .init(scaleX: 0.65, y: 0.65)
                    statusCardView.alpha = 1.0
                })
            }
        })
        
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.antialiasingMode = .multisampling2X
        
        // Connect to web socket
        socket.onText = self.websocketDidReceiveMessage(text:)
        socket.onConnect = self.websocketDidConnect
        socket.onDisconnect = self.websocketDidDisconnect
        socket.onData = self.websocketDidReceiveData(data:)
        socket.connect()
        
        setupTap()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration

        let configuration = ARWorldTrackingSessionConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        sceneView.session.run(configuration)
        
        setUpLocationManager()
        
        let mockPlane = newPlaneNode()
        nearbyFlights = [Flight.mock]
        planeNodes[Flight.mock.icao] = mockPlane
        
        let planeMaterial = SCNMaterial()
        planeMaterial.diffuse.contents = UIColor.green
        mockPlane.geometry?.materials = [planeMaterial]
        
        mockPlane.position = SCNVector3.init(0, 200, 0)
        mockPlane.rotation = Flight.mock.sceneKitRotation()
        sceneView.scene.rootNode.addChildNode(mockPlane)
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
        mostRecentUserLocation = locations[0] as CLLocation
    }
    
    // Called if location manager fails to update
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("\(error)")
    }
}

// MARK: - WebSocketDelegate

extension ViewController {
    
    func websocketDidConnect() {
        sendLocation()
    }
    
    func sendLocation() {
        guard let location = mostRecentUserLocation else {
            return
        }
        
        print("sent location")
        socket.write(string: "\(location.coordinate.latitude),\(location.coordinate.longitude)")
    }
    
    func websocketDidDisconnect(error: NSError?) {
        print("disconnected")
    }
    
    
    func websocketDidReceiveMessage(text: String) {
        print("RECEIVED DATA")
        
        guard let flightData = text.toJSON() as? [[String: Any]] else {
            return
        }
        
        nearbyFlights = flightData.map { flight in
            let icao = flight["icao"] as? String ?? "--"
            let call = flight["call"] as? String ?? "Unknown"
            let lat = flight["lat"] as? Double ?? 0
            let lng = flight["lng"] as? Double ?? 0
            let alt = flight["alt"] as? Double ?? 0
            let hdg = flight["hdg"] as? Double ?? 0
            let _ = flight["gvel"]
            let _ = flight["vvel"]
            
            let airplane = Flight(
                icao: icao,
                callsign: call,
                longitude: lng,
                latitude: lat,
                altitude: alt,
                heading: hdg)
            
            return airplane
        }
        
        print(nearbyFlights.count)
    }
    
    func websocketDidReceiveData(data: Data) {
        print("data")
    }
}

extension String {
    func toJSON() -> Any? {
        guard let data = self.data(using: .utf8, allowLossyConversion: false) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    }
}

extension Dictionary where Value: Equatable {
    func allKeys(forValue val: Value) -> [Key] {
        return self.filter { (keyvalue) in keyvalue.value == val }.map { $0.0 }
    }
}
