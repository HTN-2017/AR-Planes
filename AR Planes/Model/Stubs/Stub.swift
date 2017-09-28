//
//  Stub.swift
//  AR Planes
//
//  Created by Cal Stephens on 9/28/17.
//  Copyright © 2017 Hack the North. All rights reserved.
//

import UIKit

enum Stub {
    case waterloo
    case atlanta
    
    fileprivate var fileName: String {
        switch self {
        case .waterloo: return "server_stub_waterloo"
        case .atlanta: return "server_stub_atlanta"
        }
    }
    
    var flights: [Flight] {
        guard let jsonStub = Bundle.main.url(forResource: fileName, withExtension: "json"),
            let jsonText = try? String(contentsOf: jsonStub) else
        {
            return []
        }
        
        return WebSocketManager.processJsonTextFromServer(jsonText)
    }
}
