//
//  AudioRecorder.swift
//  EchoVault
//
//  Created by Oluwadarasimi Oloyede on 13/01/2026.
//

import Foundation
import AVFoundation
import Combine

class AudioRecorder:ObservableObject{
    var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    @Published var isRecording = false
    @Published var recordings: [URL] = []
    @Published var soundLevel:Float = 0.5
    
    init(){
        fetchRecordings()
    }
    
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try? session.setActive(true)
        
        let filename = getDocumentsDirectory().appendingPathComponent("Recording \(recordings.count + 1).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try? AVAudioRecorder(url: filename, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()
        isRecording = true
        
        // Start polling for volume levels
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.audioRecorder?.updateMeters()
            // Normalize decibels to a 0.1 - 1.0 range for the UI
            let level = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
            self.soundLevel = max(0.1 as Float, Float(level + 160) / 160.0)
        }
    }
    func stopRecording() {
        audioRecorder?.stop()
        timer?.invalidate()
        isRecording = false
        fetchRecordings()
    }
    func fetchRecordings() {
        let directory = getDocumentsDirectory()
        let content = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        recordings = content.sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
    }
    
    func renameRecording(from: URL, toName: String) {
        let newURL = getDocumentsDirectory().appendingPathComponent("\(toName).m4a")
        try? FileManager.default.moveItem(at: from, to: newURL)
        fetchRecordings()
    }
    
    func deleteRecording(at offsets: IndexSet) {
        for index in offsets {
            try? FileManager.default.removeItem(at: recordings[index])
        }
        fetchRecordings()
    }
}

