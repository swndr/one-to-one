//
//  User.swift
//  OneToOneAlpha
//
//  Created by Sam Wander on 11/19/15.
//  Copyright © 2015 FBD. All rights reserved.
//

import UIKit
import Parse
var timeCreated = NSDate()

enum UserStatus {
    case None, Anonymous, Unpaired, Paired
    
    init() {
        self = .None
    }
}

enum CodeStatus {
    case None, Expired, Used, Valid
    
    init() {
        self = .None
    }
}

// Create an anonymous user
func createAnonUser() -> Bool {
    var success = false
    
    PFAnonymousUtils.logInWithBlock {
        (user: PFUser?, error: NSError?) -> Void in
        if error != nil || user == nil {
            print("Anonymous login failed: \(error)")
        } else {
            print("Anonymous user logged in: \(user)")
            success = true
        }
    }
    return success
}

// Determine user status, if none create anonymous
func getCurrentUser() -> UserStatus {
    
    var currentUserStatus = UserStatus()
    let currentUser = PFUser.currentUser()
    
    // If there's a user that isn't anonymous
    if currentUser != nil && currentUser?.username != nil {
        print("Existing user: \(currentUser)")
        
        // Determine if paired / unpaired
        if currentUser!["recipient"] == nil {
            print("Found nil")
            currentUserStatus = .Anonymous // prepare to go to login screen
        }
        else if currentUser!["recipient"] as? String == "pending" {
            currentUserStatus = .Unpaired // prepare to go to pairing screen
        } else {
            currentUserStatus = .Paired // prepare to go to camera
        }

    } else {
        print("New user required")
    }
    return currentUserStatus
}

// Validate code from text field
func validateCode(enteredCode: String, completion: (result:Bool, codeStatus:CodeStatus, code:PFObject?) -> Void) {
    
    var querySuccess = false
    var status = CodeStatus()
    var codeObject: PFObject?
    
    // Query code from text field
    let query = PFQuery(className:"AccountCode")
    query.whereKey("code", equalTo:(enteredCode))
    query.findObjectsInBackgroundWithBlock {
        (objects: [PFObject]?, error: NSError?) -> Void in
        print("Searching...")
        if error == nil {
            // Found a code
            if objects!.count == 1 {
                // Existing code entry
                codeObject = objects!.first
                if hasCodeExpired(codeObject!) {
                    status = .Expired
                } else if hasCodeBeenUsed(codeObject!) {
                    status = .Used
                } else {
                    status = .Valid
                }
            }
            querySuccess = true
        } else {
            // Log details of the failure
            print("Error: \(error!) \(error!.userInfo)")
            querySuccess = false
        }
        completion(result: querySuccess, codeStatus: status, code: codeObject)
    }
}

// New initial user
func createUser(enteredCode: String, completion: (result: Bool) -> Void) {
    
    timeCreated = NSDate()
    
    let newUser = PFUser.currentUser()
    newUser!.username = randomStringWithLength(8) as String
    newUser!.password = randomStringWithLength(8) as String
    
    newUser!["recipient"] = "pending"
    newUser!["code"] = enteredCode // Store the code with user
    
    newUser!.signUpInBackgroundWithBlock {
        (succeeded: Bool, error: NSError?) -> Void in
        if let error = error {
            let errorString = error.userInfo["error"] as? NSString
            // Show the errorString somewhere and let the user try again.
            print(errorString)
        } else {
            print("Success: \(succeeded)")
            let accountCode = PFObject(className:"AccountCode")
            accountCode["code"] = enteredCode
            accountCode["used"] = false
            accountCode["creator"] = newUser!["username"] // Person who created code
            accountCode["receiver"] = "pending" // No receiver yet
            
            // Permissions...
            let acl = PFACL()
            acl.setPublicReadAccess(true)
            acl.setPublicWriteAccess(true) // So next person can be added as recipient
            accountCode.ACL = acl
            accountCode.saveInBackground()
            
            // Associate the device with a user (will this work if they declined notifications?)
            let installation = PFInstallation.currentInstallation()
                installation["user"] = newUser!
                installation.saveInBackground()
 
            completion(result: true)
        }
    }
}

// New recipient user
func createUser(codeObject: PFObject, completion: (result: Bool) -> Void) {
    
    let newUser = PFUser.currentUser()
    newUser!.username = randomStringWithLength(8) as String
    newUser!.password = randomStringWithLength(8) as String
    
    newUser!["recipient"] = codeObject["creator"] // The user who created this code
    newUser!["code"] = codeObject["code"]
    
    newUser!.signUpInBackgroundWithBlock {
        (succeeded: Bool, error: NSError?) -> Void in
        if let error = error {
            let errorString = error.userInfo["error"] as? NSString
            print(errorString)
        } else {
            print("Success: \(succeeded)")
            codeObject["used"] = true
            codeObject["receiver"] = newUser!["username"] // Add this receiver to the code item so first user can add them as recipient
            codeObject.saveInBackground()
            
            // Associate the device with a user (will this work if they declined notifications?)
            let installation = PFInstallation.currentInstallation()
            installation["user"] = newUser!
            installation.saveInBackgroundWithBlock({ (success:Bool, error:NSError?) -> Void in
                if let error = error {
                    let errorString = error.userInfo["error"] as? NSString
                    print(errorString)
                } else {
                    // Get recipient to notify
                    let recipient: PFUser?
                    let query:PFQuery = PFUser.query()!
                    query.whereKey("username", equalTo:codeObject["creator"])
                    do {
                        recipient = try query.getFirstObject() as? PFUser
                        print(recipient)
                    } catch _ {
                        recipient = nil
                        print(recipient)
                    }
                    
                    if recipient != nil {
                        // Create our Installation query
                        let pushQuery = PFInstallation.query()
                        pushQuery!.whereKey("user", equalTo: recipient!)
                        
                        let data = [
                            "alert" : "You're paired, now you can start sending photos!",
                            "event" : "paired"
                        ]
                        
                        // Send push notification to query
                        let push = PFPush()
                        push.setQuery(pushQuery) // Set our Installation query
                        push.setData(data)
                        push.sendPushInBackground()
                    }
                }
            })
            
            completion(result: true)
        }
    }
}

