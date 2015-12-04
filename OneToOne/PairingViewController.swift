//
//  PairingViewController.swift
//  OneToOne
//
//  Created by Sam Wander on 11/18/15.
//  Copyright © 2015 FBD. All rights reserved.
//

import UIKit
import Parse
import AVFoundation
import AVKit
import MessageUI

class PairingViewController: UIViewController, MFMessageComposeViewControllerDelegate{
    
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var sendMessageButton: UIButton!
    @IBOutlet weak var cameraContainer: UIView!

    var enteredCode = ""
    
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
    
    // Starting elapsed time at 0 so on first loading we can show 10:00 remaining
    var elapsedTime: NSTimeInterval = 0
    
    // Pairing timer
    var pairingTimer = NSTimer()
    
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
        
        // get camera
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
    }
    
    override func viewDidAppear(animated: Bool) {
        // DISABLED FOR DEMO
        //NSNotificationCenter.defaultCenter().addObserver(self, selector: "respondToNotif:", name: "justPaired", object: nil)
        
        // Begin checking for paired
        startTimer()
        
        // When view appears, get interval since code created time from Parse
        getCodeCreatedTime { (interval, result) -> Void in
            if result {
                self.elapsedTime = interval
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
            endTimer()
            if let destinationVC = segue.destinationViewController as? CameraViewController {
                destinationVC.justPaired = true
            }
        }
    }
    
    @IBAction func didPressCancel(sender: AnyObject) {
        
        endTimer()
        
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
    
    func startTimer() {
        pairingTimer = NSTimer.scheduledTimerWithTimeInterval(15, target: self, selector: Selector("lookForNewPhotos"), userInfo: nil, repeats: true)
    }
    
    func endTimer() {
        pairingTimer.invalidate()
    }
    
    func lookForNewPhotos() {
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
    
    // IGNORING FOR DEMO
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



