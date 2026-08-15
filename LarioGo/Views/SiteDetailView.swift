//
//  SiteDetailView.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  SiteDetailView.swift
//  LarioGo
//

import SwiftUI
import MapKit

struct SiteDetailView: View {
    let site: Site
    @Environment(\.dismiss) private var dismiss

    @State private var showBookButton: Bool = false
    @State private var showBooking: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    parallaxHeader
                    content
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Theme.sand)

            bookBar
        }
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .topLeading) { backButton }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.25)) {
                showBookButton = true
            }
        }
        .sheet(isPresented: $showBooking) {
            ExperienceBookingSheet(site: site)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    /// Stretchy parallax hero image.
    private var parallaxHeader: some View {
        GeometryReader { proxy in
            let offset = proxy.frame(in: .global).minY
            let height: CGFloat = 360
            SiteImage(imageName: site.imageName, symbol: site.category.symbol)
                .frame(width: proxy.size.width, height: offset > 0 ? height + offset : height)
                .clipped()
                .overlay {
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 8) {
                        CategoryTag(category: site.category)
                        Text(site.name)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text(site.tagline)
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(20)
                }
                .offset(y: offset > 0 ? -offset : 0)
        }
        .frame(height: 360)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 22) {
                stat(value: String(format: "%.1f", site.rating), label: "Rating", symbol: "star.fill")
                stat(value: site.visitDuration, label: "Duration", symbol: "clock.fill")
                stat(value: site.category.rawValue, label: "Type", symbol: site.category.symbol)
            }
            
            AudioGuidePlayer(textToSpeak: site.about, siteName: site.name)

            VStack(alignment: .leading, spacing: 8) {
                Text("About").font(.title3.bold()).foregroundStyle(Color.inkPrimary)
                Text(site.about)
                    .font(.body)
                    .foregroundStyle(Color.inkSecondary)
                    .lineSpacing(4)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Location").font(.title3.bold()).foregroundStyle(Color.inkPrimary)
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: site.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))) {
                    Annotation(site.name, coordinate: site.coordinate) {
                        // MapPin now takes a symbol rather than a Site, so it
                        // can serve both the legacy Site screens and Place.
                        MapPin(symbol: site.category.symbol, isSelected: true)
                    }
                }
                .frame(height: 180)
                .clipShape(.rect(cornerRadius: Theme.Radius.card))
                .allowsHitTesting(false)
            }
        }
        .padding(20)
        .padding(.bottom, 100)
    }

    private func stat(value: String, label: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(Theme.teal)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white, in: .rect(cornerRadius: Theme.Radius.chip))
        .shadow(color: Theme.azure.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.headline.bold())
                .foregroundStyle(Theme.azure)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: .circle)
        }
        .buttonStyle(.pressableScale(0.88))
        .padding(.leading, 16)
        .padding(.top, 56)
    }

    /// Floating "Book Now" bar that springs up on appear.
    private var bookBar: some View {
        Button {
            Haptics.tap()
            showBooking = true
        } label: {
            HStack {
                Image(systemName: "calendar.badge.plus")
                Text("Book Now")
                Spacer()
                Text("Plan your visit")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(Theme.lakeGradient, in: .capsule)
            .shadow(color: Theme.azure.opacity(0.4), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.pressableScale(0.96))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .offset(y: showBookButton ? 0 : 140)
        .opacity(showBookButton ? 1 : 0)
    }
}

/// Lightweight experience booking confirmation for a site visit.
struct ExperienceBookingSheet: View {
    let site: Site
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan your visit")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.azure)
                Text(site.name)
                    .font(.headline)
                    .foregroundStyle(Color.inkSecondary)
            }
            DatePicker("Visit date", selection: $date, in: Date()..., displayedComponents: .date)
                .tint(Theme.teal)
                .font(.headline)
            Spacer()
            Button {
                Haptics.success()
                ItineraryManager.shared.add(siteID: site.id, date: date)
                dismiss()
            } label: {
                Text("Add to my trip")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.lakeGradient, in: .rect(cornerRadius: Theme.Radius.button))
            }
            .buttonStyle(.pressableScale(0.97))
        }
        .padding(24)
    }
}
