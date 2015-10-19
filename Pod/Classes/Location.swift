
import Foundation
import MapKit


public enum Status :Int {
    case Available
    case Undetermined
    case Denied
    case Restricted
    case Disabled
}

public enum Service {
    case Google
    case Apple
}

public enum LocationError : ErrorType {
    case ServiceUnavailable
    case Timeout(NSTimeInterval)
    case LocationError(ErrorType)
    case Unknown(String)
    
    init?(_ error:ErrorType?) {
        if error != nil {
            return nil
        }
        self = .LocationError(error!)
    }
}

public let kLocationDidChangeNotification = "LocationDidChange";

extension LocationError : CustomStringConvertible {
    
    public var description: String {
        let str: String
        
        switch self {
        case .ServiceUnavailable:
            str = "Location service is unavaiable: \(Location.state)"
        case .Timeout(let timeout):
            str = "Got timeout: \(timeout)"
        case .LocationError(let error):
            str = "Location error: \(error)"
        case .Unknown(let s):
            str = "Unknown error: \(s)"
        }
        
        return str
    }
    
}

public typealias OnLocationHandler = (location:CLLocation?, error:LocationError?) -> Void
public typealias OnGeocodingHandler = (placemark:CLPlacemark?, error:LocationError?) -> Void

public typealias OnMonitorRegion = (region:CLRegion?, error:LocationError?) -> Void

public enum Accuracy:Int, CustomStringConvertible {
    case None			= 0
    case Country		= 1
    case City			= 2
    case Neighborhood	= 3
    case Block			= 4
    case House			= 5
    case Room			= 6
    
    public var description: String {
        get {
            switch self {
            case .None:
                return "None"
            case .Country:
                return "Country"
            case .City:
                return "City"
            case .Neighborhood:
                return "Neighborhood"
            case .Block:
                return "Block"
            case .House:
                return "House"
            case .Room:
                return "Room"
            }
        }
    }
    
    /**
    This is the threshold of accuracy to validate a location
    
    - returns: value in meters
    */
    func accuracyThreshold() -> Double {
        switch self {
        case .None:
            return Double.infinity
        case .Country:
            return Double.infinity
        case .City:
            return 5000.0
        case .Neighborhood:
            return 1000.0
        case .Block:
            return 100.0
        case .House:
            return 15.0
        case .Room:
            return 5.0
        }
    }
    
    /**
    Time threshold to validate the accuracy of a location
    
    - returns: in seconds
    */
    func timeThreshold() -> Double {
        switch self {
        case .None:
            return Double.infinity
        case .Country:
            return Double.infinity
        case .City:
            return 600.0
        case .Neighborhood:
            return 300.0
        case .Block:
            return 60.0
        case .House:
            return 15.0
        case .Room:
            return 5.0
        }
    }
}


