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

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    fileprivate let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        sceneView.antialiasingMode = .multisampling2X
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingSessionConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        
        // Run the view's session
        sceneView.session.run(configuration)
        
        setUpLocationManager()
        
        let greenPlane = nodeForPlane(color: .green)
        greenPlane.position = SCNVector3.init(500, 500, 500)
        sceneView.scene.rootNode.addChildNode(greenPlane)
        
        let bluePlane = nodeForPlane(color: .green)
        bluePlane.position = SCNVector3.init(0, 400, 0)
        sceneView.scene.rootNode.addChildNode(bluePlane)
        
        let planeNode = nodeForPlane(color: .red)
        let hardcodedLocation = CLLocation(latitude: 43.4729, longitude: -80.5402)
        planeNode.position = Flight.mock.sceneKitCoordinate(relativeTo: hardcodedLocation)
        sceneView.scene.rootNode.addChildNode(planeNode)
    }
    
    func nodeForPlane(color: UIColor = .white) -> SCNNode {
        let planeAssetUrl = Bundle.main.url(forResource: "777", withExtension: "obj")!
        let planeAsset = MDLAsset(url: planeAssetUrl)
        let planeNode = SCNNode(mdlObject: planeAsset.object(at: 0))
        
        let planeMaterial = SCNMaterial()
        planeMaterial.diffuse.contents = color
        planeNode.geometry?.materials = [planeMaterial]
        
        return planeNode
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
        let userLatitude = userLocation.coordinate.latitude
        let userLongitude = userLocation.coordinate.longitude
        
    }
    
    // Called if location manager fails to update
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("\(error)")
    }
    
}
