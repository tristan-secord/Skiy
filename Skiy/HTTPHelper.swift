//
//  HTTPHelper.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-07-12.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import Foundation
import UIKit

enum HTTPRequestAuthType {
    case httpBasicAuth
    case httpTokenAuth
}

enum HTTPRequestContentType {
    case httpJsonContent
    case httpMultipartContent
}

struct HTTPHelper {
    static let API_AUTH_NAME = "skiyAPI"
    static let API_AUTH_PASSWORD = "9365C1AB4740F0E1AA9FF2943D9FB93B38A7A7F33E5DC499ACB04A42F1B05283"
    static let BASE_URL = "https://immense-forest-45065.herokuapp.com/api"

    
    func buildRequest(_ path: String!, method: String, authType: HTTPRequestAuthType,
                      requestContentType: HTTPRequestContentType = HTTPRequestContentType.httpJsonContent, requestBoundary:String = "") -> NSMutableURLRequest {
        // 1. Create the request URL from path
        var requestString = "\(HTTPHelper.BASE_URL)/\(path!)"
        requestString = requestString.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let requestURL = URL(string: requestString)
        let request = NSMutableURLRequest(url: requestURL!)
        
        // Set HTTP request method and Content-Type
        request.httpMethod = method
        
        // 2. Set the correct Content-Type for the HTTP Request. This will be multipart/form-data for photo upload request and application/json for other requests in this app
        switch requestContentType {
        case .httpJsonContent:
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        case .httpMultipartContent:
            let contentType = "multipart/form-data; boundary=\(requestBoundary)"
            request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        
        // 3. Set the correct Authorization header.
        switch authType {
        case .httpBasicAuth:
            // Set BASIC authentication header
            let basicAuthString = "\(HTTPHelper.API_AUTH_NAME):\(HTTPHelper.API_AUTH_PASSWORD)"
            let utf8str = basicAuthString.data(using: String.Encoding.utf8)
            let base64EncodedString = utf8str?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
            
            request.addValue("Basic \(base64EncodedString!)", forHTTPHeaderField: "Authorization")
        case .httpTokenAuth:
            // Retreieve Auth_Token from Keychain
            if let userToken = KeychainAccess.passwordForAccount("Auth_Token", service: "KeyChainService") as String? {
                // Set Authorization header
                request.addValue("Token token=\(userToken)", forHTTPHeaderField: "Authorization")
            }
        }
        return request
    }
    
    
    func sendRequest(_ request: URLRequest, completion:@escaping (Data?, Error?) -> ()) {
        // Create a NSURLSession task
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                DispatchQueue.main.async (execute: { () -> Void in
                    completion(data, error)
                })
            }
            
            DispatchQueue.main.async(execute: { () -> Void in
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        completion(data, nil)
                    } else if httpResponse.statusCode == 401 {
                        let appDelegate =
                            UIApplication.shared.delegate as! AppDelegate
                        var aps = [String: AnyObject]()
                        aps["alert"] = "Unauthorized Access. Please sign in to continue." as AnyObject?
                        appDelegate.signOutFromPushNotification(aps)
                        return
                    } else {
                        do {
                            if let errorDict = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? NSDictionary {
                                let responseError : Error = NSError(domain: "HTTPHelperError", code: httpResponse.statusCode, userInfo: errorDict as? [AnyHashable: Any]) as Error
                                completion(data, responseError)
                            }
                        } catch {
                            print(error)
                        }
                    }
                }
            })
        }
        
        // start the task
        task.resume()
    }
    
    func uploadRequest(_ path: String, data: Data, title: String) -> NSMutableURLRequest {
        let boundary = "---------------------------14737809831466499882746641449"
        let request = buildRequest(path, method: "POST", authType: HTTPRequestAuthType.httpTokenAuth,
                                   requestContentType:HTTPRequestContentType.httpMultipartContent, requestBoundary:boundary) as NSMutableURLRequest
        
        let bodyParams : NSMutableData = NSMutableData()
        
        // build and format HTTP body with data
        // prepare for multipart form uplaod
        
        let boundaryString = "--\(boundary)\r\n"
        let boundaryData = boundaryString.data(using: String.Encoding.utf8) as Data!
        bodyParams.append(boundaryData!)
        
        // set the parameter name
        let imageMeteData = "Content-Disposition: attachment; name=\"image\"; filename=\"photo\"\r\n".data(using: String.Encoding.utf8, allowLossyConversion: false)
        bodyParams.append(imageMeteData!)
        
        // set the content type
        let fileContentType = "Content-Type: application/octet-stream\r\n\r\n".data(using: String.Encoding.utf8, allowLossyConversion: false)
        bodyParams.append(fileContentType!)
        
        // add the actual image data
        bodyParams.append(data)
        
        let imageDataEnding = "\r\n".data(using: String.Encoding.utf8, allowLossyConversion: false)
        bodyParams.append(imageDataEnding!)
        
        //let boundaryString2 = "--\(boundary)\r\n"
        let boundaryData2 = boundaryString.data(using: String.Encoding.utf8) as Data!
        
        bodyParams.append(boundaryData2!)
        
        // pass the caption of the image
        let formData = "Content-Disposition: form-data; name=\"title\"\r\n\r\n".data(using: String.Encoding.utf8, allowLossyConversion: false)
        bodyParams.append(formData!)
        
        let formData2 = title.data(using: String.Encoding.utf8, allowLossyConversion: false)
        bodyParams.append(formData2!)
        
        let closingFormData = "\r\n".data(using: String.Encoding.utf8, allowLossyConversion: false)
        bodyParams.append(closingFormData!)
        
        let closingData = "--\(boundary)--\r\n"
        let boundaryDataEnd = closingData.data(using: String.Encoding.utf8) as Data!
        
        bodyParams.append(boundaryDataEnd!)
        
        request.httpBody = bodyParams as Data
        return request
    }
    
    func getErrorMessage(_ error: NSError) -> NSString {
        var errorMessage : NSString
        
        // return correct error message
        if error.domain == "HTTPHelperError" {
            let userInfo = error.userInfo as NSDictionary!
            errorMessage = userInfo?.value(forKey: "message") as! NSString
        } else {
            errorMessage = error.description as NSString
        }
        
        return errorMessage
    }
}
