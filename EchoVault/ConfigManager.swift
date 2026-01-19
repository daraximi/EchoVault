//
//  ConfigManager.swift
//  EchoVault
//
//  Created by Oluwadarasimi Oloyede on 19/01/2026.
//

import Foundation

class ConfigManager {
    static let shared = ConfigManager()
    
    private var config: [String: Any]?
    
    private init() {
        if let path = Bundle.main.path(forResource: "config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
            config = dict
        }
    }
    
    func getValue(forKey key: String) -> String? {
        return config?[key] as? String
    }
}
