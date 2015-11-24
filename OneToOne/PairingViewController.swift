//
//  PairingViewController.swift
//  OneToOne
//
//  Created by Sam Wander on 11/18/15.
//  Copyright © 2015 FBD. All rights reserved.
//

import UIKit
import Parse
import MessageUI

class PairingViewController: UIViewController, MFMessageComposeViewControllerDelegate{

    var enteredCode = ""
    @IBOutlet weak var instructionLabel: UILabel!
    var count = 1000
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let user = PFUser.currentUser()
        
        // Not getting downloaded before label loads ** fix this **
        if enteredCode == "" && user != nil {
            let query = PFQuery(className:"AccountCode")
            query.whereKey("code", equalTo:(user!["code"])) // The code they signed up with is stored with the user
            query.findObjectsInBackgroundWithBlock {
                (objects: [PFObject]?, error: NSError?) -> Void in
                
                if error == nil {
                    // Found a code
                    if objects!.count == 1 {
                        // Existing code entry
                        let code = objects!.first
                        self.enteredCode = code!["code"] as! String
                    }
                }
            }
        }
        
        
        var timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("update"), userInfo: nil, repeats: true)

        /*
        instructionLabel.text = "Tell the recipient to enter \(enteredCode) within the next \(timeLeft) to pair."*/
        
        if user != nil {
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
    }
    
    func update() {
        let timeLeft = String(format:"%02d:%02d", (count/100)%6000, count%100)
        
        if(count > 0)
        {
            count--
            instructionLabel.text = "Tell the recipient to enter \(enteredCode) within the next \(timeLeft) to pair."
            
        }
        
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
        //self.performSegueWithIdentifier("loginSegue", sender: self)
    }
    @IBAction func didPressSendMessage(sender: AnyObject) {
        if MFMessageComposeViewController.canSendText() {
            let messageVC = MFMessageComposeViewController()
            messageVC.messageComposeDelegate = self
            messageVC.recipients = ["Enter tel-nr"]
            messageVC.body = "Download 1:1 (url) and enter code '\(enteredCode)' to  pair with me!"
            self.presentViewController(messageVC, animated: true, completion: nil)
        } else {
            print("User hasn't setup Messages.app")
        }
        
    }
    
    
    func messageComposeViewController(controller: MFMessageComposeViewController!, didFinishWithResult result: MessageComposeResult) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    

}



