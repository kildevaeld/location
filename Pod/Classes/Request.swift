//
//  Request.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 08/10/2015.
//
//

import Foundation
import MapKit

private extension CLLocation {
    func accuracyOfLocation() -> Accuracy! {
        let timeSinceUpdate = fabs( self.timestamp.timeIntervalSinceNow )
        let horizontalAccuracy = self.horizontalAccuracy
        
        if horizontalAccuracy <= Accuracy.Room.accuracyThreshold() &&
            timeSinceUpdate <= Accuracy.Room.timeThreshold() {
                return Accuracy.Room
                
        } else if horizontalAccuracy <= Accuracy.House.accuracyThreshold() &&
            timeSinceUpdate <= Accuracy.House.timeThreshold() {
                return Accuracy.House
                
        } else if horizontalAccuracy <= Accuracy.Block.accuracyThreshold() &&
            timeSinceUpdate <= Accuracy.Block.timeThreshold() {
                return Accuracy.Block
                
        } else if horizontalAccuracy <= Accuracy.Neighborhood.accuracyThreshold() &&
            timeSinceUpdate <= Accuracy.Neighborhood.timeThreshold() {
                return Accuracy.Neighborhood
                
        } else if horizontalAccuracy <= Accuracy.City.accuracyThreshold() &&
            timeSinceUpdate <= Accuracy.City.timeThreshold() {
                return Accuracy.City
        } else {
            return Accuracy.None
        }
    }
}



enum RequestType {
    case Significant
    case Continuous
    case Once
    case RegionMonitor
    case HeadingUpdate
}

public typealias RequestId = Int

private var idCounter: RequestId = 0


public class Request : NSObject {
    let id: RequestId
    let type: RequestType
    let timeout: NSTimeInterval
    let accuracy: Accuracy
    let handler: OnLocationHandler?
    let enter: OnMonitorRegion?
    let exit: OnMonitorRegion?
    let region: CLRegion?
    private(set) var isCancelled: Bool = false
    private var timer: NSTimer? = nil
    init (type:RequestType, timeout:NSTimeInterval, accuracy:Accuracy, handler: OnLocationHandler) {
        self.id = ++idCounter
        self.type = type
        self.accuracy = accuracy
        self.timeout = timeout
        self.handler = handler
        self.exit = nil
        self.enter = nil
        self.region = nil
        super.init()
        if Location.canLocate {
            self.startTimeout(nil)
        }
        
    }
    
    init (region:CLRegion, onEnter:OnMonitorRegion? , onExit: OnMonitorRegion?) {
        self.id = ++idCounter
        self.type = .RegionMonitor

        self.enter = onEnter
        self.exit = onExit
        self.handler = nil
        self.accuracy = .None
        self.timeout = 0
        self.region = region
        super.init()
        
        if Location.canLocate {
            self.startTimeout(nil)
        }
        
    }
    
    
    
    
    func isAcceptable(location: CLLocation) -> Bool! {
        if isCancelled == true {
            return false
        }
        if self.accuracy == Accuracy.None {
            return true
        }
        let locAccuracy: Accuracy! = location.accuracyOfLocation()
        let valid = (locAccuracy.rawValue >= self.accuracy.rawValue)
        return valid
    }
    
    func markAsCancelled (error:LocationError?) {
        self.isCancelled = true
        self.stopTimeout()
        Location.shared.completeRequest(self, location:nil, error:error)
    }
    
    func startTimeout(forceValue: NSTimeInterval?) {
        self.stopTimeout()
        if timeout > 0 {
            let value = (forceValue != nil ? forceValue! : timeout)
            timer = NSTimer.scheduledTimerWithTimeInterval(value, target: self, selector: "timeoutReached", userInfo: nil, repeats: false)
        
            
        }
    }
    
    func stopTimeout() {
        timer?.invalidate()
        timer = nil
    }
    
    public func timeoutReached() {
        
        self.stopTimeout()
        isCancelled = false
        
        Location.shared.completeRequest(self, location: nil, error: LocationError.Timeout(self.timeout))
    }
}

public func ==(lhs:Request, rhs:Request) -> Bool {
    return lhs.id == rhs.id
}