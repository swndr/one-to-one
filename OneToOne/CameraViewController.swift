//
//  CameraViewController.swift
//  OneToOne
//
//  Created by Sam Wander on 11/18/15.
//  Copyright © 2015 FBD. All rights reserved.
//

import UIKit
import Parse

class CameraViewController: UIViewController {

    var justPaired = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("Opened camera")
        
        if justPaired {
            print("Show NUX banner")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}
