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
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        nextButton.alpha = 0
        
        /*
        var timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("update"), userInfo: nil, repeats: true)
        */
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:",
            name: UIKeyboardWillShowNotification, object: nil)
        
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:",
            name: UIKeyboardWillHideNotification, object: nil)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /*
    func updateTime() {
    
    var currentTime = NSDate.timeIntervalSinceReferenceDate()
    
    //Find the difference between current time and start time.
    var elapsedTime: NSTimeInterval = currentTime - startTime
    
    //calculate the minutes in elapsed time.
    let minutes = UInt8(elapsedTime / 60.0)
    elapsedTime -= (NSTimeInterval(minutes) * 60)
    
    //calculate the seconds in elapsed time.
    let seconds = UInt8(elapsedTime)
    elapsedTime -= NSTimeInterval(seconds)
    
    //add the leading zero for minutes, seconds and millseconds and store them as string constants
    let strMinutes = String(format: "%02d", minutes)
    let strSeconds = String(format: "%02d", seconds)
    
    //concatenate minuets, seconds as assign it to the UILabel
    
    countdownLabel.text = "\(strMinutes):\(strSeconds)"
    
    }
    
    @IBAction func countdownOn(sender: AnyObject) {
    let aSelector : Selector = "updateTime"
    timer = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: aSelector, userInfo: nil, repeats: true)
    startTime = NSDate.timeIntervalSinceReferenceDate()
    }
    
    */
    
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
