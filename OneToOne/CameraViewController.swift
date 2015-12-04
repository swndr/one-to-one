//
//  CameraViewController.swift
//  OneToOne
//
//  Created by Sam Wander on 11/18/15.
//  Copyright © 2015 FBD. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import Parse

class CameraViewController: UIViewController, UIImagePickerControllerDelegate {
    
    @IBOutlet weak var cameraContainer: UIView!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var discardButton: UIButton!
    @IBOutlet weak var flipButton: UIButton!
    @IBOutlet weak var nuxBanner: UIView!
    
    var justPaired = false
    var recipientUsername = ""
    
    // Capture session
    let captureSession = AVCaptureSession()
    // Two camera inputs
    var frontCameraInput = AVCaptureDeviceInput()
    var backCameraInput = AVCaptureDeviceInput()
    // Image output
    let stillImageOutput = AVCaptureStillImageOutput()
    // Store current device "position"
    var currentPosition: Position!
    // To toggle back / front
    enum Position {
        case Back, Front
        init() {
            self = .Back
        }
    }
    // View for displaying the preview image
    var cameraPreview:UIView!
    // Init our CapturedPhoto type
    var capturedPhoto = CapturedPhoto()
    
    // Overlay after image captured
    var overlay = UIView()
    
    // Array to store received images
    var receivedImages: [ReceivedImage] = []
    
    // Storing thumbnail positions
    var lastThumbX:CGFloat!
    var lastThumbY:CGFloat!
    
    // Current user
    let user = PFUser.currentUser()
    
    // Tap gesture for taking photos
    var tapCamera: UITapGestureRecognizer = UITapGestureRecognizer()
    // Pan gesture for sending / discarding photo
    var panPhoto: UIPanGestureRecognizer = UIPanGestureRecognizer()
    // Tap gesture for opening received images
    var tapPhoto: UITapGestureRecognizer = UITapGestureRecognizer()
    // Pan gesture for thumbnail received photos
    var panReceivedThumbnails: UIPanGestureRecognizer = UIPanGestureRecognizer()
    // Pan gesture for saving / discarding received photos
    var panReceivedPhoto: UIPanGestureRecognizer = UIPanGestureRecognizer()
    
    // Timer
    var timer = NSTimer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("Opened camera")
        
        //let user = PFUser.currentUser()
        recipientUsername = user!["recipient"] as! String
        
        // Nux Banner
        if justPaired {
            print("Show NUX banner")
            nuxBanner.alpha = 1
        } else {
            nuxBanner.alpha = 0
        }
        
        // Initially set to use back camera
        currentPosition = Position()
        
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
        
