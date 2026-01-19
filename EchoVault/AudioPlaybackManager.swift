//
//  AudioPlaybackManager.swift
//  EchoVault
//
//  Manages audio playback state separately from recording
//

import Foundation
import AVFoundation
import Combine

class AudioPlaybackManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentURL: URL?
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    override init() {
        super.init()
    }
    
    func togglePlayback(for url: URL) {
        if currentURL == url && isPlaying {
            pause()
        } else {
            play(url: url)
        }
    }
    
    func play(url: URL) {
        // Stop current playback if any
        cleanup()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            
            duration = audioPlayer?.duration ?? 0
            currentURL = url
            
            audioPlayer?.play()
            isPlaying = true
            
            // Start timer for seek bar updates
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.currentTime = self.audioPlayer?.currentTime ?? 0
            }
        } catch {
            print("❌ Playback failed: \(error.localizedDescription)")
            cleanup()
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    func cleanup() {
        audioPlayer?.stop()
        timer?.invalidate()
        timer = nil
        isPlaying = false
        currentTime = 0
        
        // Keep currentURL and duration so seek bar remains visible when paused
        // Only clear when playing a different recording
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioPlaybackManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.currentTime = 0
            self?.timer?.invalidate()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            print("❌ Decode error: \(error?.localizedDescription ?? "Unknown")")
            self?.cleanup()
        }
    }
}
