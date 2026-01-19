//
//  AudioRecorder.swift
//  EchoVault
//
//  Created by Oluwadarasimi Oloyede on 13/01/2026.
//

import Foundation
import AVFoundation
import Combine

class AudioRecorder: ObservableObject {
    var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    
    @Published var isRecording = false
    @Published var recordings: [URL] = []
    @Published var soundLevel: Float = 0.5
    @Published var metadataStore: [String: RecordingMetadata] = [:]
    
    init() {
        loadMetadata()
        fetchRecordings()
    }
    
    // MARK: - Metadata Management
    
    private func loadMetadata() {
        guard let data = UserDefaults.standard.data(forKey: "RecordingMetadata"),
              let decoded = try? JSONDecoder().decode([String: RecordingMetadata].self, from: data) else {
            return
        }
        metadataStore = decoded
    }
    
    func saveMetadata(for filename: String, metadata: RecordingMetadata) {
        metadataStore[filename] = metadata
        persistMetadata()
    }
    
    private func persistMetadata() {
        guard let encoded = try? JSONEncoder().encode(metadataStore) else {
            print("❌ Failed to encode metadata")
            return
        }
        UserDefaults.standard.set(encoded, forKey: "RecordingMetadata")
    }
    
    private func cleanupOrphanedMetadata() {
        let currentFilenames = Set(recordings.map { $0.lastPathComponent })
        let metadataKeys = Set(metadataStore.keys)
        
        let orphanedKeys = metadataKeys.subtracting(currentFilenames)
        
        if !orphanedKeys.isEmpty {
            for key in orphanedKeys {
                metadataStore.removeValue(forKey: key)
            }
            persistMetadata()
            print("🧹 Cleaned up \(orphanedKeys.count) orphaned metadata entries")
        }
    }
    
    // MARK: - Recording Management
    
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true)
        } catch {
            print("❌ Audio session setup failed: \(error.localizedDescription)")
            return
        }
        
        let timestamp = Date().formatted(.iso8601)
        let filename = getDocumentsDirectory().appendingPathComponent("Recording_\(timestamp).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: filename, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            
            // Start polling for volume levels
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.audioRecorder?.updateMeters()
                
                // Normalize decibels to a 0.1 - 1.0 range for the UI
                let level = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                self.soundLevel = max(0.1, Float(level + 160) / 160.0)
            }
        } catch {
            print("❌ Recording failed: \(error.localizedDescription)")
            isRecording = false
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        fetchRecordings()
    }
    
    func fetchRecordings() {
        let directory = getDocumentsDirectory()
        
        guard let content = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            print("❌ Failed to fetch recordings")
            return
        }
        
        recordings = content
            .filter { $0.pathExtension == "m4a" }
            .sorted { url1, url2 in
                // Sort by creation date (newest first)
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
        
        // Clean up orphaned metadata
        cleanupOrphanedMetadata()
    }
    
    func renameRecording(from oldURL: URL, toName newName: String) {
        let sanitizedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !sanitizedName.isEmpty else {
            print("❌ Invalid filename")
            return
        }
        
        let newURL = getDocumentsDirectory().appendingPathComponent("\(sanitizedName).m4a")
        
        // Check if file already exists
        if FileManager.default.fileExists(atPath: newURL.path) {
            print("❌ File already exists: \(sanitizedName)")
            return
        }
        
        do {
            let oldFilename = oldURL.lastPathComponent
            
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            
            // Move metadata to new filename
            if let metadata = metadataStore[oldFilename] {
                metadataStore.removeValue(forKey: oldFilename)
                metadataStore[newURL.lastPathComponent] = metadata
                persistMetadata()
            }
            
            fetchRecordings()
        } catch {
            print("❌ Rename failed: \(error.localizedDescription)")
        }
    }
    
    func deleteRecording(at offsets: IndexSet) {
        for index in offsets {
            let url = recordings[index]
            let filename = url.lastPathComponent
            
            do {
                try FileManager.default.removeItem(at: url)
                
                // Remove associated metadata
                metadataStore.removeValue(forKey: filename)
                persistMetadata()
            } catch {
                print("❌ Delete failed: \(error.localizedDescription)")
            }
        }
        
        fetchRecordings()
    }
    
    deinit {
        timer?.invalidate()
    }
}
