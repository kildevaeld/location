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
    
    public static func address (location:CLLocation? = nil, service:Service = .Apple, block: AddressHandler) {
        
        if location != nil {
            let addr = self.shared.cache.get(location!)
            
            if addr != nil {
                return block(address: addr, error: nil)
            }
        }
        
        self.placemark(location, service:service) { (placemark, error) -> Void in
            self.handlePlacemark(placemark, error: error, block: block)
        }
    }
    
    public static func address (city:City, service:Service = .Apple, region:CLRegion? = nil,  block: AddressHandler) {
        self.address("\(city.name), \(city.country.name)", service:service, block: block)
    }
    
    public static func address(address:String, service:Service = .Apple, region:CLRegion? = nil, block:AddressHandler) {
        
        let addr = self.shared.cache.get(address)
        
        if addr != nil {
            return block(address: addr, error: nil)
        }
        
        self.placemark(address, service:service, region: region) { (placemark, error) -> Void in
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
        
        self.shared.cache.set(address)
        self.shared.cache.save()
        //self.shared.cache.set("\(address.city.name), \(address.country.name)", address:address)
        
        block(address: address, error: nil)
    }
    
}

extension CLLocation {
    public func compare(location: CLLocation) -> Bool {
        return self.compare(location, precision: 10.0)
    }
    
    public func compare(location: CLLocation, precision: CLLocationDistance) -> Bool {
        return self.distanceFromLocation(location) <= precision
    }
}


func ==(lhs: CLLocation, rhs: CLLocation) -> Bool {
    return lhs.compare(rhs, precision: 0.0)
}
