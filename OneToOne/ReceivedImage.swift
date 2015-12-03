//
//  ReceivedImage.swift
//  OneToOneAlpha
//
//  Created by Sam Wander on 11/21/15.
//  Copyright © 2015 FBD. All rights reserved.
//

import UIKit
import Parse

class ReceivedImage: UIImageView {

    var objectID = String()
    var created = NSDate()
    var originalCenter:CGPoint!
    var originalY: CGFloat!
    var displayed = false
    var imageData:NSData!
    
    // Store ID with image
    func storeObjectID(id: String) {
        objectID = id
    }
    
    // Store created date
    func storeCreatedDate(date: NSDate) {
        created = date
    }
    
    // Store originalY position when pan begins
    func storeOriginalCenter(center:CGPoint) {
        originalCenter = center
    }
    
    // Store originalY position when pan begins
    func storeOriginalY(pos:CGFloat) {
        originalY = pos
    }
    
    // Set when displayed
    func setDisplayed() {
        displayed = true
    }
    
    func setImageForView(data: NSData) {
        self.image = UIImage(data: data)
        imageData = data
    }
    
    // Remove image from Parse
    func deleteSeenPhoto(id: String) {
        let query = PFQuery(className:"Photo")
        query.getObjectInBackgroundWithId(id) {
            (imageToDelete: PFObject?, error: NSError?) -> Void in
            if error != nil {
                print(error)
            } else if let imageToDelete = imageToDelete {
                imageToDelete.deleteInBackground()
            }
        }
    }
    
}
