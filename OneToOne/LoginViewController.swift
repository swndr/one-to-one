//
//  PairingViewController.swift
//  one-to-one
//
//  Created by Matt Chan on 11/16/15.
//  Copyright © 2015 matt. All rights reserved.
//

import UIKit
import Parse

class LoginViewController: UIViewController {
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var pairingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var PairingTextParentView: UIView!
    
    var returningFromPairing = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let user = PFUser.currentUser()
        
        if user == nil {
            // Create anonymous user
            createAnonUser()
        } else if user!["recipient"] as? String == "pending" {
            print("Found existing user")
            // This user cancelled from pairing, or had an expired code ** not completely sure about this logic! **
            returningFromPairing = true
            deleteCode(user!) { (result) -> Void in
                if result {
                    // Query succeeded, may or may not have had to delete a code
                } else {
                    // Querying code failed, should we retry?
                }
            }
        }
        
        nextButton.alpha = 0
        textField.text = ""
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:",
            name: UIKeyboardWillShowNotification, object: nil)
        
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:",
            name: UIKeyboardWillHideNotification, object: nil)
        
    }
    
    override func viewWillAppear(animated: Bool) {
        textField.text = ""
    }
    
    @IBAction func didPressNext(sender: AnyObject) {
        self.pairingIndicator.startAnimating()
        nextButton.selected = true
        
        validateCode(textField.text!) { (result, codeStatus, code) -> Void in
            
            if result {
                switch codeStatus {
                case .None:
                    // New code
                    self.pairingIndicator.stopAnimating()
                    if !self.returningFromPairing {
                        // Create new user
                        createUser(self.textField.text!, completion: { (success) -> Void in
                            if success {
                                // Go to pairing screen
                                self.performSegueWithIdentifier("pairingSegue", sender: self)
                            } else {
                                let alertController = UIAlertController(title: "Please try again", message: "There was a problem creating your account.", preferredStyle: .Alert)
                                let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
                                    // Focus textfield again
                                }
                                alertController.addAction(OKAction)
                                self.presentViewController(alertController, animated: true) {
                                }
                            }
                        })
                    } else {
                        // Give existing user a new code
                        renewCode(self.textField.text!, completion: { (success) -> Void in
                            if success {
                                // Go to pairing screen
                                self.performSegueWithIdentifier("pairingSegue", sender: self)
                            } else {
                                let alertController = UIAlertController(title: "Please try again", message: "There was a problem creating your account.", preferredStyle: .Alert)
                                let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
                                    // Focus textfield again
                                }
                                alertController.addAction(OKAction)
                                self.presentViewController(alertController, animated: true) {
                                }
                            }
                        })
                    }
                    
                case .Expired:
                    // Code has expired, show error
                    self.pairingIndicator.stopAnimating()
                    let alertController = UIAlertController(title: "Expired", message: "This code has expired! Create a new one and send it to your friend?", preferredStyle: .Alert)
                    let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
                        // Focus textfield again
                    }
                    alertController.addAction(OKAction)
                    self.presentViewController(alertController, animated: true) {
                    }
                    
                case .Used:
                    // Code has been used but not delete yet as creator hasn't opened app, show error
                    self.pairingIndicator.stopAnimating()
                    let alertController = UIAlertController(title: "Used", message: "This code has been used! Create a new one and send it to your friend?", preferredStyle: .Alert)
                    let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
                        // Focus textfield again
                    }
                    alertController.addAction(OKAction)
                    self.presentViewController(alertController, animated: true) {
                    }
                    
                case .Valid:
                    // Code is valid, create new recipient user
                    self.pairingIndicator.stopAnimating()
                    createUser(code!, completion: { (success) -> Void in
                        if success {
                            // Go to camera screen
                            self.performSegueWithIdentifier("cameraSegue", sender: self)
                        } else {
                            let alertController = UIAlertController(title: "Please try again", message: "Something went wrong.", preferredStyle: .Alert)
                            let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
                                // Focus textfield again
                            }
                            alertController.addAction(OKAction)
                            self.presentViewController(alertController, animated: true) {
                            }
                        }
                    })
                }
            } else {
                print("Did not succeed")
            }
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "pairingSegue" {
            if let destinationVC = segue.destinationViewController as? PairingViewController {
                destinationVC.enteredCode = textField.text!
            }
        } else if segue.identifier == "cameraSegue" {
            if let destinationVC = segue.destinationViewController as? CameraViewController {
                destinationVC.justPaired = true
            }
        }
    }
    
    func keyboardWillShow(notification: NSNotification!) {
        nextButton.alpha = 1
        
    }
    
    func keyboardWillHide(notification: NSNotification!) {
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}
