//
//  ProfileView.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  ProfileView.swift
//  LarioGo
//

import SwiftUI

struct ProfileView: View {
    @State private var language: String = "English"
    @State private var largeText: Bool = false
    @State private var notifications: Bool = true

    private let languages = ["English", "Italiano", "Deutsch", "Français"]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                profileHeader

                card(title: "My Trip") {
                    row(symbol: "ticket.fill", title: "My Tickets", trailing: "2 active")
                    Divider().padding(.leading, 52)
                    row(symbol: "heart.fill", title: "Saved Places", trailing: "5")
                    Divider().padding(.leading, 52)
                    NavigationLink {
                        ItineraryPlannerView()
                    } label: {
                        row(symbol: "calendar", title: "Itinerary", trailing: nil)
                    }
                    .buttonStyle(.plain)
                }

                card(title: "Preferences") {
                    HStack {
                        icon("globe")
                        Text("Language").font(.body).foregroundStyle(Color.inkPrimary)
                        Spacer()
                        Picker("Language", selection: $language) {
                            ForEach(languages, id: \.self) { Text($0) }
                        }
                        .tint(Theme.teal)
                        .onChange(of: language) { _, _ in Haptics.selection() }
                    }
                    .padding(.vertical, 4)
                    Divider().padding(.leading, 52)
                    toggleRow(symbol: "textformat.size", title: "Larger Text", isOn: $largeText)
                    Divider().padding(.leading, 52)
                    toggleRow(symbol: "bell.fill", title: "Event Notifications", isOn: $notifications)
                }

                card(title: "Lecco Tourism") {
                    row(symbol: "info.circle.fill", title: "Visitor Information", trailing: nil)
                    Divider().padding(.leading, 52)
                    row(symbol: "phone.fill", title: "Emergency & Help", trailing: nil)
                    Divider().padding(.leading, 52)
                    row(symbol: "checkmark.seal.fill", title: "Official City Service", trailing: nil)
                }

                Text("LarioGo · Official guide to Lecco & Lake Como\nVersion 1.0 (MVP)")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .dynamicTypeSize(largeText ? .accessibility1 : .large)
        }
        .background(Theme.sand)
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.lakeGradient).frame(width: 96, height: 96)
                Text("AT")
                    .font(.title.bold())
                    .foregroundStyle(.white)
            }
            .shadow(color: Theme.azure.opacity(0.3), radius: 10, x: 0, y: 6)
            VStack(spacing: 2) {
                Text("Alpine Traveller")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.azure)
                Text("Exploring Lake Como")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.white, in: .rect(cornerRadius: Theme.Radius.card))
        .shadow(color: Theme.azure.opacity(0.08), radius: 10, x: 0, y: 5)
    }

    @ViewBuilder
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
                .padding(.leading, 4)
            VStack(spacing: 6) { content() }
                .padding(16)
                .background(.white, in: .rect(cornerRadius: Theme.Radius.card))
                .shadow(color: Theme.azure.opacity(0.08), radius: 10, x: 0, y: 5)
        }
    }

    private func row(symbol: String, title: String, trailing: String?) -> some View {
        HStack {
            icon(symbol)
            Text(title).font(.body).foregroundStyle(Color.inkPrimary)
            Spacer()
            if let trailing {
                Text(trailing).font(.subheadline).foregroundStyle(Theme.teal)
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Color.inkSecondary.opacity(0.6))
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func toggleRow(symbol: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            icon(symbol)
            Text(title).font(.body).foregroundStyle(Color.inkPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.teal)
        }
        .padding(.vertical, 2)
    }

    private func icon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.subheadline)
            .foregroundStyle(Theme.teal)
            .frame(width: 36, height: 36)
            .background(Theme.teal.opacity(0.12), in: .rect(cornerRadius: 10))
    }
}
