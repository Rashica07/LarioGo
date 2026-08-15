//
//  AttributionView.swift
//  LarioGo
//
//  Data attribution.
//
//  This is a licence obligation, not a courtesy. Place data comes from
//  OpenStreetMap under the Open Database Licence, which permits commercial use
//  and requires that contributors are credited wherever the data is shown.
//  Removing this would put the app out of compliance.
//

import LarioCore
import SwiftUI

/// Compact credit line for screens that display imported place data.
struct AttributionFootnote: View {
    var body: some View {
        Text("Place data © OpenStreetMap contributors")
            .font(.caption2)
            .foregroundStyle(Color.inkSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .accessibilityLabel("Place data copyright OpenStreetMap contributors")
    }
}

/// Full credits screen, reachable from Profile.
struct AttributionView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("OpenStreetMap")
                        .font(.headline)
                        .foregroundStyle(Color.inkPrimary)
                    Text("Attractions, restaurants and points of interest around Lecco and Lake Como come from OpenStreetMap, a map built by contributors around the world.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                    Text("© OpenStreetMap contributors · ODbL 1.0")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.teal)
                    Link("openstreetmap.org/copyright",
                         destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                        .font(.caption)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Place data")
            }

            Section {
                Text("Ratings and reviews in LarioGo come only from LarioGo users. We do not import or display ratings collected by other services.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            } header: {
                Text("Ratings")
            } footer: {
                Text("A place with no rating is shown as “New” rather than scored, so an unrated place is never mistaken for a badly rated one.")
            }

            Section {
                Text("Maps are rendered by Apple Maps.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            } header: {
                Text("Maps")
            }
        }
        .navigationTitle("Data & credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AttributionView() }
}
