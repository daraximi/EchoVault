import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject var recorder = AudioRecorder()
    @StateObject var audioManager = AudioPlaybackManager()
    
    @State private var showingRename = false
    @State private var selectedURL: URL?
    @State private var newName = ""
    
    @State private var uploadMessage = ""
    @State private var showingUploadAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 25) {
                    // Visualizer / Meter
                    AudioVisualizerView(
                        isRecording: recorder.isRecording,
                        soundLevel: recorder.soundLevel
                    )
                    
                    // Main Record Button
                    RecordButton(
                        isRecording: recorder.isRecording,
                        action: {
                            recorder.isRecording ? recorder.stopRecording() : recorder.startRecording()
                        }
                    )
                    
                    // Recordings List
                    RecordingsListView(
                        recordings: recorder.recordings,
                        metadataStore: recorder.metadataStore,
                        audioManager: audioManager,
                        onRename: { url in
                            selectedURL = url
                            newName = url.deletingPathExtension().lastPathComponent
                            showingRename = true
                        },
                        onUpload: { url in
                            handleUpload(for: url)
                        },
                        onDelete: { indexSet in
                            recorder.deleteRecording(at: indexSet)
                        }
                    )
                }
            }
            .navigationTitle("EchoVault")
            .alert("Rename Recording", isPresented: $showingRename) {
                TextField("New Name", text: $newName)
                Button("Save") {
                    if let url = selectedURL {
                        recorder.renameRecording(from: url, toName: newName)
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Upload Status", isPresented: $showingUploadAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(uploadMessage)
            }
            .onDisappear {
                audioManager.cleanup()
            }
        }
    }
    
    private func handleUpload(for url: URL) {
        let filename = url.lastPathComponent
        
        Task {
            do {
                let response = try await APIClient.uploadAudio(fileURL: url)
                
                let meta = RecordingMetadata(
                    transcript: response.transcript,
                    sentimentLabel: response.sentiment_label,
                    polarity: response.polarity,
                    isUploaded: true
                )
                
                await MainActor.run {
                    recorder.saveMetadata(for: filename, metadata: meta)
                    
                    let shortTranscript = String(response.transcript.prefix(50))
                    uploadMessage = "Success! Transcript: \(shortTranscript)..."
                    showingUploadAlert = true
                }
            } catch {
                await MainActor.run {
                    uploadMessage = "Upload failed: \(error.localizedDescription)"
                    showingUploadAlert = true
                }
            }
        }
    }
}

// MARK: - Audio Visualizer
struct AudioVisualizerView: View {
    let isRecording: Bool
    let soundLevel: Float
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<10, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(
                        width: 6,
                        height: isRecording
                            ? CGFloat.random(in: 20...80) * CGFloat(soundLevel)
                            : 10
                    )
                    .animation(.easeInOut(duration: 0.1), value: soundLevel)
            }
        }
        .frame(height: 100)
    }
}

// MARK: - Record Button
struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 90, height: 90)
                Circle()
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(width: 70, height: 70)
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 30, weight: .bold))
            }
        }
        .scaleEffect(isRecording ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isRecording)
    }
}

// MARK: - Recordings List
struct RecordingsListView: View {
    let recordings: [URL]
    let metadataStore: [String: RecordingMetadata]
    @ObservedObject var audioManager: AudioPlaybackManager
    
    let onRename: (URL) -> Void
    let onUpload: (URL) -> Void
    let onDelete: (IndexSet) -> Void
    
    var body: some View {
        List {
            ForEach(recordings, id: \.self) { url in
                let filename = url.lastPathComponent
                let metadata = metadataStore[filename]
                
                NavigationLink(
                    destination: RecordingDetailView(
                        filename: filename,
                        metadata: metadata
                    )
                ) {
                    RecordingRow(
                        url: url,
                        metadata: metadata,
                        audioManager: audioManager,
                        onRename: { onRename(url) },
                        onUpload: { onUpload(url) }
                    )
                }
            }
            .onDelete(perform: onDelete)
        }
        .listStyle(InsetGroupedListStyle())
    }
}

// MARK: - Recording Row
struct RecordingRow: View {
    let url: URL
    let metadata: RecordingMetadata?
    @ObservedObject var audioManager: AudioPlaybackManager
    
    let onRename: () -> Void
    let onUpload: () -> Void
    
    @State private var isUploading = false
    
    private var isPlaying: Bool {
        audioManager.currentURL == url && audioManager.isPlaying
    }
    
    private var isCurrentRow: Bool {
        audioManager.currentURL == url
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(url.deletingPathExtension().lastPathComponent)
                        .font(.headline)
                    Text(isCurrentRow ? formatTime(audioManager.duration) : "--:--")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Upload Button
                if metadata?.isUploaded != true {
                    Button(action: {
                        isUploading = true
                        onUpload()
                        // Reset after delay (upload handles actual state)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isUploading = false
                        }
                    }) {
                        if isUploading {
                            ProgressView()
                                .tint(.blue)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                
                // Rename Button
                Button(action: onRename) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                // Play/Pause Button
                Button(action: { audioManager.togglePlayback(for: url) }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(
                            Circle().fill(isPlaying ? Color.orange : Color.blue)
                        )
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            // Seek Bar (only for current playing/paused recording)
            if isCurrentRow {
                VStack(spacing: 6) {
                    Slider(
                        value: Binding(
                            get: { audioManager.currentTime },
                            set: { audioManager.seek(to: $0) }
                        ),
                        in: 0...max(audioManager.duration, 0.1)
                    )
                    
                    HStack {
                        Text(formatTime(audioManager.currentTime))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(audioManager.duration))
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
