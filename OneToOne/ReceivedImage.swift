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
    
    // Store ID with image
    func storeObjectID(id: String) {
        objectID = id
    }
    
    func setImageForView(data: NSData) {
        self.image = UIImage(data: data)
    }
    
    // Remove image from Parse
    func deleteSeenPhoto(id: String) {
        let query = PFQuery(className:"SentPhoto")
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
