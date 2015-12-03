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
    
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var sendMessageButton: UIButton!
    var enteredCode = ""
    
    // Starting elapsed time at 0 so on first loading we can show 10:00 remaining
    var elapsedTime: NSTimeInterval = 0
    
    let user = PFUser.currentUser()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Update every second
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
                        self.performSegueWithIdentifier("pairingToCameraSegue", sender: self)
                    default:
                        print("Still not paired")
                    }
                }
            }
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        // Add notif observer (may need to remove too?)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "respondToNotif:", name: "justPaired", object: nil)
        
        // When view appears, get interval since code created time from Parse
        getCodeCreatedTime { (interval, result) -> Void in
            if result {
                self.elapsedTime = interval
            }
        }
    }
    
    func update() {

        // Get time since code created
        let duration = Int(elapsedTime)
        let secondsRemaining = 600 - duration
        
        // Convert int to mm:ss
        let time = secondsRemaining
        let minutes = (time / 60) % 60
        let seconds = time % 60
        let timeRemaining = String(format:"%02d:%02d", minutes, seconds)
        
        // Digits are monospaced
        instructionLabel.font = UIFont.monospacedDigitSystemFontOfSize(18, weight: UIFontWeightRegular)

        // Update code + time remaining message
        if(elapsedTime < 600.00)
        {
            self.elapsedTime++
            instructionLabel.text = "Tell the recipient to enter \(enteredCode) within the next \(timeRemaining) to pair."
        } else {
            let alertController = UIAlertController(title: "Expired Code", message: "Your code '\(enteredCode)' has expired. Please try again by creating a new code.", preferredStyle: .Alert)
            let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
            }
            alertController.addAction(OKAction)
            self.presentViewController(alertController, animated: true) {
                // ** Close and return to LoginViewController **fix
            }
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "pairingToCameraSegue" {
            if let destinationVC = segue.destinationViewController as? CameraViewController {
                destinationVC.justPaired = true
            }
        }
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
    
    func messageComposeViewController(controller: MFMessageComposeViewController, didFinishWithResult result: MessageComposeResult) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func respondToNotif(userInfo:NSNotification) {
        attemptToPair(user!) { (result, userStatus) -> Void in
            if result {
                switch userStatus {
                case .Paired:
                    print("Now paired")
                    // Go to camera screen
                    self.performSegueWithIdentifier("pairingToCameraSegue", sender: self)
                default:
                    print("Still not paired")
                }
            }
        }
        
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}



