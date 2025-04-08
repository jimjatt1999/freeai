//
//  DictationView.swift
//  free ai
//
//  Created by AI Assistant on 5/21/24.
//

import SwiftUI
import Speech

#if os(iOS)
struct DictationView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.dismiss) var dismiss
    
    @State private var isRecording = false
    @State private var transcribedText = ""
    @State private var errorMessage: String?
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    
    var onComplete: (String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Dictate Your Note")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Transcribed text display - now with better styling
                ScrollView {
                    Text(transcribedText.isEmpty ? "Start speaking to see your words appear here..." : transcribedText)
                        .foregroundColor(transcribedText.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.height * 0.4)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Record button - matching Chat style
                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: isRecording ? 34 : 40, height: isRecording ? 34 : 40)
                            .foregroundColor(isRecording ? .red : .blue)
                            .animation(.spring(duration: 0.3), value: isRecording)
                    }
                    .overlay(
                        Circle()
                            .stroke(isRecording ? Color.red : Color.blue, lineWidth: 2)
                            .frame(width: 100, height: 100)
                    )
                }
                .padding(.bottom, 20)
                
                // Action buttons in a row
                HStack(spacing: 16) {
                    // Cancel button
                    Button {
                        if isRecording {
                            stopRecording()
                        }
                        onComplete("")
                    } label: {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray)
                            .cornerRadius(12)
                    }
                    
                    // Use button
                    Button {
                        onComplete(transcribedText)
                    } label: {
                        Text("Use Text")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(transcribedText.isEmpty ? Color.blue.opacity(0.5) : Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(transcribedText.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.vertical)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dictation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        if isRecording {
                            stopRecording()
                        }
                        onComplete("")
                    }
                }
            }
            .onAppear {
                checkPermissions()
            }
            .onDisappear {
                if isRecording {
                    stopRecording()
                }
            }
        }
    }
    
    // Check speech recognition permissions
    private func checkPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.errorMessage = nil
                case .denied:
                    self.errorMessage = "Speech recognition access was denied. Please enable in Settings."
                case .restricted, .notDetermined:
                    self.errorMessage = "Speech recognition is not available."
                @unknown default:
                    self.errorMessage = "Speech recognition authorization is unknown."
                }
            }
        }
    }
    
    // Start recording and transcribing speech - updated to match ChatView
    private func startRecording() {
        // Cancel existing task if it exists
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create an audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Could not set up audio session: \(error.localizedDescription)"
            return
        }
        
        // Set up recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        // Check if audio engine is running and device has recognition capability
        guard let recognitionRequest = recognitionRequest,
              let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available right now"
            return
        }
        
        // Configure request
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.stopRecording()
            }
        }
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            errorMessage = nil
            appManager.playHaptic()
        } catch {
            errorMessage = "Audio engine couldn't start: \(error.localizedDescription)"
            isRecording = false
        }
    }
    
    // Stop recording
    private func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
        }
        
        recognitionTask?.cancel()
        
        // Reset
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
#endif 