//
//  Location+Address.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 09/10/2015.
//
//

import Foundation
import MapKit

public typealias AddressHandler = (address:Address?, error:LocationError?) -> Void

extension Location {
    
    public static func address (location:CLLocation? = nil, block: AddressHandler) {
        self.placemark(location) { (placemark, error) -> Void in
            self.handlePlacemark(placemark, error: error, block: block)
        }
    }
    
    public static func address (city:City, region:CLRegion? = nil,  block: AddressHandler) {
        self.placemark("\(city.name), \(city.country.name)", region: region) { (placemark, error) -> Void in
            self.handlePlacemark(placemark, error: error, block: block)
        }
    }
    
    private static func handlePlacemark (placemark:CLPlacemark?, error:LocationError?, block:AddressHandler) {
        if error != nil {
            return block(address: nil, error: error)
        }
        
        if placemark == nil {
            return block(address: nil, error: LocationError.Unknown("could not resolve address"))
        }
        
        let address = Address(placemark: placemark!)
        
        block(address: address, error: nil)
    }
    
}
