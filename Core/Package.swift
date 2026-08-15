// swift-tools-version:5.9
import PackageDescription

// LarioCore holds every piece of LarioGo that does NOT need an Apple framework:
// domain models, geo maths, search, filtering, ranking, itinerary rules.
//
// The point is testability. The iOS app cannot be compiled on the Windows
// development machine (SwiftUI/MapKit are Apple-only) and the Vapor backend
// cannot either (no Windows support). Foundation-only code CAN be, so the
// logic most likely to contain real bugs lives here and is actually executed
// on every change instead of waiting for a CI runner.
//
// Rules for this target:
//   - import Foundation only. No SwiftUI, UIKit, MapKit, CoreLocation, Vapor.
//   - no I/O, no singletons, no global mutable state.
//   - deterministic: any "now" or "here" is a parameter, never ambient.
let package = Package(
    name: "LarioCore",
    products: [
        .library(name: "LarioCore", targets: ["LarioCore"]),
    ],
    targets: [
        .target(name: "LarioCore"),
        .testTarget(name: "LarioCoreTests", dependencies: ["LarioCore"]),
    ]
)
