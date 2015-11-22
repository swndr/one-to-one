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
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        loginViewController = storyboard.instantiateViewControllerWithIdentifier("LoginViewController")
        pairingViewController = storyboard.instantiateViewControllerWithIdentifier("PairingViewController")
        cameraViewController = storyboard.instantiateViewControllerWithIdentifier("CameraViewController")

        self.addChildViewController(loginViewController)
        loginViewController.view.frame = self.view.bounds
        self.view.addSubview(loginViewController.view)
        loginViewController.didMoveToParentViewController(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
