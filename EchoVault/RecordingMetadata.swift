//
//  RecordingMetadata.swift
//  EchoVault
//
//  Created by Oluwadarasimi Oloyede on 19/01/2026.
//

import Foundation

struct RecordingMetadata: Codable{
    let transcript: String
    let sentimentLabel: String
    let polarity: Double
    var isUploaded: Bool = false
}
