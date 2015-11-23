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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var user = PFUser.currentUser()
        
        if user == nil {
            // Create anonymous user
            createAnonUser()
        } else {
            print("Found existing user")
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
        
        //let code = validateCode(textField.text!)
        
        var status = CodeStatus()
        var codeObject: PFObject?
        
        // Query code from text field
        let query = PFQuery(className:"AccountCode")
        query.whereKey("code", equalTo:(textField.text!))
        query.findObjectsInBackgroundWithBlock {
            (objects: [PFObject]?, error: NSError?) -> Void in
            
            if error == nil {
                // Found a code
                if objects!.count == 1 {
                    // Existing code entry
                    codeObject = objects!.first
                    if hasCodeExpired(codeObject!) {
                        status = .Expired
                        // Code has expired, show error
                        self.pairingIndicator.stopAnimating()
                        let alertController = UIAlertController(title: "Expired", message: "This code has expired! Create a new one and send it to your friend?", preferredStyle: .Alert)
                        let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
                            // Focus textfield again
                        }
                        alertController.addAction(OKAction)
                        self.presentViewController(alertController, animated: true) {
                        }
                    } else if hasCodeBeenUsed(codeObject!) {
                        status = .Used
                        // Code has been used but not delete yet as creator hasn't opened app, show error
                        self.pairingIndicator.stopAnimating()
                        let alertController = UIAlertController(title: "Used", message: "This code has been used! Create a new one and send it to your friend?", preferredStyle: .Alert)
                        let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
                            // Focus textfield again
                        }
                        alertController.addAction(OKAction)
                        self.presentViewController(alertController, animated: true) {
                        }
                    } else {
                        status = .Valid
                        // Code is valid, create new recipient user
                        self.pairingIndicator.stopAnimating()
                        createUser(codeObject!, completion: { (success) -> Void in
                            if success {
                                print("cool")
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
                    // New code entered
                    self.pairingIndicator.stopAnimating()
                    createUser(self.textField.text!, completion: { (success) -> Void in
                        if success {
                            print("cool")
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
            } else {
                // Log details of the failure
                print("Error: \(error!) \(error!.userInfo)")
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