public class Location : NSObject, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var requests: [Request] = []
    private let queue = dispatch_queue_create("LocationRequest", DISPATCH_QUEUE_SERIAL)
    
    let cache: AddressCache
    static let shared = Location()
    
    override private init() {
        self.manager = CLLocationManager()
        self.cache = AddressCache()
        super.init()
        
        self.manager.delegate = self
        self.cache.load()
    }
    
    static var canLocate: Bool {
        return self.state == .Available
    }
    
    static var state: Status {
        get {
            if CLLocationManager.locationServicesEnabled() == false {
                return .Disabled
            } else {
                switch CLLocationManager.authorizationStatus() {
                case .NotDetermined:
                    return .Undetermined
                case .Denied:
                    return .Denied
                case .Restricted:
                    return .Restricted
                case .AuthorizedAlways, .AuthorizedWhenInUse:
                    return .Available
                }
            }
        }
    }
    
    public static func currentLocation(timeout:NSTimeInterval = 10, accuracy:Accuracy = .None, block:OnLocationHandler)  {
        
        if self.state == .Disabled {
            block(location: nil, error:LocationError.ServiceUnavailable)
        }
        
        let request = Request(type: .Once, timeout: timeout, accuracy: accuracy, handler: block)
        
        self.shared.addRequest(request)
        
    }
    
    public static func location(timeout:NSTimeInterval = 10, accuracy:Accuracy = .None, significant: Bool = false, block:OnLocationHandler) -> RequestId {
        if self.state == .Disabled {
            block(location: nil, error:LocationError.ServiceUnavailable)
            return -1
        }
        
        let type: RequestType = significant ? .Significant : .Continuous
        let request = Request(type: type, timeout: timeout, accuracy: accuracy, handler: block)
        
        self.shared.addRequest(request)
        return request.id
    }
    
    public static func placemark (location:CLLocation? = nil, service:Service = .Apple, block: OnGeocodingHandler) {
        
        if location != nil {
            return self.placemark(location!.coordinate, service: service, block: block)
        }
        
        self.currentLocation(accuracy: .Block) {  (location, error) in
            
            if error != nil || location == nil {
                block(placemark: nil, error: error)
            }
            
            self.placemark(location!.coordinate, service:service, block: block)
        }
        
    }
    
    public static func placemark (coordinates:CLLocationCoordinate2D, service:Service = .Apple, block: OnGeocodingHandler) {
        
        switch service {
        case .Apple:
            self.shared.reverseAppleCoodirnates(coordinates, block: block)
        case .Google:
            self.shared.reverseGoogleCoordinates(coordinates, block: block)
        }
        /*let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        
        geocoder.reverseGeocodeLocation(location, completionHandler: { (placemarks, error) in
            if error != nil {
                block(placemark:nil, error: LocationError.LocationError(error!))
            } else {
                if let placemark = placemarks?[0] {
                    let address = LocationParser()
                    address.parseAppleLocationData(placemark)
                    block(placemark: address.getPlacemark(), error:nil)
                } else {
                    block(placemark: nil, error: nil)
                }
            }
        })*/
    }
    
    public static func placemark (address:String, service: Service = .Apple, region:CLRegion? = nil, block: OnGeocodingHandler) {
        
        switch service {
        case .Apple:
            self.shared.reverseAppleAddress(address, region: region, block: block)
        case .Google:
            self.shared.reverseGoogleAddress(address, block: block)
        }
        
    }

    
    //MARK: [Public] Cancel a running request
    
    /**
    Cancel a running request
    
    - parameter identifier: identifier of the request
    
    - returns: true if request is marked as cancelled, no if it was not found
    */
    public static func cancelRequest(identifier: Int) -> Bool {
        
        if let index = shared.requests.indexOf({ $0.id == identifier }) {
            shared.requests[index].markAsCancelled(nil)
        }
        return false
    }
    
    /**
    Mark as cancelled any running request
    */
    public static func cancelAllRequests() {
        for request in shared.requests {
            request.markAsCancelled(nil)
        }
    }
    
    private func addRequest(request:Request) {
        dispatch_sync(self.queue) { () -> Void in
            self.requests.append(request)
            self.updateLocationManagerStatus()
        }
    }
    
    // MARK: - [Private] Apple Reverse Geocoding
    private func reverseAppleCoodirnates(coordinates: CLLocationCoordinate2D, block: OnGeocodingHandler) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        
        geocoder.reverseGeocodeLocation(location, completionHandler: { (placemarks, error) in
            if error != nil {
                block(placemark:nil, error: LocationError.LocationError(error!))
            } else {
                if let placemark = placemarks?[0] {
                    let address = LocationParser()
                    address.parseAppleLocationData(placemark)
                    block(placemark: address.getPlacemark(), error:nil)
                } else {
                    block(placemark: nil, error: nil)
                }
            }
        })
    }
    
    private func reverseAppleAddress(address:String, region:CLRegion?, block: OnGeocodingHandler) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address, inRegion: region) { (placemarks, error) -> Void in
            if error != nil {
                block(placemark:nil, error: LocationError.LocationError(error!))
            } else {
                if let placemark = placemarks?[0] {
                    let address = LocationParser()
                    address.parseAppleLocationData(placemark)
                    block(placemark: address.getPlacemark(), error:nil)
                } else {
                    block(placemark: nil, error: nil)
                }
            }
        }
    }
    

    //MARK: [Private] Google / Reverse Geocoding
    
    private func reverseGoogleCoordinates(coordinates: CLLocationCoordinate2D!, block:OnGeocodingHandler) {
        var APIURLString = "https://maps.googleapis.com/maps/api/geocode/json?latlng=\(coordinates.latitude),\(coordinates.longitude)" as NSString
        print(APIURLString)
        APIURLString = APIURLString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
        let APIURL = NSURL(string: APIURLString as String)
        let APIURLRequest = NSURLRequest(URL: APIURL!)
        NSURLConnection.sendAsynchronousRequest(APIURLRequest, queue: NSOperationQueue.mainQueue()) { (response, data, error) in
            if error != nil {
                return block(placemark: nil, error: LocationError.LocationError(error!))
            }
            
            if data != nil {
                let jsonResult: NSDictionary = (try! NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary
                let (error,noResults) = self.validateGoogleJSONResponse(jsonResult)
                if noResults == true || error != nil { // request is ok but not results are returned
                    block(placemark: nil, error: LocationError(error))
                } else { // we have some good results to show
                    let address = LocationParser()
                    address.parseGoogleLocationData(jsonResult)
                    let placemark:CLPlacemark = address.getPlacemark()
                    block(placemark: placemark, error: nil)
                }
            }
        }
    }
    
    private func reverseGoogleAddress(address: String!, block:OnGeocodingHandler) {
        var APIURLString = "https://maps.googleapis.com/maps/api/geocode/json?address=\(address)" as NSString
        APIURLString = APIURLString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
        let APIURL = NSURL(string: APIURLString as String)
        let APIURLRequest = NSURLRequest(URL: APIURL!)
        NSURLConnection.sendAsynchronousRequest(APIURLRequest, queue: NSOperationQueue.mainQueue()) { (response, data, error) in
            if error != nil {
                return block(placemark: nil, error: .LocationError(error!))
            }
            
            if data != nil {
                let jsonResult: NSDictionary = (try! NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary
                let (error,noResults) = self.validateGoogleJSONResponse(jsonResult)
                if noResults == true || error != nil { // request is ok but not results are returned
                    block(placemark: nil, error: LocationError(error))
                } else { // we have some good results to show
                    let address = LocationParser()
                    address.parseGoogleLocationData(jsonResult)
                    let placemark:CLPlacemark = address.getPlacemark()
                    block(placemark: placemark, error: nil)
                }
            }
        }
    }
    
    private func validateGoogleJSONResponse(jsonResult: NSDictionary!) -> (error: NSError?, noResults: Bool!) {
        var status = jsonResult.valueForKey("status") as! NSString
        status = status.lowercaseString
        if status.isEqualToString("ok") == true { // everything is fine, the sun is shining and we have results!
            return (nil,false)
        } else if status.isEqualToString("zero_results") == true { // No results error
            return (nil,true)
        } else if status.isEqualToString("over_query_limit") == true { // Quota limit was excedeed
            let message	= "Query quota limit was exceeded"
            return (NSError(domain: NSCocoaErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : message]),false)
        } else if status.isEqualToString("request_denied") == true { // Request was denied
            let message	= "Request denied"
            return (NSError(domain: NSCocoaErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : message]),false)
        } else if status.isEqualToString("invalid_request") == true { // Invalid parameters
            let message	= "Invalid input sent"
            return (NSError(domain: NSCocoaErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : message]),false)
        }
        return (nil,false) // okay!
    }
    
    
    /**
    This method return the highest accuracy you want to receive into the current bucket of requests
    
    - returns: highest accuracy level you want to receive
    */
    private func highestRequiredAccuracy() -> CLLocationAccuracy {
        var highestAccuracy = CLLocationAccuracy(Double.infinity)
        for request in requests {
            let accuracyLevel = CLLocationAccuracy(request.accuracy.accuracyThreshold())
            if accuracyLevel < highestAccuracy {
                highestAccuracy = accuracyLevel
            }
        }
        return highestAccuracy
    }
    
    /**
    Return true if a request into the pool is of type described by the list of types passed
    
    - parameter list: allowed types
    
    - returns: true if at least one request with one the specified type is running
    */
    private func hasActiveRequests(list: [RequestType]) -> Bool! {
        for request in requests {
            let idx = list.indexOf(request.type)
            if idx != nil {
                return true
            }
        }
        return false
    }
    
    /**
    Return the list of all request of a certain type
    
    - parameter list: list of types to filter
    
    - returns: output list with filtered active requests
    */
    private func activeRequests(list: [RequestType]) -> [Request] {
        var filteredList : [Request] = []
        for request in requests {
            let idx = list.indexOf(request.type)
            if idx != nil {
                filteredList.append(request)
            }
        }
        return filteredList
    }
    
    
    /**
    This method simply turn off/on hardware required by the list of active running requests.
    The same method also ask to the user permissions to user core location.
    */
    private func updateLocationManagerStatus() {
        if requests.count > 0 {
            let hasAlwaysKey = (NSBundle.mainBundle().objectForInfoDictionaryKey("NSLocationAlwaysUsageDescription") != nil)
            let hasWhenInUseKey = (NSBundle.mainBundle().objectForInfoDictionaryKey("NSLocationWhenInUseUsageDescription") != nil)
            if hasAlwaysKey == true {
                manager.requestAlwaysAuthorization()
            } else if hasWhenInUseKey == true {
                manager.requestWhenInUseAuthorization()
            } else {
                // You've forgot something essential
                assert(false, "To use location services in iOS 8+, your Info.plist must provide a value for either NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription.")
            }
        }
        
        // Location Update
        if hasActiveRequests([RequestType.Continuous, RequestType.Once]) == true {
            let requiredAccuracy = self.highestRequiredAccuracy()
            if requiredAccuracy != manager.desiredAccuracy {
                manager.stopUpdatingLocation()
                manager.desiredAccuracy = requiredAccuracy
            }
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
        }
        // Significant Location Changes
        if hasActiveRequests([RequestType.Significant]) == true {
            manager.startMonitoringSignificantLocationChanges()
        } else {
            manager.stopMonitoringSignificantLocationChanges()
        }
        /*// Beacon/Region monitor is turned off automatically on completeRequest()
        let beaconRegions = self.activeRequests([RequestType.BeaconRegionProximity])
        for beaconRegion in beaconRegions {
            manager.startRangingBeaconsInRegion(beaconRegion.beaconReg!)
        }*/
    }
    
    /**
    In case of an error we want to expire all queued notifications
    
    - parameter error: error to notify
    */
    private func expireAllRequests(error: NSError?, types: [RequestType]?) {
        for request in requests {
            let canMark = (types == nil ? true : (types!.indexOf(request.type) != nil))
            if canMark == true {
                let e: LocationError? = error != nil ? LocationError.LocationError(error!) : nil
                request.markAsCancelled(e)
            }
        }
    }
    
    func completeRequest(request: Request, location: CLLocation?, error:LocationError?) {
        if request.type == RequestType.RegionMonitor { // If request is a region monitor we need to explictly stop it
            manager.stopMonitoringForRegion(request.region!)
        } /*else if (request.type == RequestType.BeaconRegionProximity) { // If request is a proximity beacon monitor we need to explictly stop it
            //manager.stopRangingBeaconsInRegion(request.beaconReg!)
        }*/
        
        // Sync remove item from requests pool
        dispatch_sync(queue) {
            //var idx = 0
            
            if !self.requests.contains(request) {
                return
            }
            
            request.stopTimeout()
            
            if request.type == .Significant ||
                request.type == .Continuous ||
                request.type == .Once {
                request.handler?(location: location, error: error)
            }
            
            
            if request.isCancelled == true || !(request.type == .Continuous || request.type == .Significant) {
                self.requests.removeAtIndex(self.requests.indexOf(request)!)
            }
            // Turn off any non-used hardware based upon the new list of running requests
            self.updateLocationManagerStatus()
        }
    }
    
    
    //MARK: [Private] Location Manager Delegate
    public func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationsReceived(locations)
    }
    
    private func locationsReceived(locations: [AnyObject]!) {
        if let location = locations.last as? CLLocation {
            NSNotificationCenter.defaultCenter().postNotificationName(kLocationDidChangeNotification, object: location)
            for request in requests {
                if request.isAcceptable(location) == true {
                    completeRequest(request, location: location, error: nil)
                }
            }
        }
    }
    
    public func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        let expiredTypes = [RequestType.Continuous,
            RequestType.Significant,
            RequestType.Once,
            RequestType.HeadingUpdate,
            RequestType.RegionMonitor]
        expireAllRequests(error, types: expiredTypes)
    }
    
    public func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == CLAuthorizationStatus.Denied || status == CLAuthorizationStatus.Restricted {
            // Clear out any pending location requests (which will execute the blocks with a status that reflects
            // the unavailability of location services) since we now no longer have location services permissions
            let err = NSError(domain: NSCocoaErrorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey : "Location services denied/restricted by parental control"])
            locationManager(manager, didFailWithError: err)
        } else if status == CLAuthorizationStatus.AuthorizedAlways || status == CLAuthorizationStatus.AuthorizedWhenInUse {
            for request in requests {
                request.startTimeout(nil)
            }
            updateLocationManagerStatus()
        } else if status == CLAuthorizationStatus.NotDetermined {
            
        }
    }
    
    public func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let idx = requests.indexOf({ $0.type == .RegionMonitor && $0.region == region}) {
            requests[idx].enter?(region: region,error: nil)
        }
    }
    
    public func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let idx = requests.indexOf({ $0.type == .RegionMonitor && $0.region == region}) {
            requests[idx].exit?(region: region,error: nil)
        }
    }
    
    public func locationManager(manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], inRegion region: CLBeaconRegion) {
        /*for request in requests {
            if request.beaconReg == region {
                request.onRangingBeaconEvent?(beacons: beacons)
            }
        }*/
    }
    
    public func locationManager(manager: CLLocationManager, rangingBeaconsDidFailForRegion region: CLBeaconRegion, withError error: NSError) {
        //let expiredTypes = [RequestType.BeaconRegionProximity]
        //expireAllRequests(error, types: expiredTypes)
    }
}