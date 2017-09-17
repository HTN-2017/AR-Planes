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
    
    static let USE_JSON_STUB = true
    
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
                    
                    existingNode.runAction(move)
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

        let cylinder = SCNCylinder(radius: 30, height: 20)
        cylinder.firstMaterial?.diffuse.contents = UIColor.clear
        let largerNode = SCNNode(geometry: cylinder)
        largerNode.addChildNode(planeNode)
        
        return largerNode
    }
    
    // MARK: - User interaction
    
    func setupTap() {
        let tapRecognizer = UITapGestureRecognizer()
        tapRecognizer.numberOfTapsRequired = 1
        tapRecognizer.numberOfTouchesRequired = 1
        tapRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        sceneView.gestureRecognizers = [tapRecognizer]
    }

    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: sceneView)
        
        let hitResults = sceneView.hitTest(location, options: nil)
        if hitResults.count > 0 {
            guard let planeNode = hitResults.first?.node,
                let identifier = planeNodes.allKeys(forValue: planeNode).first,
                let flight = nearbyFlights.first(where: { $0.icao == identifier }) else
            {
                return
            }
            
            addInformationView(for: flight, in: planeNode)
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
        
        statusCardView.alpha = 1.0
        statusCardView.setLoading(true, flight: flight)
        
        guard !flight.callsign.isEmpty else {
            statusCardView.updateForPrivateFlight(flight)
            return
        }
        
        flight.loadAdditionalInformation(handler: { info in
            DispatchQueue.main.async {
                guard let flightInfo = info,
                    let userLocation = self.mostRecentUserLocation else
                {
                    statusCardView.updateForPrivateFlight(flight)
                    return
                }

                statusCardView.update(
                    with: flight,
                    and: flightInfo,
                    relativeTo: userLocation)
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
        sceneView.delegate = self
        sceneView.showsStatistics = true
        
        // Connect to web socket
        if !ViewController.USE_JSON_STUB {
            socket.onText = self.websocketDidReceiveMessage(text:)
            socket.onConnect = self.websocketDidConnect
            socket.onDisconnect = self.websocketDidDisconnect
            socket.onData = self.websocketDidReceiveData(data:)
            socket.connect()
        }
        
        setupTap()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        sceneView.session.run(configuration)
        setUpLocationManager()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
}

// MARK: - ARSCNViewDelegate

extension ViewController /*: ARSCNViewDelegate */ {
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let statusCardView = self.statusCardView,
            let flight = statusCardView.flight,
            let node = planeNodes[flight.icao] else
        {
            return
        }
        
        let centerPoint = node.position
        let projectedPoint = renderer.projectPoint(centerPoint)
        
        let translate = CGAffineTransform(
            translationX: CGFloat(projectedPoint.x) - statusCardView.intrinsicContentSize.width/2,
            y: CGFloat(projectedPoint.y))
        
        let translateAndScale = translate.scaledBy(x: 0.65, y: 0.65)
        
        DispatchQueue.main.async {
            statusCardView.transform = translateAndScale
        }
    }
    
}

// MARK: - CLLocationManagerDelegate

extension ViewController: CLLocationManagerDelegate {
    
    func setUpLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        mostRecentUserLocation = locations[0] as CLLocation
        
        if ViewController.USE_JSON_STUB,
            let jsonStub = Bundle.main.url(forResource: "server_stub", withExtension: "json"),
            let jsonText = try? String(contentsOf: jsonStub)
        {
            processJsonText(text: jsonText)
        }
    }
    
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
        processJsonText(text: text)
    }
    
    func processJsonText(text: String) {
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
