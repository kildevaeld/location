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


enum AddressKey: String {
    case SubAdministrativeArea = "SubAdministrativeArea"
    case SubLocality           = "SubLocality"
    case State                 = "State"
    case Street                = "Street"
    case Thoroughfare          = "Thoroughfare"
    case FormattedAddressLines = "FormattedAddressLines"
    case SubThoroughfare       = "SubThoroughfare"
    case PostCodeExtension     = "PostCodeExtension"
    case City                  = "City"
    case ZIP                   = "ZIP"
    case Country               = "Country"
    case CountryCode           = "CountryCode"
}

struct AddressDictionary {
    var values : [ AddressKey: AnyObject]

    subscript(index:AddressKey) -> AnyObject? {
        get {
            return values[index]
        }
        set (value) {
            values[index] = value
        }
    }

    init(address:Address) {
        self.values = [
            .Street: address.street,
            .ZIP: address.zipCode,
            .CountryCode: address.country.iso,
            .Country: address.country.name,
            .City: address.city.name,
        ]
    }
    
    init () {
        self.values = [:]
    }

    func placemark (location:CLLocation) -> CLPlacemark {
        return self.placemark(location.coordinate)
    }

    func placemark (coordinate:CLLocationCoordinate2D) -> CLPlacemark {

        let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: self.dictionary)
        return (placemark as CLPlacemark)
    }

    var dictionary : [String:AnyObject] {
        var out: [String: AnyObject] = [:]
        for (k, v) in self.values {
            out[k.rawValue] = v
        }
        return out

    }
}

class LocationParser: NSObject {
    private var latitude = 0.0
    private var longitude  = 0.0
    private var streetNumber = ""
    private var route = ""
    private var locality = ""
    private var subLocality = ""
    private var formattedAddress = ""
    private var administrativeArea = ""
    private var administrativeAreaCode = ""
    private var subAdministrativeArea = ""
    private var postalCode = ""
    private var country = ""
    private var subThoroughfare = "" // number
    private var thoroughfare = "" // street
    private var ISOcountryCode = ""
    private var state = ""

    override init() {
        super.init()
    }

    private func parseIPLocationData(JSON: NSDictionary) -> Bool {
        let status = JSON["status"] as? String
        if status != "success" {
            return false
        }
        self.country = JSON["country"]  as! String//as! NSString
        self.ISOcountryCode = JSON["countryCode"] as! String
        if let lat = JSON["lat"] as? Double, lon = JSON["lon"] as? Double {
            self.longitude = lat
            self.latitude = lon
        }
        self.postalCode = JSON["zip"] as! String
        
        return true
    }

    func parseAppleLocationData(placemark:CLPlacemark) {
        let addressLines = placemark.addressDictionary?["FormattedAddressLines"] as! NSArray

        //self.streetNumber = placemark.subThoroughfare ? placemark.subThoroughfare : ""

        self.thoroughfare = placemark.thoroughfare ?? ""
        self.subThoroughfare = placemark.subThoroughfare ?? ""
        self.locality = placemark.locality ?? ""
        self.postalCode = placemark.postalCode ?? ""
        self.subLocality = placemark.subLocality ?? ""
        self.administrativeArea = placemark.administrativeArea ?? ""
        self.country = placemark.country ?? ""
        self.ISOcountryCode = placemark.ISOcountryCode ?? ""
        if let location = placemark.location {
            self.longitude = location.coordinate.longitude;
            self.latitude = location.coordinate.latitude
        }
        if addressLines.count>0 {
            self.formattedAddress = addressLines.componentsJoinedByString(", ")
        } else {
            self.formattedAddress = ""
        }
    }

    func parseGoogleLocationData(resultDict:NSDictionary) {
        let locationDict = (resultDict.valueForKey("results") as! NSArray).firstObject as! NSDictionary
        let formattedAddrs = locationDict.objectForKey("formatted_address") as! String

        let geometry = locationDict.objectForKey("geometry") as! NSDictionary
        let location = geometry.objectForKey("location") as! NSDictionary
        let lat = location.objectForKey("lat") as! Double
        let lng = location.objectForKey("lng") as! Double

        self.latitude = lat
        self.longitude = lng

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
        self.formattedAddress = formattedAddrs as String;
    }

    func getPlacemark() -> CLPlacemark {
        //var addressDict = [String:AnyObject]()

        var addressDict = AddressDictionary()

        let formattedAddressArray = self.formattedAddress.componentsSeparatedByString(", ") as Array

        addressDict[.SubAdministrativeArea] = self.subAdministrativeArea
        addressDict[.SubLocality] = self.subLocality
        addressDict[.State] = self.administrativeAreaCode
        addressDict[.Street] = formattedAddressArray.first!
        addressDict[.Thoroughfare] = self.thoroughfare
        addressDict[.FormattedAddressLines] = formattedAddressArray
        addressDict[.SubThoroughfare] = self.subThoroughfare
        addressDict[.PostCodeExtension] = ""
        addressDict[.City] = self.locality
        addressDict[.ZIP] = self.postalCode
        addressDict[.Country] = self.country
        addressDict[.CountryCode] = self.ISOcountryCode

        let lat = self.latitude
        let lng = self.longitude
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)

        return addressDict.placemark(coordinate)
    }

    private func component(component:String,inArray:NSArray,ofType:String) -> String {
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
        let item = inArray.objectAtIndex(index).valueForKey(ofType)
        //let type = (inArray.objectAtIndex(index) as! NSDictionary).valueForKey(ofType)!

        if item != nil {

            return item as! String
        }
        return ""
    }
}