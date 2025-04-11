//
//  MoonAnimationView.swift
//  free ai
//
//  Created by Xavier on 17/12/2024.
//

import AVKit
import SwiftUI

#if os(macOS)
import AppKit
#endif

#if os(iOS) || os(visionOS)
struct PlayerView: UIViewRepresentable {
    var videoName: String

    init(videoName: String) {
        self.videoName = videoName
    }

    func updateUIView(_: UIView, context _: UIViewRepresentableContext<PlayerView>) {}

    func makeUIView(context _: Context) -> UIView {
        return LoopingPlayerUIView(videoName: videoName)
    }
}

class LoopingPlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var player = AVQueuePlayer()

    init(videoName: String) {
        let url = URL(fileURLWithPath: Bundle.main.path(forResource: videoName, ofType: "mp4")!)
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        super.init(frame: .zero)

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)

        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        
        // Prevent other audio from stopping
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        
        player.play()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
#endif

#if os(macOS)
struct PlayerView: NSViewRepresentable {
    var videoName: String
    
    init(videoName: String) {
        self.videoName = videoName
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // No dynamic updates needed for this player
    }
    
    func makeNSView(context: Context) -> NSView {
        return LoopingPlayerNSView(videoName: videoName)
    }
}

class LoopingPlayerNSView: NSView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var player = AVQueuePlayer()
    
    init(videoName: String) {
        // Ensure the video file exists
        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else {
            fatalError("Video file \(videoName).mp4 not found in bundle.")
        }
        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        super.init(frame: .zero)
        
        // Configure the player layer
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        self.wantsLayer = true
        self.layer?.addSublayer(playerLayer)
        
        // Setup looping
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        
        // Start playback
        player.play()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        playerLayer.frame = self.bounds
    }
}
#endif

struct MoonAnimationView: View {
    var isDone: Bool
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.7
    
    var body: some View {
        ZStack {
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                // Modern moon animation
                ZStack {
                    // Base circle
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 64, height: 64)
                    
                    // Revolving dot
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 10, height: 10)
                        .offset(x: 28)
                        .rotationEffect(.degrees(rotation))
                        .opacity(opacity)
                    
                    // Moon gradient overlay
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 64, height: 64)
                        .mask(
                            Circle()
                                .scale(scale)
                        )
                }
                .onAppear {
                    withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        scale = 0.95
                        opacity = 1.0
                    }
                }
            }
        }
        .frame(width: 64, height: 64)
        .animation(.spring(duration: 0.6), value: isDone)
    }
}

#Preview {
    @Previewable @State var done = false
    VStack(spacing: 50) {
        Toggle(isOn: $done, label: { Text("Done") })
        MoonAnimationView(isDone: done)
    }
}
