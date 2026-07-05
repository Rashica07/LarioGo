//
//  MapTabView.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  MapTabView.swift
//  LarioGo
//

import SwiftUI
import MapKit

struct MapTabView: View {
    let onSelectSite: (Site) -> Void

    private let sites = TourismData.sites
    @State private var selectedSiteID: Site.ID? = nil
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.92, longitude: 9.36),
            span: MKCoordinateSpan(latitudeDelta: 0.55, longitudeDelta: 0.55)
        )
    )

    private var selectedSite: Site? {
        sites.first { $0.id == selectedSiteID }
    }

    var body: some View {
        Map(position: $cameraPosition, selection: $selectedSiteID) {
            ForEach(sites) { site in
                Annotation(site.name, coordinate: site.coordinate, anchor: .bottom) {
                    MapPin(site: site, isSelected: site.id == selectedSiteID)
                        .onTapGesture {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                selectedSiteID = site.id
                            }
                        }
                }
                .tag(site.id)
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) { titleBar }
        .overlay(alignment: .bottom) {
            if let selectedSite {
                MapPreviewCard(site: selectedSite) { onSelectSite(selectedSite) }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(selectedSite.id)
            }
        }
    }

    private var titleBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "map.fill").foregroundStyle(Theme.teal)
            Text("Explore the Map")
                .font(.headline)
                .foregroundStyle(Theme.azure)
            Spacer()
            Text("\(sites.count) places")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

/// High-contrast custom map pin.
struct MapPin: View {
    let site: Site
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isSelected ? AnyShapeStyle(Theme.coral) : AnyShapeStyle(Theme.lakeGradient))
                    .frame(width: isSelected ? 46 : 38, height: isSelected ? 46 : 38)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                Image(systemName: site.category.symbol)
                    .font(.system(size: isSelected ? 20 : 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(Circle().stroke(.white, lineWidth: 3))
            Triangle()
                .fill(isSelected ? Theme.coral : Theme.teal)
                .frame(width: 14, height: 9)
                .offset(y: -1)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isSelected)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// Compact card surfaced when a pin is selected.
struct MapPreviewCard: View {
    let site: Site
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                SiteImage(imageName: site.imageName, symbol: site.category.symbol)
                    .frame(width: 70, height: 70)
                    .clipShape(.rect(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(site.name)
                        .font(.headline)
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                    Text(site.tagline)
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(2)
                    Label(String(format: "%.1f", site.rating), systemImage: "star.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.teal)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.teal)
            }
            .padding(12)
            .background(.white, in: .rect(cornerRadius: Theme.Radius.card))
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.pressableScale(0.97))
    }
}