// New code for existing user
func renewCode(enteredCode: String, completion: (result: Bool) -> Void) {
    
    let existingUser = PFUser.currentUser()

    // Set new details
    existingUser!["recipient"] = "pending"
    existingUser!["code"] = enteredCode // Store the code with user
    
    existingUser!.saveInBackgroundWithBlock { (success: Bool, error: NSError?) -> Void in
        if let error = error {
            let errorString = error.userInfo["error"] as? NSString
            print(errorString)
        } else {
            let accountCode = PFObject(className:"AccountCode")
            accountCode["code"] = enteredCode
            accountCode["used"] = false
            accountCode["creator"] = existingUser!["username"] // Person who created code
            accountCode["receiver"] = "pending" // No receiver yet
            
            // Permissions...
            let acl = PFACL()
            acl.setPublicReadAccess(true)
            acl.setPublicWriteAccess(true) // So next person can be added as recipient
            accountCode.ACL = acl
            accountCode.saveInBackground()
            
            completion(result: true)
        }
    }
}

// Check when submit code, or while waiting to pair
func hasCodeExpired(codeObject: PFObject) -> Bool {

    var expired = false
    let minutesToPair = 10.00
    let interval = NSDate().timeIntervalSinceDate((codeObject.createdAt)!) // time since code created

    // Check time since code created is within time window, and if used yet
    if interval > (minutesToPair * 60.00) {
        expired = true
        print("code expired try again")
    }
    return expired
}

// Check when submit code
func hasCodeBeenUsed(codeObject: PFObject) -> Bool {
    
    var used = false
    
    if codeObject["used"] as! Bool == true {
        used = true
    }
    
    return used
}

// Attempt to delete a used / expired code (may no longer exist)
func deleteCode(currentUser: PFUser, completion: (result:Bool) -> Void) {
    
    let currentUser = PFUser.currentUser()
    
    // Find their code and delete it first
    let query = PFQuery(className:"AccountCode")
    query.whereKey("code", equalTo:(currentUser!["code"])) // The code they signed up with is stored with the user
    query.findObjectsInBackgroundWithBlock {
        (objects: [PFObject]?, error: NSError?) -> Void in
        
        if error == nil {
            // Found a code
            if objects!.count == 1 {
                // Existing code entry
                let codeObject = objects!.first
                // Now delete the code so it can be reused
                codeObject!.deleteInBackground()
                print("Found and deleted a code")
            }
            completion(result: true)
        } else {
            // Log details of the failure
            print("Error: \(error!) \(error!.userInfo)")
        }
    }
}

// To be called from pairing screen if code not expired
func attemptToPair(currentUser: PFUser, completion: (result:Bool, userStatus:UserStatus) -> Void) {
    
    var querySuccess = false
    var status = UserStatus.Unpaired
    
    let query = PFQuery(className:"AccountCode")
    query.whereKey("code", equalTo:(currentUser["code"])) // The code they signed up with is stored with the user
    query.findObjectsInBackgroundWithBlock {
        (objects: [PFObject]?, error: NSError?) -> Void in
        
        if error == nil {
            // Found a code
            if objects!.count == 1 {
                // Existing code entry
                let codeObject = objects!.first
                // Does this code have a receiver yet?
                if codeObject!["receiver"] as? String == "pending" {
                    // Still waiting
                    print("Still waiting for someone to accept")
                } else {
                    // Recevier found – associate recipient with user
                    currentUser["recipient"] = codeObject!["receiver"]
                    currentUser.saveInBackground()
                    status = .Paired
                    
                    // Now delete the code so it can be reused
                    codeObject!.deleteInBackground() 
                }
                querySuccess = true
            }
        } else {
                // Log details of the failure
                print("Error: \(error!) \(error!.userInfo)")
                querySuccess = false
        }
        completion(result: querySuccess, userStatus: status)
    }
}

func randomStringWithLength (len : Int) -> NSString {
    
    let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let randomString : NSMutableString = NSMutableString(capacity: len)
    
    for (var i = 0; i < len; i++){
        let length = UInt32 (letters.length)
        let rand = arc4random_uniform(length)
        randomString.appendFormat("%C", letters.characterAtIndex(Int(rand)))
    }
    return randomString
}