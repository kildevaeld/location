//
//  ViewController.swift
//  Location
//
//  Created by Softshag & Me on 10/08/2015.
//  Copyright (c) 2015 Softshag & Me. All rights reserved.
//

import UIKit
import Location
class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        Location.address(service:.Google) { (location, error) in
            print("Found location \(location) - \(error)")
        }
        
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

