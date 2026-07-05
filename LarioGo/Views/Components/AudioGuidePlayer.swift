//
//  AudioGuidePlayer.swift
//  LarioGo
//
//  Created by Antigravity on 5.7.26.
//

import SwiftUI
import AVFoundation

struct AudioGuidePlayer: View {
    let textToSpeak: String
    let siteName: String
    
    @StateObject private var speaker = SpeechManager.shared
    @State private var showingPlaybackSpeed = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Play / Pause button
                Button {
                    Haptics.tap()
                    if speaker.isPlaying && speaker.currentText == textToSpeak {
                        speaker.pause()
                    } else {
                        speaker.speak(textToSpeak, title: siteName)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.lakeGradient)
                            .frame(width: 58, height: 58)
                            .shadow(color: Theme.teal.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: (speaker.isPlaying && speaker.currentText == textToSpeak) ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .offset(x: (speaker.isPlaying && speaker.currentText == textToSpeak) ? 0 : 2)
                    }
                }
                .buttonStyle(.pressableScale(0.92))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(speaker.currentText == textToSpeak ? "Now Playing" : "Audio Guide Available")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.teal)
                    
                    Text(siteName)
                        .font(.headline)
                        .foregroundStyle(Color.inkPrimary)
                }
                
                Spacer()
                
                // Speed Controller
                Button {
                    Haptics.selection()
                    showingPlaybackSpeed.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                        Text(String(format: "%.2fx", speaker.rateMultiplier))
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.azure)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.azure.opacity(0.08), in: .capsule)
                }
                .sheet(isPresented: $showingPlaybackSpeed) {
                    SpeedSelectorSheet()
                        .presentationDetents([.fraction(0.3)])
                        .presentationDragIndicator(.visible)
                }
            }
            .padding(14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .shadow(color: Theme.azure.opacity(0.08), radius: 10, x: 0, y: 5)
            
            if speaker.isPlaying && speaker.currentText == textToSpeak {
                HStack {
                    Spacer()
                    Text("Narrating guide...")
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .italic()
                    Spacer()
                }
                .padding(.top, -8)
            }
        }
    }
}

class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isPlaying = false
    @Published var currentText = ""
    @Published var rateMultiplier: Float = 1.0 {
        didSet {
            if isPlaying {
                // Restart with new rate if playing
                let text = currentText
                let title = currentTitle
                stop()
                speak(text, title: title)
            }
        }
    }
    
    private var currentTitle = ""
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(_ text: String, title: String) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
        }
        
        currentText = text
        currentTitle = title
        
        let utterance = AVSpeechUtterance(string: text)
        // Set speech language to Italian if it's Italian or default to English
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        // Base rate is roughly 0.5. Adjust with multiplier
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * rateMultiplier
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
        isPlaying = true
    }
    
    func pause() {
        synthesizer.pauseSpeaking(at: .immediate)
        isPlaying = false
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        currentText = ""
        currentTitle = ""
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isPlaying = false
        currentText = ""
        currentTitle = ""
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isPlaying = false
        currentText = ""
        currentTitle = ""
    }
}

struct SpeedSelectorSheet: View {
    @StateObject private var speaker = SpeechManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Playback Speed")
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
                .padding(.top, 16)
            
            HStack(spacing: 12) {
                ForEach(speeds, id: \.self) { speed in
                    Button {
                        Haptics.selection()
                        speaker.rateMultiplier = speed
                        dismiss()
                    } label: {
                        Text(String(format: "%.2fx", speed))
                            .font(.subheadline.bold())
                            .foregroundStyle(speaker.rateMultiplier == speed ? .white : Theme.azure)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(speaker.rateMultiplier == speed ? AnyShapeStyle(Theme.lakeGradient) : AnyShapeStyle(Theme.azure.opacity(0.08)))
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
}
