//
//  LocationParser.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 09/10/2015.
//
//

import Foundation
import MapKit
// Portions of this class are part of the LocationManager mady by varshylmobile (AddressParser class):
// (Made by https://github.com/varshylmobile/LocationManager)

class LocationParser: NSObject {
    private var latitude = NSString()
    private var longitude  = NSString()
    private var streetNumber = NSString()
    private var route = NSString()
    private var locality = NSString()
    private var subLocality = NSString()
    private var formattedAddress = NSString()
    private var administrativeArea = NSString()
    private var administrativeAreaCode = NSString()
    private var subAdministrativeArea = NSString()
    private var postalCode = NSString()
    private var country = NSString()
    private var subThoroughfare = NSString()
    private var thoroughfare = NSString()
    private var ISOcountryCode = NSString()
    private var state = NSString()
    
    override init() {
        super.init()
    }
    
    private func parseIPLocationData(JSON: NSDictionary) -> Bool {
        let status = JSON["status"] as? String
        if status != "success" {
            return false
        }
        self.country = JSON["country"] as! NSString
        self.ISOcountryCode = JSON["countryCode"] as! NSString
        if let lat = JSON["lat"] as? NSNumber, lon = JSON["lon"] as? NSNumber {
            self.longitude = lat.description
            self.latitude = lon.description
        }
        self.postalCode = JSON["zip"] as! NSString
        return true
    }
    
    func parseAppleLocationData(placemark:CLPlacemark) {
        let addressLines = placemark.addressDictionary?["FormattedAddressLines"] as! NSArray
        
        //self.streetNumber = placemark.subThoroughfare ? placemark.subThoroughfare : ""
        self.streetNumber = placemark.thoroughfare ?? ""
        self.locality = placemark.locality ?? ""
        self.postalCode = placemark.postalCode ?? ""
        self.subLocality = placemark.subLocality ?? ""
        self.administrativeArea = placemark.administrativeArea ?? ""
        self.country = placemark.country ?? ""
        if let location = placemark.location {
            self.longitude = location.coordinate.longitude.description;
            self.latitude = location.coordinate.latitude.description
        }
        if addressLines.count>0 {
            self.formattedAddress = addressLines.componentsJoinedByString(", ")
        } else {
            self.formattedAddress = ""
        }
    }
    
    private func parseGoogleLocationData(resultDict:NSDictionary) {
        let locationDict = (resultDict.valueForKey("results") as! NSArray).firstObject as! NSDictionary
        let formattedAddrs = locationDict.objectForKey("formatted_address") as! NSString
        
        let geometry = locationDict.objectForKey("geometry") as! NSDictionary
        let location = geometry.objectForKey("location") as! NSDictionary
        let lat = location.objectForKey("lat") as! Double
        let lng = location.objectForKey("lng") as! Double
        
        self.latitude = lat.description
        self.longitude = lng.description
        
        let addressComponents = locationDict.objectForKey("address_components") as! NSArray
        self.subThoroughfare = component("street_number", inArray: addressComponents, ofType: "long_name")
        self.thoroughfare = component("route", inArray: addressComponents, ofType: "long_name")
        self.streetNumber = self.subThoroughfare
        self.locality = component("locality", inArray: addressComponents, ofType: "long_name")
        self.postalCode = component("postal_code", inArray: addressComponents, ofType: "long_name")
        self.route = component("route", inArray: addressComponents, ofType: "long_name")
        self.subLocality = component("subLocality", inArray: addressComponents, ofType: "long_name")
        self.administrativeArea = component("administrative_area_level_1", inArray: addressComponents, ofType: "long_name")
        self.administrativeAreaCode = component("administrative_area_level_1", inArray: addressComponents, ofType: "short_name")
        self.subAdministrativeArea = component("administrative_area_level_2", inArray: addressComponents, ofType: "long_name")
        self.country =  component("country", inArray: addressComponents, ofType: "long_name")
        self.ISOcountryCode =  component("country", inArray: addressComponents, ofType: "short_name")
        self.formattedAddress = formattedAddrs;
    }
    
    func getPlacemark() -> CLPlacemark {
        var addressDict = [String:AnyObject]()
        let formattedAddressArray = self.formattedAddress.componentsSeparatedByString(", ") as Array
        
        let kSubAdministrativeArea = "SubAdministrativeArea"
        let kSubLocality           = "SubLocality"
        let kState                 = "State"
        let kStreet                = "Street"
        let kThoroughfare          = "Thoroughfare"
        let kFormattedAddressLines = "FormattedAddressLines"
        let kSubThoroughfare       = "SubThoroughfare"
        let kPostCodeExtension     = "PostCodeExtension"
        let kCity                  = "City"
        let kZIP                   = "ZIP"
        let kCountry               = "Country"
        let kCountryCode           = "CountryCode"
        
        addressDict[kSubAdministrativeArea] = self.subAdministrativeArea
        addressDict[kSubLocality] = self.subLocality
        addressDict[kState] = self.administrativeAreaCode
        addressDict[kStreet] = formattedAddressArray.first! as NSString
        addressDict[kThoroughfare] = self.thoroughfare
        addressDict[kFormattedAddressLines] = formattedAddressArray
        addressDict[kSubThoroughfare] = self.subThoroughfare
        addressDict[kPostCodeExtension] = ""
        addressDict[kCity] = self.locality
        addressDict[kZIP] = self.postalCode
        addressDict[kCountry] = self.country
        addressDict[kCountryCode] = self.ISOcountryCode
        
        let lat = self.latitude.doubleValue
        let lng = self.longitude.doubleValue
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        
        let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: addressDict)
        return (placemark as CLPlacemark)
    }
    
    private func component(component:NSString,inArray:NSArray,ofType:NSString) -> NSString {
        let index:NSInteger = inArray.indexOfObjectPassingTest { (obj, idx, stop) -> Bool in
            
            let objDict:NSDictionary = obj as! NSDictionary
            let types:NSArray = objDict.objectForKey("types") as! NSArray
            let type = types.firstObject as! NSString
            return type.isEqualToString(component as String)
        }
        
        if index == NSNotFound {
            return ""
        }
        
        if index >= inArray.count {
            return ""
        }
        
        let type = ((inArray.objectAtIndex(index) as! NSDictionary).valueForKey(ofType as String)!) as! NSString
        
        if type.length > 0 {
            
            return type
        }
        return ""
    }
}