        sendButton.alpha = 0
        cancelButton.alpha = 0
        saveButton.alpha = 0
        discardButton.alpha = 0
    }
    
    override func viewDidAppear(animated: Bool) {
        // Fetch new photos
        if receivedImages.count == 0 {
            lastThumbX = 0
            lastThumbY = 0
        }
        
        // Add notif observer
        //NSNotificationCenter.defaultCenter().addObserver(self, selector: "respondToNotif:", name: "newPhoto", object: nil)

        getNewPhotos { (ready) -> Void in
            if ready {
                self.receivedImages.sortInPlace({ $0.created.timeIntervalSince1970 > $1.created.timeIntervalSince1970 })
                self.displayReceivedPhotos()
            }
        }
        
        startTimer()
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
            tapCamera = UITapGestureRecognizer(target: self, action: "didTakePhoto:")
            cameraPreview.addGestureRecognizer(tapCamera)
            cameraContainer.addSubview(cameraPreview)
        }
    }
    
    // Called when preview view is tapped to take picture
    func didTakePhoto(sender: UITapGestureRecognizer) {
        
        endTimer()
        
        if let videoConnection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo) {
            stillImageOutput.captureStillImageAsynchronouslyFromConnection(videoConnection) {
                (imageDataSampleBuffer, error) -> Void in
                
                self.cameraPreview.userInteractionEnabled = false
                
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                
                // TODO: MAKE OVERLAY NICE
                self.overlay.frame = CGRectMake(0.0, 0.0, self.view.bounds.size.width, self.view.bounds.size.height)
                self.overlay.backgroundColor = UIColor.blackColor()
                self.overlay.alpha = 0
                self.cameraPreview.addSubview(self.overlay)
                
                // Calculate sizes
                let screenSize = UIScreen.mainScreen().bounds.size
                let cameraAspectRatio: CGFloat = 4.0 / 3.0
                let imageWidth = screenSize.width
                let imageHeight = floor(screenSize.width * cameraAspectRatio)
                let yPos = floor((screenSize.height - imageHeight)/2)
                
                self.capturedPhoto.userInteractionEnabled = true
                self.capturedPhoto.storeData(imageData) // Store the data
                self.capturedPhoto.addImage(imageData) // Add the actual image via data
                self.capturedPhoto.frame = CGRectMake(0.0, yPos, imageWidth, imageHeight)
                self.capturedPhoto.transform = CGAffineTransformMakeScale(1.1, 1.1)
                self.cameraContainer.addSubview(self.capturedPhoto)
                
                for image in self.receivedImages {
                    UIView.animateWithDuration(0.4, delay: 0.0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
                        image.transform = CGAffineTransformMakeScale(0.001,0.001)
                        }, completion: { (done) -> Void in
                    })
                }
                
                UIView.animateWithDuration(0.2, delay: 0.0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
                    
                    // NUX Banner
                    if self.justPaired {
                        self.justPaired = false
                        self.nuxBanner.alpha = 0
                    }
                    
                    // Hide Flip
                    self.flipButton.alpha = 0
                    
                    // Show buttons and overlay
                    self.sendButton.alpha = 1
                    self.cancelButton.alpha = 1
                    self.overlay.alpha = 0.8
                    self.capturedPhoto.transform = CGAffineTransformMakeScale(1, 1)
                    
                    }, completion: { (bool) -> Void in
                        // Add pan gesture
                        self.panPhoto = UIPanGestureRecognizer(target: self, action: "didPanPhoto:")
                        self.capturedPhoto.addGestureRecognizer(self.panPhoto)
                })
            }
        }
    }
    
    func switchCamera(currentPosition: Position, frontCamera:AVCaptureDeviceInput,backCamera:AVCaptureDeviceInput) -> Position {
        
        // Depending on current camera position, swap to the other one
        switch currentPosition {
        case .Back:
            captureSession.beginConfiguration()
            captureSession.removeInput(backCamera)
            if captureSession.canAddInput(frontCamera) {
                captureSession.addInput(frontCamera)
            }
            captureSession.commitConfiguration()
            return .Front
        case .Front:
            captureSession.beginConfiguration()
            captureSession.removeInput(frontCamera)
            if captureSession.canAddInput(backCamera) {
                captureSession.addInput(backCamera)
            }
            captureSession.commitConfiguration()
            return .Back
        }
    }
    
    func didPanPhoto(sender:UIPanGestureRecognizer) {
        // Decide if saving or discarding
        let location = sender.locationInView(view)
        let velocity = sender.velocityInView(view)
        let translation = sender.translationInView(view)
        
        if sender.state == UIGestureRecognizerState.Began {
            
            capturedPhoto.storeOriginalY(capturedPhoto.frame.origin.y)
            
        } else if sender.state == UIGestureRecognizerState.Changed {
            
            capturedPhoto.frame.origin.y = capturedPhoto.originalY + translation.y
            
            if capturedPhoto.center.y < UIScreen.mainScreen().bounds.height/2 {
                let scale = convertValue(capturedPhoto.center.y, r1Min: 0, r1Max: UIScreen.mainScreen().bounds.height/2, r2Min: 2.0, r2Max: 1.0)
                self.sendButton.transform = CGAffineTransformMakeScale(scale, scale)
            } else {
                let scale = convertValue(capturedPhoto.center.y, r1Min: UIScreen.mainScreen().bounds.height/2, r1Max: UIScreen.mainScreen().bounds.height, r2Min: 1.0, r2Max: 2.0)
                self.cancelButton.transform = CGAffineTransformMakeScale(scale, scale)
            }
            
        } else if sender.state == UIGestureRecognizerState.Ended {
            
            let options: UIViewAnimationOptions = .CurveEaseInOut
            
            // Bounce to center
            if capturedPhoto.center.y > UIScreen.mainScreen().bounds.height/4 && capturedPhoto.center.y < (UIScreen.mainScreen().bounds.height/4)*3 {
                UIView.animateWithDuration(0.2, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 2, options: options, animations: { () -> Void in
                    
                    self.capturedPhoto.center.y = UIScreen.mainScreen().bounds.height/2
                    self.sendButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
                    self.cancelButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
                    
                        }, completion: { finished in

                    })
            // Send
            } else if capturedPhoto.center.y <= UIScreen.mainScreen().bounds.height/4 {
            print("send")
                UIView.animateWithDuration(0.2, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 2, options: options, animations: { () -> Void in
                    
                    self.capturedPhoto.frame.size.height = UIScreen.mainScreen().bounds.origin.y - 50.0
                    self.sendButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
                    self.cancelButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
                    
                    }, completion: { finished in
                        self.sendPhoto(self.capturedPhoto)
                })
            // Cancel
            } else {
            print("cancel")
                UIView.animateWithDuration(0.2, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 2, options: options, animations: { () -> Void in
                    
                    self.capturedPhoto.frame.origin.y = UIScreen.mainScreen().bounds.height + 50.0
                    self.sendButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
                    self.cancelButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
                    
                    }, completion: { finished in
                        self.discardPhoto(self.capturedPhoto)
                })
            }
        }
    }
    
    func discardPhoto(photoToDiscard:CapturedPhoto) {
        // TODO: MAKE THIS NICE
        photoToDiscard.removeFromSuperview()
        UIView.animateWithDuration(0.2, delay: 0.0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
            self.sendButton.alpha = 0
            self.cancelButton.alpha = 0
            self.overlay.alpha = 0
            self.flipButton.alpha = 1
            }, completion: { (done) -> Void in
                self.startTimer()
        })
        cameraPreview.userInteractionEnabled = true
        
        for image in self.receivedImages {
            UIView.animateWithDuration(0.4, delay: 0.0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
                image.transform = CGAffineTransformMakeScale(0.2,0.2)
                }, completion: { (done) -> Void in
            })
        }
    }
    
    func sendPhoto(photoToSend:CapturedPhoto) {
        
        self.sendButton.setTitle("Sending...", forState: .Normal)
        self.sendButton.userInteractionEnabled = false
        
        // TODO: MAKE THIS NICE
        capturedPhoto.sendImage(capturedPhoto.imageData, recipientUsername: recipientUsername) { (sent) -> Void in
            print("Sending...") // ADD LOADING SPINNER
            if sent {
                print("Sent")
                self.capturedPhoto.removeFromSuperview()
                UIView.animateWithDuration(0.2, delay: 0.0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
                    self.sendButton.alpha = 0
                    self.cancelButton.alpha = 0
                    self.overlay.alpha = 0
                    self.flipButton.alpha = 1
                    }, completion: { (done) -> Void in
                        self.startTimer()
                })
                self.cameraPreview.userInteractionEnabled = true
                self.sendButton.setTitle("Send", forState: .Normal)
                self.sendButton.userInteractionEnabled = true
                
                // Save to camera roll
                UIImageWriteToSavedPhotosAlbum(UIImage(data: self.capturedPhoto.imageData)!, nil, nil, nil)
                
                for image in self.receivedImages {
                    UIView.animateWithDuration(0.4, delay: 0.0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
                        image.transform = CGAffineTransformMakeScale(0.2,0.2)
                        }, completion: { (done) -> Void in
                    })
                }
            }
        }
    }
    
    @IBAction func didSendPhoto(sender: UIButton) {
        let options: UIViewAnimationOptions = .CurveEaseInOut
        UIView.animateWithDuration(0.2, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 2, options: options, animations: { () -> Void in
            
            self.capturedPhoto.frame.size.height = UIScreen.mainScreen().bounds.origin.y - 50.0
            self.sendButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
            self.cancelButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
            
            }, completion: { finished in
                delay(0.5, closure: { () -> () in
                    self.sendPhoto(self.capturedPhoto)
                })
        })
    }
    
    @IBAction func didDiscardPhoto(sender: UIButton) {
        let options: UIViewAnimationOptions = .CurveEaseInOut
        UIView.animateWithDuration(0.2, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 2, options: options, animations: { () -> Void in
            
            self.capturedPhoto.frame.origin.y = UIScreen.mainScreen().bounds.height + 50.0
            self.sendButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
            self.cancelButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
            
            }, completion: { finished in
                delay(0.5, closure: { () -> () in
                    self.discardPhoto(self.capturedPhoto)
                })
        })
    }
    
    
    @IBAction func didFlipCamera(sender:UIButton) {
        // Toggle camera position and set currentPosition to new position
        currentPosition = switchCamera(currentPosition, frontCamera: frontCameraInput, backCamera: backCameraInput)
    }
    
    ///// RECEIVING PHOTOS /////
    
    func startTimer() {
        timer = NSTimer.scheduledTimerWithTimeInterval(15, target: self, selector: Selector("lookForNewPhotos"), userInfo: nil, repeats: true)
    }
    
    func endTimer() {
        timer.invalidate()
    }
    
    func lookForNewPhotos() {
        getNewPhotos { (ready) -> Void in
            if ready {
                self.receivedImages.sortInPlace({ $0.created.timeIntervalSince1970 > $1.created.timeIntervalSince1970 })
                self.displayReceivedPhotos()
            }
        }
    }
    
    // IGNORING THIS FOR DEMO
    func respondToNotif(userInfo:NSNotification) {
    
        print("Responding to notif")
        getNewPhotos { (ready) -> Void in
            if ready {
                self.receivedImages.sortInPlace({ $0.created.timeIntervalSince1970 > $1.created.timeIntervalSince1970 })
                self.displayReceivedPhotos()
            }
        }
    }
    
    func getNewPhotos(completion: (Bool -> Void)) {
        
        var newImages: [PFObject] = []
        
        func getObjects(completion: (Bool -> Void)) {
            let query = PFQuery(className:"Photo")
            query.whereKey("recipient", equalTo:user!["username"])
            query.whereKey("viewed", equalTo:NSNumber(bool: false)) // not viewed yet
            query.findObjectsInBackgroundWithBlock {
                (objects: [PFObject]?, error: NSError?) -> Void in
                
                if error == nil {
                    // The find succeeded
                    if let objects = objects! as? [PFObject] {
                        for object in objects {
                            // Check not already in array of downloaded images
                            if !self.receivedImages.contains({$0.objectID == object.objectId!}) {
                                newImages.append(object) // add to array
                                print(newImages)
                            }
                            if object == objects.last {
                                completion(true)
                                print(newImages)
                            }
                        }
                    }
                } else {
                    // Log details of the failure
                    print("Error: \(error!) \(error!.userInfo)")
                }
            }
        }
        
        // Get new images then add to receivedImages array
        getObjects { (done) -> Void in
            if done {
                let existingImages = self.receivedImages.count
                print("Successfully retrieved \(newImages.count) photos.")
                // Total to track download completion
                //var totalPercentDone:Int32 = 100 * Int32(newImages.count)
                for object in newImages {
                    let imageFile = object["imageFile"]
                    if imageFile != nil {
                        imageFile!.getDataInBackgroundWithBlock({ (data, error) -> Void in
                            if error == nil {
                                // Calculate size for display
                                let screenSize = UIScreen.mainScreen().bounds.size
                                let cameraAspectRatio: CGFloat = 4.0 / 3.0
                                let imageWidth = screenSize.width
                                let imageHeight = floor(screenSize.width * cameraAspectRatio)
                                
                                // Set received image and id
                                let receivedImage = ReceivedImage(frame:CGRect(x:0,y:0,width:imageWidth,height:imageHeight))
                                receivedImage.setImageForView(data!)
                                receivedImage.storeObjectID(object.objectId!)
                                receivedImage.storeCreatedDate(object.createdAt!)
                                print("ID: \(receivedImage.objectID)")
                                
                                receivedImage.userInteractionEnabled = true
                                
                                // Add to array so can display later
                                self.receivedImages.append(receivedImage)
                            }
                        }, progressBlock: { (percentDone: Int32) -> Void in
                            
                            print("Progress: \(percentDone)")
                            if object == newImages.last && percentDone == 100 {
                                
                                func checkCompletion() {
                                    if (self.receivedImages.count - existingImages) == newImages.count {
                                        completion(true)
                                    } else {
                                        delay(0.2, closure: { () -> () in
                                            print("Still waiting...")
                                            checkCompletion()
                                        })
                                    }
                                }
                                checkCompletion()
                            }
                        })
                    }
                }
            }
        }
    }
    
    func displayReceivedPhotos() {
        
        print("Displaying received photos")
        print(receivedImages.count)
        
        for image in receivedImages {
            if !image.displayed {
                // Clip and shrink images, display in view
                if lastThumbX == 0 {
                    image.center = CGPointMake(UIScreen.mainScreen().bounds.origin.x + 60, UIScreen.mainScreen().bounds.height - 50)
                    lastThumbX = image.center.x
                    lastThumbY = image.center.y
                } else {
                    image.center = CGPointMake(lastThumbX + randRange(-20, upper: 20), lastThumbY + randRange(-20, upper: 20))
                    lastThumbX = image.center.x
                    lastThumbY = image.center.y
                }
                image.frame.size.height = ((image.frame.height/4.0) * 3.0)
                image.layer.cornerRadius = image.frame.width/2
                image.layer.borderWidth = 5.0
                image.layer.borderColor = UIColor.whiteColor().CGColor
                image.contentMode = .ScaleAspectFill
                image.clipsToBounds = true
            
                image.transform = CGAffineTransformMakeScale(0.001,0.001)
                image.setDisplayed()
                self.view.addSubview(image)
                image.sendSubviewToBack(self.view)
                
                UIView.animateWithDuration(0.4, delay: 0.0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
                    
                   image.transform = CGAffineTransformMakeScale(0.2,0.2)
                    
                    }, completion: { (done) -> Void in
                })
            } else {
                self.view.bringSubviewToFront(image)
            }
            
            // Add gesture recognizer to top image
            if image == receivedImages.last {
                if image.gestureRecognizers?.count == nil {
                    panReceivedThumbnails = UIPanGestureRecognizer(target: self, action: "didPanReceivedThumbnail:")
                    image.addGestureRecognizer(panReceivedThumbnails)
                    tapPhoto = UITapGestureRecognizer(target: self, action: "didTapTopImage:")
                    image.addGestureRecognizer(tapPhoto)
                }
                // MAY NEED TO WORK ON DISTINGUISHING GESTURES / PRIORITY
            }
        }
    }
    
    func didTapTopImage(sender:UITapGestureRecognizer) {
        
        endTimer()
        
        cameraPreview.userInteractionEnabled = false
        sender.view?.removeGestureRecognizer(panReceivedThumbnails)
        sender.view?.removeGestureRecognizer(tapPhoto)
        
        UIView.animateWithDuration(0.2, delay: 0.0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
            
            if self.overlay.superview == nil {
                // TODO: MAKE OVERLAY NICE
                self.overlay.frame = CGRectMake(0.0, 0.0, self.view.bounds.size.width, self.view.bounds.size.height)
                self.overlay.backgroundColor = UIColor.blackColor()
                self.overlay.alpha = 0
                self.cameraPreview.addSubview(self.overlay)
            }
            self.overlay.alpha = 0.8
            self.saveButton.alpha = 1
            self.discardButton.alpha = 1
            self.flipButton.alpha = 0
            
            self.panReceivedPhoto = UIPanGestureRecognizer(target: self, action: "didPanReceivedPhoto:")
            
            // Loop through images, make them full size and not masked
            for image in self.receivedImages {
                if image.displayed {
                    image.layer.cornerRadius = 0
                    image.layer.borderWidth = 0.0
                    image.frame.size.height = ((image.frame.height/3.0) * 4.0)
                    image.center.x = UIScreen.mainScreen().bounds.width/2
                    image.center.y = UIScreen.mainScreen().bounds.height/2
                    image.transform = CGAffineTransformMakeScale(1,1)
                    
                    if image == self.receivedImages.last {
                        image.addGestureRecognizer(self.panReceivedPhoto)
                    }
                }
            }

            }) { (finished) -> Void in
                self.view.bringSubviewToFront(self.saveButton)
                self.view.bringSubviewToFront(self.discardButton)
                
        }
    }
    
    func didPanReceivedThumbnail(sender:UIPanGestureRecognizer) {
        let translation = sender.translationInView(view)
        
        if sender.state == UIGestureRecognizerState.Began {
            for image in receivedImages {
                image.storeOriginalCenter(image.center)
            }
            self.lastThumbX = 0

        } else if sender.state == UIGestureRecognizerState.Changed {
            
            // add animation
            for (index,image) in receivedImages.enumerate() {
                // Subtract from count so the front one leads and back ones follow
                let delay: Double = (Double)(receivedImages.count - index) * 0.1
                UIView.animateWithDuration(delay, animations: { () -> Void in
                    image.center = CGPoint(x: image.originalCenter.x + translation.x, y: image.originalCenter.y + translation.y)
                })
            }

        } else if sender.state == UIGestureRecognizerState.Ended {
            
            for image in receivedImages {
                UIView.animateWithDuration(0.5, animations: { () -> Void in
                    if image.center.x < UIScreen.mainScreen().bounds.width/2 && image.center.y < UIScreen.mainScreen().bounds.height/2 {
                        if self.lastThumbX == 0 {
                            image.center = CGPointMake(UIScreen.mainScreen().bounds.origin.x + 100, UIScreen.mainScreen().bounds.origin.y + 100)
                            self.lastThumbX = image.center.x
                            self.lastThumbY = image.center.y
                        } else {
                            image.center = CGPointMake(self.lastThumbX + randRange(-20, upper: 20), self.lastThumbY + randRange(-20, upper: 20))
                            self.lastThumbX = image.center.x
                            self.lastThumbY = image.center.y
                        }
                    } else if image.center.x > UIScreen.mainScreen().bounds.width/2 && image.center.y < UIScreen.mainScreen().bounds.height/2 {
                        if self.lastThumbX == 0 {
                            image.center = CGPointMake(UIScreen.mainScreen().bounds.width - 100, UIScreen.mainScreen().bounds.origin.y + 100)
                            self.lastThumbX = image.center.x
                            self.lastThumbY = image.center.y
                        } else {
                            image.center = CGPointMake(self.lastThumbX + randRange(-20, upper: 20), self.lastThumbY + randRange(-20, upper: 20))
                            self.lastThumbX = image.center.x
                            self.lastThumbY = image.center.y
                        }
                    } else if image.center.x > UIScreen.mainScreen().bounds.width/2 && image.center.y > UIScreen.mainScreen().bounds.height/2 {
                        if self.lastThumbX == 0 {
                            image.center = CGPointMake(UIScreen.mainScreen().bounds.width - 100, UIScreen.mainScreen().bounds.height - 100)
                            self.lastThumbX = image.center.x
                            self.lastThumbY = image.center.y
                        } else {
                            image.center = CGPointMake(self.lastThumbX + randRange(-20, upper: 20), self.lastThumbY + randRange(-20, upper: 20))
                            self.lastThumbX = image.center.x
                            self.lastThumbY = image.center.y
                        }
                    } else {
                        if self.lastThumbX == 0 {
                            image.center = CGPointMake(UIScreen.mainScreen().bounds.origin.x + 100, UIScreen.mainScreen().bounds.height - 100)
                            self.lastThumbX = image.center.x
                            self.lastThumbY = image.center.y
                        } else {
                            image.center = CGPointMake(self.lastThumbX + randRange(-20, upper: 20), self.lastThumbY + randRange(-20, upper: 20))
                            self.lastThumbX = image.center.x
                            self.lastThumbY = image.center.y
                        }
                    }
                })
            }
        }
    }
    
    func didPanReceivedPhoto(sender:UIPanGestureRecognizer) {
        // Decide whether to save or discard
        let translation = sender.translationInView(view)
        
        let image = sender.view as! ReceivedImage
        
        if sender.state == UIGestureRecognizerState.Began {
            
            image.storeOriginalY(image.frame.origin.y)
            
        } else if sender.state == UIGestureRecognizerState.Changed {
            
            image.frame.origin.y = image.originalY + translation.y
            
            if image.center.y < UIScreen.mainScreen().bounds.height/2 {
                let scale = convertValue(image.center.y, r1Min: 0, r1Max: UIScreen.mainScreen().bounds.height/2, r2Min: 2.0, r2Max: 1.0)
                self.saveButton.transform = CGAffineTransformMakeScale(scale, scale)
            } else {
                let scale = convertValue(image.center.y, r1Min: UIScreen.mainScreen().bounds.height/2, r1Max: UIScreen.mainScreen().bounds.height, r2Min: 1.0, r2Max: 2.0)
                self.discardButton.transform = CGAffineTransformMakeScale(scale, scale)
            }
            
        } else if sender.state == UIGestureRecognizerState.Ended {
            
            let options: UIViewAnimationOptions = .CurveEaseInOut
            
            // Bounce to center
            if image.center.y > UIScreen.mainScreen().bounds.height/4 && image.center.y < (UIScreen.mainScreen().bounds.height/4)*3 {
                UIView.animateWithDuration(0.2, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 2, options: options, animations: { () -> Void in
                    
                    image.center.y = UIScreen.mainScreen().bounds.height/2
                    self.saveButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
                    self.discardButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
                    
                    }, completion: { finished in
                        
                })
                // Send
            } else if image.center.y <= UIScreen.mainScreen().bounds.height/4 {
                print("save")
                UIView.animateWithDuration(0.2, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 2, options: options, animations: { () -> Void in
                    
                    image.frame.size.height = UIScreen.mainScreen().bounds.origin.y - 50.0
                    self.sendButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
                    self.cancelButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
                    
                    }, completion: { finished in
                       self.saveReceivedPhoto(image)
                })
                // Cancel
            } else {
                print("cancel")
                UIView.animateWithDuration(0.2, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 2, options: options, animations: { () -> Void in
                    
                    image.frame.origin.y = UIScreen.mainScreen().bounds.height + 50.0
                    self.sendButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
                    self.cancelButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
                    
                    }, completion: { finished in
                        self.discardReceivedPhoto(image)
                })
            }
        }
    }
    
    func saveReceivedPhoto(image: ReceivedImage) {
        
        receivedImages.removeLast()
        if receivedImages.last != nil {
            receivedImages.last!.addGestureRecognizer(panReceivedPhoto)
        } else {
            UIView.animateWithDuration(0.2, delay: 0.0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
                self.overlay.alpha = 0
                self.saveButton.alpha = 0
                self.discardButton.alpha = 0
                self.flipButton.alpha = 1
                }, completion: { (done) -> Void in
                    self.startTimer()
                    self.cameraPreview.userInteractionEnabled = true
            })
        }
        
        // Save to camera roll
        UIImageWriteToSavedPhotosAlbum(UIImage(data: image.imageData)!, nil, nil, nil)
        // Delete from Parse
        image.deleteSeenPhoto(image.objectID)
        image.removeFromSuperview()
    }
    
    func discardReceivedPhoto(image: ReceivedImage) {
        
        receivedImages.removeLast()
        if receivedImages.last != nil {
            receivedImages.last!.addGestureRecognizer(panReceivedPhoto)
        } else {
            UIView.animateWithDuration(0.2, delay: 0.0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
                self.overlay.alpha = 0
                self.saveButton.alpha = 0
                self.discardButton.alpha = 0
                self.flipButton.alpha = 1
                }, completion: { (done) -> Void in
                    self.startTimer()
                    self.cameraPreview.userInteractionEnabled = true
            })
        }
        // Delete from Parse
        image.deleteSeenPhoto(image.objectID)
        image.removeFromSuperview()
        
    }
    
    @IBAction func didSavePhoto(sender: AnyObject) {
        let options: UIViewAnimationOptions = .CurveEaseInOut
        UIView.animateWithDuration(0.2, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 2, options: options, animations: { () -> Void in
            
            self.receivedImages.last!.frame.size.height = UIScreen.mainScreen().bounds.origin.y - 50.0
            self.saveButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
            self.discardButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
            
            }, completion: { finished in
                delay(0.5, closure: { () -> () in
                    self.saveReceivedPhoto(self.receivedImages.last!)
                })
        })
    }
    
    @IBAction func didDiscardReceivedPhoto(sender: AnyObject) {
        let options: UIViewAnimationOptions = .CurveEaseInOut
        UIView.animateWithDuration(0.2, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 2, options: options, animations: { () -> Void in
            
            self.receivedImages.last!.frame.origin.y = UIScreen.mainScreen().bounds.height + 50.0
            self.saveButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
            self.discardButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
            
            }, completion: { finished in
                delay(0.5, closure: { () -> () in
                    self.discardReceivedPhoto(self.receivedImages.last!)
                })
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}
