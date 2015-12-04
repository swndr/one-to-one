//
//  PairingViewController.swift
//  one-to-one
//
//  Created by Matt Chan on 11/16/15.
//  Copyright © 2015 matt. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import Parse

class LoginViewController: UIViewController {
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var pairingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var PairingTextParentView: UIView!
    @IBOutlet weak var cameraContainer: UIView!

    
    var returningFromPairing = false
    
    // Capture session
    let captureSession = AVCaptureSession()
    // Two camera inputs
    var frontCameraInput = AVCaptureDeviceInput()
    var backCameraInput = AVCaptureDeviceInput()
    // Image output
    let stillImageOutput = AVCaptureStillImageOutput()
    // View for displaying the preview image
    var cameraPreview:UIView!
    // Overlay after image captured
    var overlay = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let authorizationStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        switch authorizationStatus {
        case .NotDetermined:
            // Request authorization
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo,
                completionHandler: { (granted:Bool) -> Void in
                    if granted {
                        // Continue
                        self.loadCamera()
                    }
                    else {
                        // user denied: show an error?
                    }
            })
        case .Authorized:
            // Continue
            loadCamera()
        case .Denied, .Restricted:
            print("Can't open camera")
            // Denied!
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
    }
    
    func loadCamera() {
        
        // Get available devices (e.g back and front camera)
        let availableCameraDevices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for device in availableCameraDevices as! [AVCaptureDevice] {
            if device.position == .Back {
                let backCameraDevice = device
                do {
                    let possibleBackCamera = try AVCaptureDeviceInput(device: backCameraDevice)
                    backCameraInput = possibleBackCamera
                    try captureSession.addInput(backCameraInput)
                    do {
                        try backCameraDevice.lockForConfiguration()
                        backCameraDevice.focusMode = .ContinuousAutoFocus
                        backCameraDevice.unlockForConfiguration()
                    } catch _ {
                        // Couldn't set focus
                    }
                } catch _ {
                    // Couldn't set back camera input
                }
            }
            else if device.position == .Front {
                let frontCameraDevice = device
                do {
                    let possibleFrontCamera = try AVCaptureDeviceInput(device: frontCameraDevice)
                    frontCameraInput = possibleFrontCamera
                } catch _ {
                    // Couldn't set front camera input
                }
            }
        }
        
        
        // Begin capture session
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        captureSession.startRunning()
        // Set output
        stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecJPEG,AVVideoQualityKey: 0.9]
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
        }
        
        // Create the preview layer to display camera input
        if let preview = AVCaptureVideoPreviewLayer(session: captureSession) {
            let previewLayer = preview
            previewLayer.bounds = CGRectMake(0.0, 0.0, view.bounds.size.width, view.bounds.size.height)
            previewLayer.position = CGPointMake(view.bounds.midX, view.bounds.midY)
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            cameraPreview = UIView(frame: CGRectMake(0.0, 0.0, view.bounds.size.width, view.bounds.size.height))
            cameraPreview.layer.addSublayer(previewLayer)
            cameraContainer.addSubview(cameraPreview)
            
            // overlay
            self.overlay.frame = CGRectMake(0.0, 0.0, self.view.bounds.size.width, self.view.bounds.size.height)
            self.overlay.backgroundColor = UIColor.blackColor()
            self.overlay.alpha = 0.8
            self.cameraPreview.addSubview(self.overlay)
        }
        
    }
    
    @IBAction func didPressNextKey(sender: AnyObject) {
        attemptLogin()
    }
    @IBAction func didPressNext(sender: AnyObject) {
        attemptLogin()
    }
        
    func attemptLogin() {
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
