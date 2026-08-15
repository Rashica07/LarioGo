//
//  DataSourceSettingsView.swift
//  LarioGo
//
//  In-app switch between mock content and the live API, plus controls for
//  forcing the loading, empty and error states.
//
//  This screen is a deliberate, retained feature — not debug scaffolding to be
//  removed once the API works. It stays until v1.0 ships with licensed content
//  and signed sponsors, because demos, screenshots, offline development and
//  QA of failure paths all depend on it.
//

import LarioCore
import SwiftUI

struct DataSourceSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        List {
            if let error = environment.configurationError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.coral)
                } header: {
                    Text("Configuration problem")
                }
            }

            Section {
                ForEach(DataSourceMode.allCases, id: \.self) { mode in
                    Button {
                        Haptics.selection()
                        environment.setDataSource(mode)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(mode.displayName)
                                    .foregroundStyle(Color.inkPrimary)
                                Text(description(for: mode))
                                    .font(.caption)
                                    .foregroundStyle(Color.inkSecondary)
                            }
                            Spacer()
                            if environment.configuration.dataSource == mode {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.teal)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Content source")
            } footer: {
                Text("Switching source signs you out — a mock account has no meaning to the live API, and the reverse is also true.")
            }

            if environment.configuration.dataSource != .live {
                Section {
                    behaviourButton("Instant", .immediate, "No delay. Fastest for clicking through.")
                    behaviourButton("Realistic", .realistic, "Adds a short delay so loading states are visible.")
                    behaviourButton("Unreliable", .unreliable, "Fails about a third of requests, for testing retries.")
                    behaviourButton("Always offline", .alwaysOffline, "Every request fails. Exercises error states.")
                    behaviourButton("No results", .empty, "Returns nothing. Exercises empty states.")
                } header: {
                    Text("Mock behaviour")
                } footer: {
                    Text("Loading, empty and error states are the ones that rot unnoticed. These force them on demand.")
                }
            }

            Section {
                LabeledContent("Places", value: "\(MockCatalog.places.count)")
                LabeledContent("Test profiles", value: "\(MockCatalog.profiles.count)")
                if environment.mustLabelSampleContent {
                    Label(
                        "Dining, events and experiences are invented sample data and are labelled as such.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                }
            } header: {
                Text("Mock catalogue")
            }
        }
        .navigationTitle("Data Source")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func behaviourButton(_ title: String, _ behaviour: MockBehaviour, _ detail: String) -> some View {
        Button {
            Haptics.selection()
            environment.setMockBehaviour(behaviour)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).foregroundStyle(Color.inkPrimary)
                    Text(detail).font(.caption).foregroundStyle(Color.inkSecondary)
                }
                Spacer()
                if environment.configuration.mockBehaviour == behaviour {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.teal)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func description(for mode: DataSourceMode) -> String {
        switch mode {
        case .mock:
            return "Bundled catalogue. No network at all."
        case .live:
            return "The real backend. The only mode serving verified content."
        case .liveWithMockFallback:
            return "Live, dropping to mock when unreachable. Never use for release."
        }
    }
}

/// Badge shown on any card or detail view rendering invented content.
///
/// The rule this enforces: sample data must never be mistaken for a real,
/// verified listing.
struct SampleContentBadge: View {
    var body: some View {
        Label("Sample data", systemImage: "flask.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.coral.opacity(0.92), in: .capsule)
            .accessibilityLabel("Sample data, not a real listing")
    }
}

#Preview {
    NavigationStack {
        DataSourceSettingsView()
            .environmentObject(AppEnvironment(
                configuration: .testing,
                sessionStore: InMemorySessionStore()
            ))
    }
}
