//
//  Address.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 09/10/2015.
//
//

import Foundation
import MapKit
public typealias IsoCode = String
public typealias AddressMeta = [String: AnyObject]

public class Country : NSObject {
    public let name: String
    public let iso: IsoCode
    public init(name:String, iso:IsoCode) {
        self.name = name
        self.iso = iso
    }
    
    public override var description: String {
        return "\(self.name) (\(self.iso))"
    }
    
    public override var hashValue: Int {
        return self.iso.hashValue
    }
}

public func ==(lhs:Country, rhs: Country) -> Bool {
    return lhs.iso == rhs.iso
}


public class City: NSObject {
    public let name: String
    public let country: Country
    
    public init (name:String, country: Country) {
        self.name = name
        self.country = country
    }
    
    public init (name:String, country:String, iso:String) {
        self.name = name
        self.country = Country(name: country, iso: iso)
    }
    
    public override var description: String {
        return "\(name), \(self.country)"
    }
    
    public override var hashValue: Int {
        return self.name.hashValue ^ self.country.hashValue
    }
}

public func ==(lhs:City, rhs:City) -> Bool {
    return lhs.name == rhs.name && lhs.country == rhs.country
}

public class Address : NSObject, MKAnnotation, NSCoding  {
    
    struct AddressCoding {
        static let City = "city", Country = "country", Iso = "isoCode", ZipCode = "zipCode", Street = "street",
        Latitude = "latitude", Longitude = "longitude"
    }
    
    public var title: String?
    public let street: String
    public let zipCode: String
    public let city: City
    public var country: Country {
        return self.city.country
    }
    public let location: CLLocation
    public var coordinate: CLLocationCoordinate2D {
        return self.location.coordinate
    }
    
    public var meta: AddressMeta = [:]
    
    public required init?(coder aDecoder: NSCoder) {
        
        let cityName  = aDecoder.decodeObjectForKey(AddressCoding.City) as? String
        let countryName = aDecoder.decodeObjectForKey(AddressCoding.Country) as? String
        let isoCode  = aDecoder.decodeObjectForKey(AddressCoding.Iso) as? String
        let zipCode  = aDecoder.decodeObjectForKey(AddressCoding.ZipCode) as? String
        let latitude = aDecoder.decodeDoubleForKey(AddressCoding.Latitude)
        let longitude = aDecoder.decodeDoubleForKey(AddressCoding.Longitude)
        let street = aDecoder.decodeObjectForKey(AddressCoding.Street) as? String
        var valid = true
        if countryName == nil || isoCode == nil || cityName == nil || street == nil {
            valid = false
        }
        
        let country = Country(name: countryName!,iso: isoCode!)
        let city = City(name: cityName!, country: country)
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        

        self.city = city
        self.street = street!
        self.zipCode = zipCode!
        self.location = location
        
        /*if valid == false {
            return nil
        }*/
        
    }
    
    public init(city: City, street: String, zipCode: String, location: CLLocation) {
        
        self.city = city
        self.street = street
        self.location = location
        self.zipCode = zipCode
        
    }
    
    
    
    public convenience init(placemark:CLPlacemark) {
        
        let country = Country(name: placemark.country!, iso:placemark.ISOcountryCode!)
        let city = City(name: placemark.locality!, country:country)
        let street = placemark.subThoroughfare != "" ? placemark.thoroughfare! + " " + placemark.subThoroughfare! : placemark.thoroughfare
        self.init(city:city, street: street!, zipCode:placemark.postalCode!, location: placemark.location!)
        
    }
    
    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.city.name, forKey: AddressCoding.City)
        aCoder.encodeObject(self.country.name, forKey: AddressCoding.Country)
        aCoder.encodeObject(self.country.iso, forKey: AddressCoding.Iso)
        aCoder.encodeObject(self.street, forKey: AddressCoding.Street)
        aCoder.encodeObject(self.zipCode, forKey: AddressCoding.ZipCode)
        aCoder.encodeDouble(self.coordinate.latitude, forKey: AddressCoding.Latitude)
        aCoder.encodeDouble(self.coordinate.longitude, forKey: AddressCoding.Longitude)
    }
    
    var placemark: CLPlacemark {
        return self.addressDictionary.placemark(self.location)
    }
    
    var addressDictionary: AddressDictionary {
        return AddressDictionary(address: self)
    }
}

extension Address {
    public override var description: String {
        return "\(street), \(zipCode) \(city)"
    }
}
