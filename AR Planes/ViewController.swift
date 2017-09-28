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
import ModelIO
import SceneKit.ModelIO

class ViewController: UIViewController {
    
    static let NETWORK_STUB: Stub? = .atlanta
    
    @IBOutlet var sceneView: ARSCNView!
    var statusCardView: FlightStatusCardView?
    
    fileprivate var socketManager: WebSocketManager?
    fileprivate let locationManager = CLLocationManager()
    
    var mostRecentUserLocation: CLLocation? {
        didSet {
            guard let userLocation = mostRecentUserLocation else {
                return
            }
            
            if let existingSocketManager = self.socketManager {
                existingSocketManager.location = userLocation
            } else {
                setUpSocketManager(for: userLocation)
            }
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.antialiasingMode = .multisampling2X
        sceneView.delegate = self
        
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
    
    private func setUpSocketManager(for location: CLLocation) {
        
        //use a stub instead if it exists
        if let stub = ViewController.NETWORK_STUB {
            self.nearbyFlights = stub.flights
            return
        }
        
        let socketManager = WebSocketManager(for: location)
        self.socketManager = socketManager
        
        socketManager.didReceiveFlights = { flights in
            self.nearbyFlights = flights
        }
        
        socketManager.onError = {
            //this doesn't do anything yet. not sure what qualifies as an error in terms of web sockets.
            //needs to warn the user about connectivity issues
        }
    }
    
    // MARK: Flights
    
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
                        duration: WebSocketManager.serverPollingInterval)
                    
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
        planeMaterial.diffuse.contents = UIColor(white:0.88, alpha:1.0)
        planeMaterial.reflective.contents = #imageLiteral(resourceName: "night")
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
            //build the status card
            statusCardView = FlightStatusCardView()
            self.statusCardView = statusCardView
            self.view.addSubview(statusCardView)
            
            statusCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            statusCardView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        }
        
        statusCardView.alpha = 1.0
        statusCardView.setLoading(true, flight: flight)
        updatePositionOfStatusCardView()
        
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
    
    func updatePositionOfStatusCardView() {
        guard let statusCardView = self.statusCardView,
            let flight = statusCardView.flight,
            let node = planeNodes[flight.icao] else
        {
            return
        }
        
        let centerPoint = node.position
        let projectedPoint = sceneView.projectPoint(centerPoint)
        
        let translate = CGAffineTransform(
            translationX: CGFloat(projectedPoint.x) - statusCardView.intrinsicContentSize.width/2.2,
            y: CGFloat(projectedPoint.y) - 14)
        
        let translateAndScale = translate.scaledBy(x: 0.65, y: 0.65)
        
        DispatchQueue.main.async {
            statusCardView.transform = translateAndScale
            
            //if z if less than 1, then the point is behind the camera
            // this is a little buggy sometimes.
            if projectedPoint.z > 1 {
                statusCardView.alpha = 0.0
            } else {
                statusCardView.alpha = 1.0
            }
        }
    }
    
}

// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        updatePositionOfStatusCardView()
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
    }
    
}
