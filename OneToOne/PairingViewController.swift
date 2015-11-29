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
        
        var timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("update"), userInfo: nil, repeats: true)

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
        
        //instructionLabel.text = "Tell the recipient to enter \(enteredCode) within the next 10:00 to pair."

    }
    
    func update() {
        /*
        var totalTime = 600 // 60 seconds * 10
        var timeElapsed = NSDate().timeIntervalSinceDate((codeObject.createdAt)!)

        let interval = totalTime - timeElapsed
        let componentFormatter = NSDateComponentsFormatter()
        
        componentFormatter.unitsStyle = .Positional
        componentFormatter.zeroFormattingBehavior = .DropAll
        
        if let formattedString = componentFormatter.stringFromDateComponents(<#T##components: NSDateComponents##NSDateComponents#>) {
        print(formattedString) // x:xx
        }
        //returns in seconds
        */

        let timeLeft = String(format:"%02d:%02d", (count/100)%6000, count%100)
        
        //timeLeft.font = UIFont.monospacedDigitSystemFontOfSize(17, weight: UIFontWeightRegular)

        
        
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
        
        // Go to login screen
        if self.parentViewController == nil {
        // We came from login, so can dismiss
            self.dismissViewControllerAnimated(false, completion: nil)
        } else {
            // Pairing was initial VC
            var loginViewController = UIViewController()
            loginViewController = self.storyboard!.instantiateViewControllerWithIdentifier("LoginViewController")
            let containerVC = self.parentViewController!
            containerVC.addChildViewController(loginViewController)
            self.willMoveToParentViewController(nil)
            containerVC.transitionFromViewController(self, toViewController: loginViewController, duration: 0.2, options: [], animations: { () -> Void in
                
                }) { (success) -> Void in
                    loginViewController.didMoveToParentViewController(containerVC)
                    loginViewController.view.frame = self.view.bounds
            }
        }
    }
    
    @IBAction func didPressSendMessage(sender: AnyObject) {
        if MFMessageComposeViewController.canSendText() {
            let messageVC = MFMessageComposeViewController()
            messageVC.messageComposeDelegate = self
            //messageVC.recipients = ["Enter tel-nr"]
            messageVC.body = "Download 1:1 from the App Store and enter code '\(enteredCode)' to pair with me!"
            self.presentViewController(messageVC, animated: true, completion: nil)
        } else {
            print("User hasn't setup Messages.app")
        }
        
    }
    
    
    func messageComposeViewController(controller: MFMessageComposeViewController!, didFinishWithResult result: MessageComposeResult) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    

}



