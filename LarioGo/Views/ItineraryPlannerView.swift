//
//  ItineraryPlannerView.swift
//  LarioGo
//
//  Created by Antigravity on 5.7.26.
//

import SwiftUI

struct ItineraryPlannerView: View {
    @StateObject private var itinerary = ItineraryManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private let sites = TourismData.sites
    
    // Grouping itinerary items by Day (represented as localized date string)
    private var groupedItems: [(Date, [ItineraryItem])] {
        let dictionary = Dictionary(grouping: itinerary.items) { item in
            Calendar.current.startOfDay(for: item.date)
        }
        return dictionary.sorted { $0.key < $1.key }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Trip Planner")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Theme.azure)
                        Text("Your customized Lake Como itinerary.")
                            .font(.body)
                            .foregroundStyle(Color.inkSecondary)
                    }
                    Spacer()
                    
                    if !itinerary.items.isEmpty {
                        Button {
                            Haptics.selection()
                            itinerary.clear()
                        } label: {
                            Text("Clear")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                if itinerary.items.isEmpty {
                    emptyState
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 24) {
                        ForEach(groupedItems, id: \.0) { date, items in
                            VStack(alignment: .leading, spacing: 12) {
                                // Day Header
                                Text(formatDayHeader(date))
                                    .font(.headline)
                                    .foregroundStyle(Theme.teal)
                                    .padding(.horizontal, 20)
                                
                                ForEach(items) { item in
                                    if let site = sites.first(where: { $0.id == item.siteID }) {
                                        ItineraryRow(item: item, site: site) {
                                            itinerary.remove(itemID: item.id)
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.sand)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(Theme.teal.opacity(0.4))
            
            Text("No plans yet")
                .font(.title3.bold())
                .foregroundStyle(Color.inkPrimary)
            
            Text("Add sites or landmarks from the Explore view to construct your own custom itinerary.")
                .font(.body)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatDayHeader(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
}

struct ItineraryRow: View {
    let item: ItineraryItem
    let site: Site
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            SiteImage(imageName: site.imageName, symbol: site.category.symbol)
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(site.name)
                    .font(.headline)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                
                Text(site.tagline)
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
                
                Label(formatTime(item.date), systemImage: "clock")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.teal)
            }
            
            Spacer()
            
            Button {
                Haptics.tap()
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(Color.red.opacity(0.08), in: .circle)
            }
            .buttonStyle(.pressableScale(0.85))
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .shadow(color: Theme.azure.opacity(0.06), radius: 8, x: 0, y: 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}
