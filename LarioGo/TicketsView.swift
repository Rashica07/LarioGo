//
//  TicketsView.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  TicketsView.swift
//  LarioGo
//

import SwiftUI

struct TicketsView: View {
    private let tickets = TourismData.tickets
    @State private var selectedKind: TicketKind? = nil
    @State private var bookingTarget: TicketPass? = nil

    private var filtered: [TicketPass] {
        guard let selectedKind else { return tickets }
        return tickets.filter { $0.kind == selectedKind }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                kindFilter
                LazyVStack(spacing: 16) {
                    ForEach(filtered) { ticket in
                        TicketCard(ticket: ticket) { bookingTarget = ticket }
                    }
                }
                .padding(.horizontal, 20)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedKind)
                .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
        .background(Theme.sand)
        .sheet(item: $bookingTarget) { ticket in
            BookingSheet(ticket: ticket)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Travel Passes")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.azure)
            Text("Boats, buses & city passes — book in seconds.")
                .font(.body)
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.horizontal, 20)
    }

    private var kindFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(title: "All", symbol: "square.grid.2x2.fill", isSelected: selectedKind == nil) {
                    Haptics.selection(); selectedKind = nil
                }
                ForEach(TicketKind.allCases) { kind in
                    FilterChip(title: kind.rawValue, symbol: kind.symbol, isSelected: selectedKind == kind) {
                        Haptics.selection()
                        selectedKind = selectedKind == kind ? nil : kind
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollClipDisabled()
    }
}

struct TicketCard: View {
    let ticket: TicketPass
    let onBook: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.lakeGradient)
                        .frame(width: 54, height: 54)
                    Image(systemName: ticket.kind.symbol)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(ticket.title)
                        .font(.headline)
                        .foregroundStyle(Color.inkPrimary)
                    Text(ticket.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                    Text(ticket.validity)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.teal)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(ticket.highlights, id: \.self) { item in
                    Label(item, systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                }
            }

            Divider()

            HStack(alignment: .firstTextBaseline) {
                Text(ticket.priceString)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.azure)
                Text("per person")
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                Spacer()
                Button(action: onBook) {
                    Text("Book Now")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Theme.lakeGradient, in: .capsule)
                }
                .buttonStyle(.pressableScale(0.93))
            }
        }
        .padding(18)
        .background(.white, in: .rect(cornerRadius: Theme.Radius.card))
        .shadow(color: Theme.azure.opacity(0.10), radius: 10, x: 0, y: 5)
    }
}
