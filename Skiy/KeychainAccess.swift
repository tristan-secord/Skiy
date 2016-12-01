//
//  KeychainAccess.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-07-12.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import Foundation

open class KeychainAccess {
    fileprivate class func secClassGenericPassword() -> String {
        return NSString(format: kSecClassGenericPassword) as String
    }
    
    fileprivate class func secClass() -> String {
        return NSString(format: kSecClass) as String
    }
    
    fileprivate class func secAttrService() -> String {
        return NSString(format: kSecAttrService) as String
    }
    
    fileprivate class func secAttrAccount() -> String {
        return NSString(format: kSecAttrAccount) as String
    }
    
    fileprivate class func secValueData() -> String {
        return NSString(format: kSecValueData) as String
    }
    
    fileprivate class func secReturnData() -> String {
        return NSString(format: kSecReturnData) as String
    }
    
    open class func setPassword(_ password: String, account: String, service: String = "keyChainDefaultService") {
        let secret: Data = password.data(using: String.Encoding.utf8, allowLossyConversion: false)!
        let objects: Array = [secClassGenericPassword(), service, account, secret] as [Any]
        
        let keys: Array = [secClass(), secAttrService(), secAttrAccount(), secValueData()]
        
        let query = NSDictionary(objects: objects, forKeys: keys as [NSCopying])
        
        SecItemDelete(query as CFDictionary)
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    open class func passwordForAccount(_ account: String, service: String = "keyChainDefaultService") -> String? {
        let queryAttributes = NSDictionary(objects: [secClassGenericPassword(), service, account, true], forKeys: [secClass() as NSCopying, secAttrService() as NSCopying, secAttrAccount() as NSCopying, secReturnData() as NSCopying])
        
        var dataTypeRef : AnyObject?
        var retrievedData : Data?
        SecItemCopyMatching(queryAttributes, &dataTypeRef)
        
        if dataTypeRef == nil {
            return nil
        }
        
        retrievedData = dataTypeRef as? Data
        let password = NSString(data: retrievedData!, encoding: String.Encoding.utf8.rawValue)
        return (password as! String)
    }
    
    open class func deletePasswordForAccount(_ password: String, account: String, service: String = "keyChainDefaultService") {
        let secret: Data = password.data(using: String.Encoding.utf8, allowLossyConversion: false)!
        let objects: Array = [secClassGenericPassword(), service, account, secret] as [Any]
        
        let keys: Array = [secClass(), secAttrService(), secAttrAccount(), secValueData()]
        let query = NSDictionary(objects: objects, forKeys: keys as [NSCopying])
        
        SecItemDelete(query as CFDictionary)
    }
}
