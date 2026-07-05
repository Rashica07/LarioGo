//
//  ARViewfinder.swift
//  LarioGo
//
//  Created by Antigravity on 5.7.26.
//

import SwiftUI
import CoreLocation
import CoreMotion
import AVFoundation

struct ARViewfinder: View {
    @Environment(\.dismiss) private var dismiss
    
    // Core Location & Motion for Heading
    @StateObject private var headingManager = ARHeadingManager()
    
    // Available Sites
    private let sites = TourismData.sites
    
    // Bearing calculation and list of visible site overlays
    private var visibleOverlays: [ARSiteOverlay] {
        guard let currentHeading = headingManager.heading else {
            // Simulator mockup: return mock location heading
            return calculateOverlays(forHeading: mockHeading)
        }
        return calculateOverlays(forHeading: currentHeading)
    }
    
    // Mock Heading for Simulator testing
    @State private var mockHeading: Double = 0.0
    @State private var isSimulating = false
    
    var body: some View {
        ZStack {
            // Camera feed background or fallbacks
            ARCameraView()
                .ignoresSafeArea()
            
            // Panoramic Simulated Grid if running on Simulator without actual compass
            if !headingManager.hasSensors {
                Color.black.opacity(0.4).ignoresSafeArea()
                
                // Allow user to swipe left/right to pan simulated heading
                Color.clear
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let delta = Double(-value.translation.width / 5.0)
                                mockHeading = (mockHeading + delta).truncatingRemainder(dividingBy: 360.0)
                                if mockHeading < 0 { mockHeading += 360.0 }
                            }
                    )
            }
            
            // Viewfinder Target Reticle
            VStack {
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 32, weight: .thin))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
            
            // Site HUD Overlays
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                
                ZStack {
                    ForEach(visibleOverlays) { overlay in
                        let xPos = calculateXPosition(bearing: overlay.bearing, currentHeading: headingManager.heading ?? mockHeading, screenWidth: width)
                        
                        if xPos > -100 && xPos < width + 100 {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                                    
                                    HStack(spacing: 10) {
                                        Image(systemName: overlay.site.category.symbol)
                                            .foregroundStyle(Theme.teal)
                                            .font(.headline)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(overlay.site.name)
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.white)
                                            
                                            Text(String(format: "Bearing: %.0f°", overlay.bearing))
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.8))
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                }
                                .frame(width: 190, height: 50)
                                
                                // Vertical alignment line pointing down
                                Rectangle()
                                    .fill(.white.opacity(0.5))
                                    .frame(width: 2, height: 60)
                            }
                            .position(x: xPos, y: height / 2.0 + CGFloat(overlay.verticalOffset))
                            .transition(.opacity)
                        }
                    }
                }
            }
            
            // Compass Tape at the top
            VStack {
                HStack {
                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.5), in: .circle)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("AR LANDMARK SCANNER")
                            .font(.caption.bold())
                            .tracking(2)
                            .foregroundStyle(Theme.teal)
                        
                        Text(String(format: "HEADING: %.0f°", headingManager.heading ?? mockHeading))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.5), in: .rect(cornerRadius: 12))
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // Empty space to balance close button
                    Spacer().frame(width: 48)
                }
                
                Spacer()
                
                if !headingManager.hasSensors {
                    Text("Simulator Mode: Drag left/right to pan direction")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 24)
                }
            }
        }
        .statusBarHidden(true)
        .onAppear {
            headingManager.start()
        }
        .onDisappear {
            headingManager.stop()
        }
    }
    
    // Calculates horizontal X placement based on bearing offset from current heading
    private func calculateXPosition(bearing: Double, currentHeading: Double, screenWidth: CGFloat) -> CGFloat {
        var diff = bearing - currentHeading
        if diff > 180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        
        // Let field of view (FOV) be roughly 60 degrees total
        let fov: Double = 60.0
        let screenPercent = diff / (fov / 2.0)
        
        return (screenWidth / 2.0) + CGFloat(screenPercent) * (screenWidth / 2.0)
    }
    
    // Calculates mock bearing offsets for each site in the database
    private func calculateOverlays(forHeading heading: Double) -> [ARSiteOverlay] {
        // Generate pseudo-fixed bearings for our landmarks so they appear pinned to locations
        // In production, we'd use true GPS coordinates, but pseudo-bearings are robust for demoing.
        var overlays: [ARSiteOverlay] = []
        var offsetCount = 0
        
        for site in sites {
            // Generate a bearing from 0 to 360 based on site coordinates or properties
            let pseudoBearing = abs(site.latitude * 100).truncatingRemainder(dividingBy: 360.0)
            
            // Apply slight vertical offset spacing so cards don't overlap vertically
            let pseudoVerticalOffset = -80 + (offsetCount * 45)
            offsetCount = (offsetCount + 1) % 3
            
            overlays.append(
                ARSiteOverlay(
                    site: site,
                    bearing: pseudoBearing,
                    verticalOffset: pseudoVerticalOffset
                )
            )
        }
        
        return overlays
    }
}

struct ARSiteOverlay: Identifiable {
    let id = UUID()
    let site: Site
    let bearing: Double
    let verticalOffset: Int
}

class ARHeadingManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var heading: Double? = nil
    @Published var hasSensors = false
    
    func start() {
        locationManager.delegate = self
        if CLLocationManager.headingAvailable() {
            hasSensors = true
            locationManager.startUpdatingHeading()
        } else {
            hasSensors = false
        }
    }
    
    func stop() {
        locationManager.stopUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Smooth out updates
        self.heading = newHeading.magneticHeading
    }
}

// Camera Feed View using UIKit representation
struct ARCameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ARCameraController {
        return ARCameraController()
    }
    
    func updateUIViewController(_ uiViewController: ARCameraController, context: Context) {}
}

class ARCameraController: UIViewController {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            // Add a beautiful placeholder for simulators
            setupSimulatorBackground()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        self.previewLayer = preview
        self.captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    private func setupSimulatorBackground() {
        let gradientView = UIView(frame: view.bounds)
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds
        gradientLayer.colors = [
            UIColor(red: 0x00 / 255.0, green: 0x3B / 255.0, blue: 0x4D / 255.0, alpha: 1.0).cgColor,
            UIColor(red: 0x25 / 255.0, green: 0xA1 / 255.0, blue: 0x8E / 255.0, alpha: 1.0).cgColor
        ]
        gradientView.layer.addSublayer(gradientLayer)
        view.addSubview(gradientView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
}
