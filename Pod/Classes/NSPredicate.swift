//
//  NSPredicate+Location.swift
//  Pods
//
//  Created by Rasmus Kildevæld on 23/06/15.
//
//

import Foundation
import MapKit

enum Unit : Double {
    case Kilometres = 6378.137, Miles = 3963.19
}

func deg2rad(deg: Double) -> Double{
    return deg*(M_PI / 180)
}

func rad2deg(rad: Double) -> Double {
    return rad*(180 / M_PI)
}

struct BoundingBox {
    let latitude: (Double, Double)
    let longitide: (Double, Double)
    
}

func locationFromDistance(latitude: Double, longitude: Double, bearing: Double, distanceInMeters: Double, unit: Unit) -> CLLocationCoordinate2D {
    
    let radius = unit.rawValue
    
    let distance = distanceInMeters / 1000.0;
    
    let rLatitude = deg2rad(latitude);
    let rLongitude = deg2rad(longitude);
    
    let rBearing = deg2rad(bearing);
    
    let rAngDist = distance / radius;
    
    let rLatB = asin(sin(rLatitude) * cos(rAngDist) +
        cos(rLatitude) * sin(rAngDist) * cos(rBearing))
    
    let rLonB = rLongitude + atan2(sin(rBearing) * sin(rAngDist) * cos(rLatitude),
        cos(rAngDist) - sin(rLatitude) * sin(rLatB))
    
    
    return CLLocationCoordinate2DMake(rad2deg(rLatB), rad2deg(rLonB))
}

func _boundingBox (location: CLLocationCoordinate2D, distance: Double, unit: Unit) -> BoundingBox {
    let minLat = locationFromDistance(location.latitude, longitude: location.longitude, bearing: 0, distanceInMeters: distance, unit: .Kilometres).latitude
    let maxLat = locationFromDistance(location.latitude, longitude: location.longitude, bearing: 180, distanceInMeters: distance, unit: .Kilometres).latitude
    
    let minLng = locationFromDistance(location.latitude, longitude: location.longitude, bearing: 90, distanceInMeters: distance, unit: .Kilometres).longitude
    let maxLng = locationFromDistance(location.latitude, longitude: location.longitude, bearing: 270, distanceInMeters: distance, unit: .Kilometres).longitude
    
    return BoundingBox(latitude: (minLat,maxLat), longitide: (minLng,maxLng))
}

extension NSPredicate {
    static public func boundingBox(location:CLLocationCoordinate2D, distance: CLLocationDistance) -> NSPredicate {
        return self.boundingBox(location, distance: distance, latitudeKeyPath: "latitude", longitudeKeyPath: "longitude")
    }
    
    static public func boundingBox(location:CLLocationCoordinate2D, distance: CLLocationDistance, latitudeKeyPath:String, longitudeKeyPath: String) -> NSPredicate {
        
        let box = _boundingBox(location, distance: distance, unit: .Kilometres)
        
        let (minLat, maxLat) = box.latitude
        let (minLng, maxLng) = box.longitide
        
        let latPredicate : NSPredicate
        let lngPredicate : NSPredicate
        
        let las = "\(latitudeKeyPath) <= %@ AND \(latitudeKeyPath) >= %@"
        let los =  "\(longitudeKeyPath) <= %@ AND \(longitudeKeyPath) >= %@"
        
        if maxLat > minLat {
            latPredicate = NSPredicate(format:las, NSNumber(double: maxLat), minLat as NSNumber)
        } else {
            latPredicate = NSPredicate(format:las, NSNumber(double:minLat), maxLat as NSNumber)
        }
        
        if maxLng > minLng {
            lngPredicate = NSPredicate(format:los, maxLng as NSNumber, minLng as NSNumber)
        } else {
            lngPredicate = NSPredicate(format:los, minLng as NSNumber, maxLng as NSNumber)
        }
        
        
        return NSCompoundPredicate(andPredicateWithSubpredicates:[lngPredicate, latPredicate])
    }
}