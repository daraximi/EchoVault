import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject var recorder = AudioRecorder()
    @State var audioPlayer: AVAudioPlayer?
    @State private var playingURL: URL?
    @State private var isPlaying = false
    @State private var showingRename = false
    @State private var selectedURL: URL?
    @State private var newName = ""
    @State private var playerDelegate: PlayerDelegate?
    
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var timer: Timer?
    
    @State private var uploadMessage = ""
    @State private var showingUploadAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 25) {
                    // Visualizer / Meter
                    HStack(spacing: 4) {
                        ForEach(0..<10) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(recorder.isRecording ? Color.red : Color.blue)
                                .frame(width: 6, height: recorder.isRecording ? CGFloat.random(in: 20...80) * CGFloat(recorder.soundLevel) : 10)
                                .animation(.easeInOut(duration: 0.1), value: recorder.soundLevel)
                        }
                    }
                    .frame(height: 100)
                    
                    // Main Record Button
                    Button(action: {
                        recorder.isRecording ? recorder.stopRecording() : recorder.startRecording()
                    }) {
                        ZStack {
                            Circle()
                                .fill(recorder.isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                .frame(width: 90, height: 90)
                            Circle()
                                .fill(recorder.isRecording ? Color.red : Color.blue)
                                .frame(width: 70, height: 70)
                            Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 30, weight: .bold))
                        }
                    }
                    .scaleEffect(recorder.isRecording ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: recorder.isRecording)
                    
                    // Recordings List
                    List {
                        ForEach(recorder.recordings, id: \.self) { url in
                            RecordingRow(
                                url: url,
                                isPlaying: playingURL == url && isPlaying,
                                isCurrentRow: playingURL == url,
                                currentTime: $currentTime,
                                duration: duration,
                                onPlay: { togglePlayback(for: url) },
                                onRename: {
                                    selectedURL = url
                                    newName = url.deletingPathExtension().lastPathComponent
                                    showingRename = true
                                },
                                onSeek: { value in seekAudio(to: value) },
                                onUpload: {
                                    Task {
                                        do {
                                            let response = try await APIClient.uploadAudio(fileURL: url)
                                            // Success! Update the UI
                                            uploadMessage = "Successfully uploaded: \(response.filename)"
                                            showingUploadAlert = true
                                        } catch {
                                            // Error! Update the UI
                                            uploadMessage = "Upload failed: \(error.localizedDescription)"
                                            showingUploadAlert = true
                                        }
                                    }
                                }
                            )
                        }
                        .onDelete(perform: recorder.deleteRecording)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("EchoVault")
            .alert("Rename Recording", isPresented: $showingRename) {
                TextField("New Name", text: $newName)
                Button("Save") {
                    if let url = selectedURL { recorder.renameRecording(from: url, toName: newName) }
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Upload Status", isPresented: $showingUploadAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(uploadMessage)
            }
        }
    }
    
    
    
    func togglePlayback(for url: URL) {
        if playingURL == url && isPlaying {
            audioPlayer?.pause()
            isPlaying = false
            timer?.invalidate()
        } else {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                duration = audioPlayer?.duration ?? 0
                
                playerDelegate = PlayerDelegate {
                    self.isPlaying = false
                    self.timer?.invalidate()
                    self.currentTime = 0
                }
                audioPlayer?.delegate = playerDelegate
                
                audioPlayer?.play()
                playingURL = url
                isPlaying = true
                
                // Start timer to update seek bar
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    currentTime = audioPlayer?.currentTime ?? 0
                }
            } catch {
                print("Playback failed")
            }
        }
    }
    
    func seekAudio(to value: TimeInterval) {
        audioPlayer?.currentTime = value
        currentTime = value
    }
}

// Custom Row Component for better UX
struct RecordingRow: View {
    let url: URL
    let isPlaying: Bool
    let isCurrentRow: Bool
    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    
    let onPlay: () -> Void
    let onRename: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onUpload: () -> Void // New Closure
    
    @State private var isUploading = false // Local state for UI feedback

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(url.deletingPathExtension().lastPathComponent)
                        .font(.headline)
                    Text(isCurrentRow ? formatTime(duration) : "--:--")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // --- NEW UPLOAD BUTTON ---
                Button(action: {
                    Task {
                        isUploading = true
                        onUpload()
                        // Note: In a real app, you'd want the parent to tell the row when it's done
                        // but for a quick test, we'll reset it after a delay or success.
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        isUploading = false
                    }
                }) {
                    if isUploading {
                        ProgressView().tint(.blue)
                    } else {
                        Image(systemName: "icloud.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.horizontal, 8)
                // -------------------------

                Button(action: onRename) {
                    Image(systemName: "pencil.circle").foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(isPlaying ? Color.orange : Color.blue))
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            if isCurrentRow {
                VStack(spacing: 6) {
                    Slider(value: Binding(
                        get: { currentTime },
                        set: { newValue in
                            currentTime = newValue
                            onSeek(newValue)
                        }
                    ), in: 0...max(duration, 0.1))
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(duration))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "--:--" }
        let totalSeconds = max(0, Int(time.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}



// Delegate methods
class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

