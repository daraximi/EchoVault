////
////  APIClient.swift
////  EchoVault
////
////  Created by Oluwadarasimi Oloyede on 14/01/2026.
////
//
//import Foundation
//
//struct UploadResponse: Codable {
//    let file_id: String
//    let original_filename: String
//    let saved_filename: String
//    let local_path:String
//}
//
//final class APIClient {
//    static let baseURL = "http://192.168.5.141:8000"
//
//    static func uploadAudio(fileURL: URL) async throws -> UploadResponse{
//        let url = URL(string: "\(baseURL)/upload")!
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//
//        let boundary = UUID().uuidString
//        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
//
//        let audioData = try Data(contentsOf: fileURL)
//        let filename = fileURL.lastPathComponent
//
//        var body = Data()
//
//        body.append("--\(boundary)\r\n".data(using: .utf8)!)
//                body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
//                body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
//                body.append(audioData)
//                body.append("\r\n".data(using: .utf8)!)
//                body.append("--\(boundary)--\r\n".data(using: .utf8)!)
//
//        request.httpBody = body
//        let(data, response) = try await URLSession.shared.data(for: request)
//
//        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
//            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
//            throw NSError(domain:"UploadError", code:0, userInfo: [NSLocalizedDescriptionKey:msg])
//        }
//        return try JSONDecoder().decode(UploadResponse.self, from:data)
//    }
//}

import Foundation

struct UploadResponse: Codable {
    let file_id: String
    let filename: String
    let url: String
    let status_code: Int
}
enum APIError: Error {
    case invalidURL
    case serverError(String)
    case decodingError
}

final class APIClient {
    // TIP: Use a computed property or config file for base URLs
    static let baseURL = "http://192.168.5.141:8000"
    
    static func uploadAudio(fileURL: URL) async throws -> UploadResponse {
        guard let url = URL(string: "\(baseURL)/upload") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60 // Give uploads more time
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Use Data(contentsOf:) carefully; for very large files, use URLSessionUploadTask with a file
        let audioData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        
        let body = createMultipartBody(
            boundary: boundary,
            data: audioData,
            mimeType: "audio/m4a", 
            filename: filename
        )
        
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid Response")
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status: \(httpResponse.statusCode)"
            throw APIError.serverError(errorMsg)
        }
        
        do {
            return try JSONDecoder().decode(UploadResponse.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
    
    private static func createMultipartBody(boundary: String, data: Data, mimeType: String, filename: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        
        body.append("--\(boundary)\(lineBreak)")
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\(lineBreak)")
        body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)")
        body.append(data)
        body.append("\(lineBreak)")
        body.append("--\(boundary)--\(lineBreak)")
        
        return body
    }
}

// Helper to append strings to Data easily
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
