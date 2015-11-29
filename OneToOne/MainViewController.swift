//
//  MainViewController.swift
//  OneToOne
//
//  Created by Matt Chan on 11/18/15.
//  Copyright © 2015 FBD. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {

    @IBOutlet weak var contentView: UIView!
    
    var loginViewController: UIViewController!
    var pairingViewController: UIViewController!
    var cameraViewController: UIViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
