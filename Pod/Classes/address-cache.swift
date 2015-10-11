//
//  address-cache.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 11/10/2015.
//
//

import Foundation

//
//  Cache.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 25/06/15.
//
//

import Foundation
import MapKit

class CacheItem : Equatable {
    var address: Address
    var key: String
    
    init(address: Address) {
        self.address = address
        self.key = "\(address.city.name), \(address.country.name)"
    }
    
    init(key: String, address: Address) {
        self.address = address
        self.key = key
    }
    
    func check(location:CLLocation) -> Bool {
        return self.address.location.compare(location, precision: 100)
    }
    
    func check(key: String) -> Bool {
        if self.key == key {
            return true
        }
        return false
    }
}

func ==(lhs:CacheItem, rhs: CacheItem) -> Bool {
    return lhs.address.location == rhs.address.location
}

class AddressCache {
    var store: [CacheItem] = []
    var storePath : String {
        return (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("address_cache.lm")
    }
    
    init () {
        self.load()
    }
    
    func set (address: Address) {
        
        let item = CacheItem(address: address)
        if self.store.contains(item) {
            return
        }
        
        self.store.append(item)
        
    }
    
    func set (key: String, address: Address) {
        
        let addr = self.get(key)
        
        if addr == nil {
            let item = CacheItem(key: key, address: address)
            self.store.append(item)
        }
        
        
    }
    
    func get (location: CLLocation) -> Address? {
        return self.get(location, precision: 20)
    }
    
    func get (location: CLLocation, precision: CLLocationDistance) -> Address? {
        for item in self.store {
            if item.check(location) {
                return item.address
            }
        }
        
        return nil
    }
    
    func get(key: String) -> Address? {
        for item in self.store {
            if item.check(key) {
                return item.address
            }
        }
        return nil
    }
    
    func save() {
        
        var dict = Dictionary<String,Address>()
        
        for item in self.store {
            dict[item.key] = item.address
        }
        
        NSKeyedArchiver.archiveRootObject(dict, toFile: self.storePath)
        
    }
    
    func load () {
        if !NSFileManager.defaultManager().isReadableFileAtPath(self.storePath) {
            return
        }
        
        let data: AnyObject? = NSKeyedUnarchiver.unarchiveObjectWithFile(self.storePath)
        
        if let dict = data as? Dictionary<String, Address> {
            
            for (key, item) in dict {
                self.set(key, address: item)
            }
            
        }
        
    }
}
