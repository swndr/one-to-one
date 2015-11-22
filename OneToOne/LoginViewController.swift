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
    
    @IBAction func didPressNext(sender: AnyObject) {
        self.pairingIndicator.startAnimating()
        nextButton.selected = true

        let user = PFUser()
        
        user.username = textField.text
        user.password = textField.text
        
        user.signUpInBackgroundWithBlock { (status: Bool, error: NSError?) -> Void in
            if error == nil {
                self.performSegueWithIdentifier("pairingSegue", sender: self)
                self.pairingIndicator.stopAnimating()
                let alertController = UIAlertController(title: "Success", message: "account created", preferredStyle: .Alert)
                let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
                }
                alertController.addAction(OKAction)
                self.presentViewController(alertController, animated: true) {
                }
                
            } else {
                print("error: \(error)")
                self.pairingIndicator.stopAnimating()
                let alertController = UIAlertController(title: "Error", message: "error: \(error)", preferredStyle: .Alert)
                let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
                }
                alertController.addAction(OKAction)
                self.presentViewController(alertController, animated: true) {
                }

            }
            
        }
        /*
        
        
        /////////////
        // if field is correct
        if textField.text == "Seabiscuit" {
        delay(2){
        self.pairingIndicator.stopAnimating()
        self.performSegueWithIdentifier("pairingSegue", sender: self)
        UIView.animateWithDuration(0.3, delay: 0, options: [], animations: { () -> Void in
        self.PairingTextParentView.alpha = 0
        
        }, completion: { (Bool) -> Void in
        // Hide the keyboard
        self.view.endEditing(true)
        })
        }
        }
        
        // if field is empty
        if textField.text!.isEmpty {
        self.pairingIndicator.stopAnimating()
        let alertController = UIAlertController(title: "Try Again", message: "Please enter a word to start pairing.", preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
        }
        alertController.addAction(OKAction)
        self.presentViewController(alertController, animated: true) {
        }
        }
        
        // if field is incorrect
        else {
        delay(2){
        self.pairingIndicator.stopAnimating()
        let alertController = UIAlertController(title: "Try Again", message: "Please enter a word to start pairing.", preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
        }
        alertController.addAction(OKAction)
        self.presentViewController(alertController, animated: true) {
        }
        }
        }
        */
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func keyboardWillShow(notification: NSNotification!) {
        nextButton.alpha = 1
        
    }
    func keyboardWillHide(notification: NSNotification!) {
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
