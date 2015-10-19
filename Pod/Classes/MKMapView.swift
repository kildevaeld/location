//
//  MKMapView.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 18/10/2015.
//
//

import Foundation
import MapKit

public extension MKMapView {
    /*public var distance : CLLocationDistance {
        get {
            var dis: AnyObject! = objc_getAssociatedObject(self, &kDistanceKey)
            
            if dis == nil {
                dis = 100.0
            }
            
            return dis as! CLLocationDistance
        }
        set (value) {
            
            objc_setAssociatedObject(self, &kDistanceKey, value,.OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }*/
    
    public func setLocationWithCoordinates(coordinate: CLLocationCoordinate2D, distance:CLLocationDistance, animated: Bool) {
        
        let region = MKCoordinateRegionMakeWithDistance(coordinate, distance, distance)
        
        self.setRegion(region, animated: animated)
    }
    
    public func setLocation(location: CLLocation, distance:CLLocationDistance, animated: Bool) {
        self.setLocationWithCoordinates(location.coordinate, distance: distance, animated: animated)
    }

}