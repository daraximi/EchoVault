//
//  APIClient.swift
//  EchoVault
//
//  Created by Oluwadarasimi Oloyede on 14/01/2026.
//

import Foundation

struct UploadResponse: Codable {
    let file_id: String
    let transcript: String
    let polarity: Double
    let sentiment_label: String
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case serverError(String)
    case decodingError(Error)
    case networkError(Error)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL. Please check configuration."
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out. Please try again."
        }
    }
}

final class APIClient {
    // MARK: - Configuration
    
    // TODO: Move this to a Config.plist or environment variable
    static let baseURL = ConfigManager.shared.getValue(forKey: "ip_address")!
    static let timeout: TimeInterval = 60
    static let maxRetries = 2
    
    // MARK: - Upload Audio
    
    static func uploadAudio(fileURL: URL, retryCount: Int = 0) async throws -> UploadResponse {
        guard let url = URL(string: "\(baseURL)/upload_audio") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Read audio file
        let audioData: Data
        do {
            audioData = try Data(contentsOf: fileURL)
        } catch {
            throw APIError.networkError(error)
        }
        
        let filename = fileURL.lastPathComponent
        let body = createMultipartBody(
            boundary: boundary,
            data: audioData,
            mimeType: "audio/m4a",
            filename: filename
        )
        
        // Perform upload
        do {
            let (data, response) = try await URLSession.shared.upload(for: request, from: body)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError("Invalid response type")
            }
            
            // Handle HTTP errors
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Status: \(httpResponse.statusCode)"
                
                // Retry on server errors (5xx)
                if (500...599).contains(httpResponse.statusCode) && retryCount < maxRetries {
                    print("⚠️ Server error, retrying... (attempt \(retryCount + 1)/\(maxRetries))")
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 1_000_000_000))
                    return try await uploadAudio(fileURL: fileURL, retryCount: retryCount + 1)
                }
                
                throw APIError.serverError(errorMsg)
            }
            
            // Decode response
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(UploadResponse.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
            
        } catch let error as APIError {
            throw error
        } catch {
            // Handle network errors with retry
            if retryCount < maxRetries {
                print("⚠️ Network error, retrying... (attempt \(retryCount + 1)/\(maxRetries))")
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 1_000_000_000))
                return try await uploadAudio(fileURL: fileURL, retryCount: retryCount + 1)
            }
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private static func createMultipartBody(
        boundary: String,
        data: Data,
        mimeType: String,
        filename: String
    ) -> Data {
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

// MARK: - Data Extension

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - Configuration Helper (Optional)

struct AppConfiguration {
    static var apiBaseURL: String {
        // Try to load from Info.plist or Config.plist
        if let configURL = Bundle.main.url(forResource: "Config", withExtension: "plist"),
           let config = NSDictionary(contentsOf: configURL),
           let baseURL = config["APIBaseURL"] as? String {
            return baseURL
        }
        
        // Fallback to default
        return "http://192.168.5.145:8000"
    }
}
