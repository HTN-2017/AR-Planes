//
//  FlightStatusCardView.swift
//  AR Planes
//
//  Created by Cal Stephens on 9/16/17.
//  Copyright © 2017 Hack the North. All rights reserved.
//

import UIKit
import CoreLocation

class FlightStatusCardView: UINibView {
    
    private(set) var flight: Flight?
    private(set) var flightInfo: Flight.FlightInformation?
    
    @IBOutlet weak var loadingCoverView: UIView!
    @IBOutlet weak var loadingIndicator: UIView!
    @IBOutlet weak var privateFlightCoverView: UIView!
    @IBOutlet weak var privateFlightCallSignLabel: UILabel!
    
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var airlineNameLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    
    @IBOutlet weak var originAirportLabel: UILabel!
    @IBOutlet weak var departureTimeLabel: UILabel!
    
    @IBOutlet weak var destinationAirportLabel: UILabel!
    @IBOutlet weak var arrivalTimeLabel: UILabel!
    
    // MARK: - Setup
    
    override var nibName: String {
        return "StatusCard"
    }
    
    override func nibWasLoaded() {
        self.translatesAutoresizingMaskIntoConstraints = false
        
        widthAnchor.constraint(equalToConstant: intrinsicContentSize.width).isActive = true
        heightAnchor.constraint(equalToConstant: intrinsicContentSize.height).isActive = true
        
        nibView.layer.cornerRadius = 10.0
        nibView.layer.masksToBounds = true
        
        
        //add arrow to plane
        let arrowPath = UIBezierPath()
        let cardBounds = CGRect(origin: .zero, size: intrinsicContentSize)
        
        arrowPath.move(to: CGPoint(
            x: cardBounds.midX,
            y: cardBounds.minY))
        
        arrowPath.addLine(to: CGPoint(
            x: cardBounds.midX,
            y: cardBounds.minY - cardBounds.height * 0.05))
        
        arrowPath.addLine(to: CGPoint(
            x: cardBounds.midX - cardBounds.width * 0.025,
            y: cardBounds.minY - cardBounds.height * 0.15))
        
        let arrowLayer = CAShapeLayer()
        arrowLayer.path = arrowPath.cgPath
        arrowLayer.lineCap = kCALineCapRound
        arrowLayer.lineJoin = kCALineJoinRound
        arrowLayer.strokeColor = UIColor(white: 1.0, alpha: 1.0).cgColor
        arrowLayer.fillColor = nil
        arrowLayer.lineWidth = 4
        
        layer.addSublayer(arrowLayer)
        layer.masksToBounds = false
        clipsToBounds = false
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 400, height: 150)
    }
    
    
    // MARK - Updating
    
    func setLoading(_ loading: Bool, flight: Flight) {
        self.flight = flight
        self.flightInfo = nil
        showOverlay(.loading)
    }
    
    func updateForPrivateFlight(_ flight: Flight) {
        self.flight = flight
        self.flightInfo = nil
        showOverlay(.privateFlight(callsign: flight.callsign))
    }
    
    func update(
        with flight: Flight,
        and info: Flight.FlightInformation,
        relativeTo userLocation: CLLocation)
    {
        self.flight = flight
        self.flightInfo = info
        
        guard let originAirportCode = info.originAirportCode,
            let destinationAirportCode = info.destinationAirportCode else
        {
            showOverlay(.privateFlight(callsign: flight.callsign))
            return
        }
        
        //update strings
        airlineNameLabel?.text = info.airlineName ?? flight.callsign
        originAirportLabel?.text = originAirportCode
        departureTimeLabel?.text = info.departureTime ?? "--"
        destinationAirportLabel?.text = destinationAirportCode
        arrivalTimeLabel?.text = info.arrivalTime ?? "--"
        
        let distanceMeters = flight.location.distance(from: userLocation)
        
        if distanceMeters < 1000.0 {
            distanceLabel.text = "\(Int(round(distanceMeters)))m"
        } else {
            distanceLabel.text = "\(Int(round(distanceMeters / 1000.0)))km"
        }
        
        //load image from URL
        guard let logoImageView = self.logoImageView else { return }
        
        let imageTask = URLSession.shared.dataTask(with: URL(string: info.airlineLogoUrl)!, completionHandler: { data, _, _ in
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    logoImageView.image = #imageLiteral(resourceName: "generic airline")
                    self.showOverlay(nil)
                }
                
                return
            }
            
            DispatchQueue.main.async {
                logoImageView.image = image
                self.showOverlay(nil)
            }
        })
        
        imageTask.resume()
    }
    
    // MARK: - Overlay
    
    fileprivate enum Overlay {
        case loading
        case privateFlight(callsign: String)
    }
    
    fileprivate func showOverlay(_ overlay: Overlay?) {
        guard let overlay = overlay else {
            self.loadingCoverView.alpha = 0.0
            self.privateFlightCoverView.alpha = 0.0
            return
        }
        
        switch overlay {
        case .loading:
            self.loadingCoverView.alpha = 1.0
            self.privateFlightCoverView.alpha = 0.0
            self.loadingIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        case .privateFlight(let callsign):
            self.loadingCoverView.alpha = 0.0
            self.privateFlightCoverView.alpha = 1.0
            self.privateFlightCallSignLabel.text = callsign
        }
    }
    
}

///helper class to reduce boilerplate of loading from Nib
open class UINibView : UIView {
    
    var nibView: UIView!
    
    open var nibName: String {
        get {
            print("UINibView.nibName should be overridden by subclass")
            return ""
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupNib()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupNib()
    }
    
    func setupNib() {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: nibName, bundle: bundle)
        nibView = nib.instantiate(withOwner: self, options: nil)[0] as! UIView
        
        nibView.frame = bounds
        nibView.layer.masksToBounds = true
        
        self.addSubview(nibView)
        
        nibView.translatesAutoresizingMaskIntoConstraints = false
        let attributes: [NSLayoutAttribute] = [.top, .left, .right, .bottom]
        for attribute in attributes {
            let constraint = NSLayoutConstraint(item: self, attribute: attribute, relatedBy: .equal, toItem: self.nibView, attribute: attribute, multiplier: 1.0, constant: 0.0)
            self.addConstraint(constraint)
        }
        
        nibWasLoaded()
    }
    
    open func nibWasLoaded() {
        
    }
    
}
