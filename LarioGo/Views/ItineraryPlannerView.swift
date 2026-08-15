//
//  ItineraryPlannerView.swift
//  LarioGo
//

import LarioCore
import MapKit
import SwiftUI

struct ItineraryPlannerView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject var model: ItineraryViewModel
    @State private var showingNewTrip = false
    @State private var newTripName = ""

    var body: some View {
        Group {
            if model.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(model.trips) { trip in
                        NavigationLink {
                            TripDetailView(tripID: trip.id, model: model)
                        } label: {
                            TripRow(trip: trip, unresolved: model.unresolvedCount(trip))
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { model.delete(model.trips[index]) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Theme.sand)
        .navigationTitle("Trips")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptics.tap()
                    newTripName = ""
                    showingNewTrip = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New trip")
            }
        }
        .task { await model.resolveMissingPlaces() }
        .alert("New trip", isPresented: $showingNewTrip) {
            TextField("Trip name", text: $newTripName)
            Button("Create") { model.createTrip(named: newTripName) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Give it a name — you can change it later.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 46))
                .foregroundStyle(Theme.teal.opacity(0.45))
            Text("No trips yet")
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
            Text("Build a day-by-day plan. Trips are stored on this device and work offline.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
            Button {
                Haptics.tap()
                newTripName = ""
                showingNewTrip = true
            } label: {
                Text("Create a trip")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.lakeGradient, in: .capsule)
            }
            .buttonStyle(.pressableScale(0.95))
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TripRow: View {
    let trip: Itinerary
    let unresolved: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.name)
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
            HStack(spacing: 8) {
                Text("\(trip.stops.count) stop\(trip.stops.count == 1 ? "" : "s")")
                if !trip.days.isEmpty {
                    Text("· \(trip.days.count) day\(trip.days.count == 1 ? "" : "s")")
                }
            }
            .font(.caption)
            .foregroundStyle(Color.inkSecondary)

            // Says which stops could not be loaded rather than quietly showing
            // fewer than the user saved.
            if unresolved > 0 {
                Label("\(unresolved) stop\(unresolved == 1 ? "" : "s") not loaded yet",
                      systemImage: "arrow.clockwise")
                    .font(.caption2)
                    .foregroundStyle(Theme.coral)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Trip detail

struct TripDetailView: View {
    let tripID: UUID
    @ObservedObject var model: ItineraryViewModel
    @State private var isEditing = false

    private var trip: Itinerary? { model.trip(id: tripID) }

    var body: some View {
        Group {
            if let trip {
                if trip.isEmpty {
                    emptyState
                } else {
                    content(trip)
                }
            } else {
                // The trip was deleted while this screen was open.
                Text("This trip no longer exists.")
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.sand)
        .navigationTitle(trip?.name ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let trip, !trip.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
        .task { await model.resolveMissingPlaces() }
    }

    private func content(_ trip: Itinerary) -> some View {
        List {
            ForEach(model.resolved(trip)) { day in
                Section {
                    ForEach(day.entries, id: \.stop.id) { entry in
                        StopRow(stop: entry.stop, place: entry.place)
                    }
                    .onDelete { offsets in
                        for index in offsets where index < day.entries.count {
                            model.removeStop(day.entries[index].stop, from: tripID)
                        }
                    }
                    .onMove { source, destination in
                        model.move(in: tripID, on: day.day, from: source, to: destination)
                    }
                } header: {
                    Text(dayTitle(day.day))
                }
            }

            if let mapDay = model.resolved(trip).first, !mapDay.entries.isEmpty {
                Section("Day map") {
                    TripMap(places: mapDay.entries.map(\.place))
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func dayTitle(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: day)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 42))
                .foregroundStyle(Theme.teal.opacity(0.45))
            Text("Nothing planned yet")
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
            Text("Open any place and tap \"Add to trip\".")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct StopRow: View {
    let stop: ItineraryStop
    let place: Place

    var body: some View {
        HStack(spacing: 12) {
            SiteImage(imageName: place.primaryImageName ?? "", symbol: place.category.symbol)
                .frame(width: 54, height: 54)
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Text(place.category.displayName)
                    .font(.caption)
                    .foregroundStyle(Theme.teal)
                if let note = stop.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct TripMap: View {
    let places: [Place]

    var body: some View {
        Map(initialPosition: .region(region)) {
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                Annotation(
                    "\(index + 1). \(place.name)",
                    coordinate: place.coordinate.clCoordinate
                ) {
                    ZStack {
                        Circle().fill(Theme.lakeGradient).frame(width: 28, height: 28)
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Frames every stop, with padding so pins are not flush against the edge.
    private var region: MKCoordinateRegion {
        guard let first = places.first else { return .lakeComo }
        var minLat = first.coordinate.latitude, maxLat = minLat
        var minLon = first.coordinate.longitude, maxLon = minLon
        for place in places {
            minLat = min(minLat, place.coordinate.latitude)
            maxLat = max(maxLat, place.coordinate.latitude)
            minLon = min(minLon, place.coordinate.longitude)
            maxLon = max(maxLon, place.coordinate.longitude)
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.01, (maxLat - minLat) * 1.5),
                longitudeDelta: max(0.01, (maxLon - minLon) * 1.5)
            )
        )
    }
}
