//
//  APIManager.swift
//  GuidO
//
//  Created by Amelie Beaudin on 2024-06-19.
//

import Foundation
import UIKit

class APIManager {
    
    static let shared = APIManager()
    
    private init() {}
    
    func predictImage(image: UIImage, completion: @escaping (String?, Error?) -> Void) {
        let url = URL(string: "http://127.0.0.1:5000/predict")!
        
        // Convert UIImage to Data
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            completion(nil, NSError(domain: "com.GuidO", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG data"]))
            return
        }
        
        // Create boundary string
        let boundary = UUID().uuidString
        
        // Prepare request body as NSMutableData
        let body = NSMutableData()
        
        // Append boundary as Data
        let boundaryPrefix = "--\(boundary)\r\n"
        if let boundaryData = boundaryPrefix.data(using: .utf8) {
            body.append(boundaryData)
        }
        
        // Append headers and other parts as Data
        let contentDisposition = "Content-Disposition: form-data; name=\"file\"; filename=\"image.jpeg\"\r\n"
        if let contentDispositionData = contentDisposition.data(using: .utf8) {
            body.append(contentDispositionData)
        }
        
        let contentType = "Content-Type: image/jpeg\r\n\r\n"
        if let contentTypeData = contentType.data(using: .utf8) {
            body.append(contentTypeData)
        }
        
        // Append image data as Data
        body.append(imageData)
        
        // Append closing boundary as Data
        let closingBoundary = "\r\n--\(boundary)--\r\n"
        if let closingBoundaryData = closingBoundary.data(using: .utf8) {
            body.append(closingBoundaryData)
        }
        
        // Create URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body as Data
        
        // Create URLSession
        let session = URLSession.shared
        
        // Create task
        let task = session.dataTask(with: request) { data, response, error in
            // Check for errors
            if let error = error {
                completion(nil, error)
                return
            }
            
            // Parse JSON response
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let prediction = json["prediction"] as? String {
                        completion(prediction, nil)
                    } else {
                        completion(nil, NSError(domain: "com.GuidO", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON response"]))
                    }
                } catch {
                    completion(nil, error)
                }
            } else {
                completion(nil, NSError(domain: "com.GuidO", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received from server"]))
            }
        }
        
        // Start the task
        task.resume()
    }
}









