//
//  LarioGoApp.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  LarioGoApp.swift
//  LarioGo
//

import SwiftUI

@main
struct LarioGoApp: App {
    @State private var isReady = false

    /// The composition root. Built once here and injected, so nothing further
    /// down ever constructs a service or decides between mock and live.
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(
                    favorites: FavoritesViewModel(
                        persistence: UserDefaultsFavoritesPersistence(),
                        placeService: environment.placeService
                    )
                )
                .environmentObject(environment)

                if !isReady {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.easeOut(duration: 0.5)) { isReady = true }
            }
        }
    }
}

/// Branded launch screen echoing the lake-inspired identity.
struct SplashView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Theme.deepGradient.ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 130, height: 130)
                        .scaleEffect(animate ? 1.1 : 0.8)
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(spacing: 4) {
                    Text("LarioGo")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Lecco · Lake Como")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .opacity(animate ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) { animate = true }
        }
    }
}
