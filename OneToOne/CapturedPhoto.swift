//
//  CapturedPhoto.swift
//  OneToOne
//
//  Created by Sam Wander on 11/25/15.
//  Copyright © 2015 FBD. All rights reserved.
//

import UIKit
import Parse

class CapturedPhoto: UIImageView {

    var imageData: NSData!
    var originalY: CGFloat!
    
    // Store image data with the image
    func storeData(data: NSData) {
        imageData = data
    }
    
    // Add image to image view
    func addImage(data: NSData) {
        self.image = UIImage(data: data)
    }
    
    // Store originalY position when pan begins
    func storeOriginalY(pos:CGFloat) {
        originalY = pos
    }
    
    // Send image to Parse and notify recipient
    func sendImage(data: NSData, recipientUsername:String) {
        
        // Save to user's photos
        UIImageWriteToSavedPhotosAlbum(UIImage(data: data)!, nil, nil, nil)
        
        let recipient: PFUser?
        let query:PFQuery = PFUser.query()!
        query.whereKey("username", equalTo:recipientUsername)
        do {
            recipient = try query.getFirstObject() as? PFUser
            print(recipient)
        } catch _ {
            recipient = nil
            print(recipient)
        }
        
        if recipient != nil {
            let imageFile = PFFile(name:"image.png", data:data)
            
            let photo = PFObject(className:"Photo")
            photo["recipient"] = recipientUsername
            photo["viewed"] = false
            photo["imageFile"] = imageFile
            
            // Permissions...
            let acl = PFACL()
            acl.setPublicReadAccess(true)
            acl.setWriteAccess(true, forUser: recipient!)
            acl.setPublicWriteAccess(true)
            photo.ACL = acl
            
            photo.saveInBackgroundWithBlock({ (success, error) -> Void in
                if success {
                    print("Saved image to Parse")
                    
                    // Create our Installation query
                    let pushQuery = PFInstallation.query()
                    pushQuery!.whereKey("user", equalTo: recipient!)
                    
                    let data = [
                        "alert" : "📷 You received a new photo!",
                        "event" : "photo"
                    ]
                    
                    // Send push notification to query
                    let push = PFPush()
                    push.setQuery(pushQuery) // Set our Installation query
                    push.setData(data)
                    push.sendPushInBackground()
                } else {
                    print(error)
                }
            })
        }
    }
}
