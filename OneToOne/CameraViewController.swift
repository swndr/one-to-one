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
    // Overlay after image captured *placeholder*
    var overlay = UIView()
    
    // TEMP VIEW TO HOLD PHOTO ** need to figure out scope stuff **
    var photoHolder:CapturedPhoto!
    
    // Array to store received images
    var receivedImages: [ReceivedImage] = []
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("Opened camera")
        
        //let user = PFUser.currentUser()
        recipientUsername = user!["recipient"] as! String
        
        if justPaired {
            print("Show NUX banner")
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
    }
    
    override func viewDidAppear(animated: Bool) {
        // Fetch new photos
        // TODO: FIND WAY TO AUTOMATE / INITIATE REFRESHING
        
        // Add notif observer (may need to remove too?)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "respondToNotif:", name: "newPhoto", object: nil)

        getNewPhotos { (ready) -> Void in
            if ready {
                self.receivedImages.sortInPlace({ $0.created.timeIntervalSince1970 > $1.created.timeIntervalSince1970 })
                self.displayReceivedPhotos()
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
            tapCamera = UITapGestureRecognizer(target: self, action: "didTakePhoto:")
            cameraPreview.addGestureRecognizer(tapCamera)
            cameraContainer.addSubview(cameraPreview)
        }
    }
    
    // Called when preview view is tapped to take picture
    func didTakePhoto(sender: UITapGestureRecognizer) {
        if let videoConnection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo) {
            stillImageOutput.captureStillImageAsynchronouslyFromConnection(videoConnection) {
                (imageDataSampleBuffer, error) -> Void in
                
                self.cameraPreview.removeGestureRecognizer(self.tapCamera)
                
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
                
                // Init our CapturedPhoto type
                let capturedPhoto = CapturedPhoto()
                
                capturedPhoto.userInteractionEnabled = true
                capturedPhoto.storeData(imageData) // Store the data
                capturedPhoto.addImage(imageData) // Add the actual image via data
                capturedPhoto.frame = CGRectMake(0.0, yPos, imageWidth, imageHeight)
                capturedPhoto.transform = CGAffineTransformMakeScale(1.1, 1.1)
                self.view.addSubview(capturedPhoto)
                
                UIView.animateWithDuration(0.2, delay: 0.0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
                    
                    // Show buttons and overlay
                    self.sendButton.alpha = 1
                    self.cancelButton.alpha = 1
                    self.overlay.alpha = 0.8
                    capturedPhoto.transform = CGAffineTransformMakeScale(1, 1)
                    
                    }, completion: { (bool) -> Void in
                        
                        // Sending to global scope so buttons can reach this...
                        self.photoHolder = capturedPhoto
                        
                        // Add pan gesture
                        self.panPhoto = UIPanGestureRecognizer(target: self, action: "didPanPhoto:")
                        self.photoHolder.addGestureRecognizer(self.panPhoto)
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
        
    }
    
    func discardPhoto(photoToDiscard:CapturedPhoto) {
        // TODO: MAKE THIS NICE
        photoToDiscard.removeFromSuperview()
        self.sendButton.alpha = 0
        self.cancelButton.alpha = 0
        self.overlay.alpha = 0
        cameraPreview.addGestureRecognizer(tapCamera)
    }
    
    @IBAction func didSendPhoto(sender: UIButton) {
        // Save to camera roll
        UIImageWriteToSavedPhotosAlbum(UIImage(data: photoHolder.imageData)!, nil, nil, nil)
        
        // TODO: MAKE THIS NICE
        photoHolder.sendImage(photoHolder.imageData, recipientUsername: recipientUsername)
        photoHolder.removeFromSuperview()
        self.sendButton.alpha = 0
        self.cancelButton.alpha = 0
        self.overlay.alpha = 0
        cameraPreview.addGestureRecognizer(tapCamera)
    }
    
    @IBAction func didDiscardPhoto(sender: UIButton) {
        discardPhoto(photoHolder)
    }
    
    
    @IBAction func didFlipCamera(sender:UIButton) {
        // Toggle camera position and set currentPosition to new position
        currentPosition = switchCamera(currentPosition, frontCamera: frontCameraInput, backCamera: backCameraInput)
    }
    
    ///// RECEIVING PHOTOS /////
    
    func respondToNotif(userInfo:NSNotification) {
    
        print("Responding to notif")
        // TODO: WORKING BUT NEW IMAGE ENDS UP UNDER OLD ONE AT MOMENT
        
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
                                    if self.receivedImages.count == newImages.count {
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
        
        //TEMP LOCATION FOR IMAGES
        var tempY:CGFloat = 100
        
        for image in receivedImages {
            print(image.displayed)
            if image.displayed {
                // Remove gesture recognizer from any older image
                if image.gestureRecognizers?.count > 1 {
                    image.removeGestureRecognizer(panReceivedThumbnails)
                }
                if image.gestureRecognizers?.count > 0 {
                    image.removeGestureRecognizer(tapPhoto)
                }
            } else {
                // Clip and shrink images, display in view
                image.frame.origin.y += tempY
                image.frame.size.height = ((image.frame.height/4.0) * 3.0)
                image.layer.cornerRadius = image.frame.width/2
                image.contentMode = .ScaleAspectFill
                image.clipsToBounds = true
                image.transform = CGAffineTransformMakeScale(0.2,0.2)
                tempY += 50
                image.setDisplayed()
                self.view.addSubview(image)
                
                // Add gesture recognizer to top image
                if image == receivedImages.last {
                    panReceivedThumbnails = UIPanGestureRecognizer(target: self, action: "didPanReceivedThumbnail:")
                    image.addGestureRecognizer(panReceivedThumbnails)
                    tapPhoto = UITapGestureRecognizer(target: self, action: "didTapTopImage:")
                    image.addGestureRecognizer(tapPhoto)
                    // MAY NEED TO WORK ON DISTINGUISHING GESTURES / PRIORITY
                }
            }
        }
    }
    
    func didTapTopImage(sender:UITapGestureRecognizer) {
        
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
            
            self.panReceivedPhoto = UIPanGestureRecognizer(target: self, action: "didPanReceivedPhoto:")
            
            // Loop through images, make them full size and not masked
            for image in self.receivedImages {
                if image.displayed {
                    image.layer.cornerRadius = 0
                    image.frame.size.height = ((image.frame.height/3.0) * 4.0)
                    image.transform = CGAffineTransformMakeScale(1,1)
                    image.addGestureRecognizer(self.panReceivedPhoto)
                }
            }

            }) { (finished) -> Void in
                
        }
    }
    
    func didPanReceivedThumbnail(sender:UIPanGestureRecognizer) {
        // Chat heads behavior
    }
    
    func didPanReceivedPhoto(sender:UIPanGestureRecognizer) {
        // Decide whether to save or discard
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}
