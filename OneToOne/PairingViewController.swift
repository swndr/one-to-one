//
//  PairingViewController.swift
//  OneToOne
//
//  Created by Sam Wander on 11/18/15.
//  Copyright © 2015 FBD. All rights reserved.
//

import UIKit
import Parse

class PairingViewController: UIViewController {

    var enteredCode = ""
    @IBOutlet weak var instructionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let user = PFUser.currentUser()
        
        if user != nil {
            
            if enteredCode == "" {
                enteredCode = user!["code"] as! String
            }
            
            attemptToPair(user!) { (result, userStatus) -> Void in
                if result {
                    switch userStatus {
                    case .Paired:
                        print("Now paired")
                        // Go to camera screen
                        self.performSegueWithIdentifier("cameraSegue", sender: self)
                    default:
                        print("Still not paired") // Getting called twice ** investigate
                    }
                }
            }
        }
        
        instructionLabel.text = "Tell the recipient to enter \(enteredCode) within the next 10:00 to pair."

    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "cameraSegue" {
            if let destinationVC = segue.destinationViewController as? CameraViewController {
                destinationVC.justPaired = true
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func didPressCancel(sender: AnyObject) {
        // Go to login screen ** maybe need to figure appropriate animation for this? **
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        var loginViewController: UIViewController!
        loginViewController = storyboard.instantiateViewControllerWithIdentifier("LoginViewController")
        self.addChildViewController(loginViewController)
        loginViewController.view.frame = self.view.bounds
        self.view.addSubview(loginViewController.view)
        loginViewController.didMoveToParentViewController(self)

        /*
        self.transitionFromViewController(self, toViewController: loginViewController, duration: 0.2, options: UIViewAnimationOptions.TransitionCrossDissolve, animations: { () -> Void in
            
            }) { (success) -> Void in
                //self.removeFromParentViewController()
                loginViewController.didMoveToParentViewController(self)
                loginViewController.view.frame = self.view.bounds
        }*/
    }

}
