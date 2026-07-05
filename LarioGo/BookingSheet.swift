//
//  BookingSheet.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  BookingSheet.swift
//  LarioGo
//

import SwiftUI

struct BookingSheet: View {
    let ticket: TicketPass
    @Environment(\.dismiss) private var dismiss

    @State private var quantity: Int = 1
    @State private var date: Date = Date()
    @State private var confirmed: Bool = false

    private var total: Double { ticket.price * Double(quantity) }
    private var totalString: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "it_IT")
        return f.string(from: NSNumber(value: total)) ?? "€\(total)"
    }

    var body: some View {
        Group {
            if confirmed {
                confirmation
            } else {
                form
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: confirmed)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(ticket.kind.rawValue, systemImage: ticket.kind.symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.teal)
                    Text(ticket.title)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.azure)
                    Text(ticket.validity)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                }

                stepper
                DatePicker("Travel date", selection: $date, in: Date()..., displayedComponents: .date)
                    .font(.headline)
                    .tint(Theme.teal)

                HStack {
                    Text("Total")
                        .font(.headline)
                        .foregroundStyle(Color.inkSecondary)
                    Spacer()
                    Text(totalString)
                        .font(.title.bold())
                        .foregroundStyle(Theme.azure)
                }
                .padding(.top, 4)

                Button {
                    Haptics.success()
                    confirmed = true
                } label: {
                    Text("Confirm Booking")
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

    private var stepper: some View {
        HStack {
            Text("Travellers")
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            HStack(spacing: 18) {
                stepButton(symbol: "minus") { if quantity > 1 { quantity -= 1; Haptics.selection() } }
                Text("\(quantity)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(Theme.azure)
                    .frame(minWidth: 28)
                stepButton(symbol: "plus") { if quantity < 10 { quantity += 1; Haptics.selection() } }
            }
        }
    }

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline.bold())
                .foregroundStyle(Theme.teal)
                .frame(width: 40, height: 40)
                .background(Theme.teal.opacity(0.12), in: .circle)
        }
        .buttonStyle(.pressableScale(0.85))
    }

    private var confirmation: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Theme.teal.opacity(0.15)).frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(Theme.teal)
            }
            Text("Booking Confirmed")
                .font(.title.bold())
                .foregroundStyle(Theme.azure)
            Text("\(quantity) × \(ticket.title)\nYour pass is ready in Profile › My Tickets.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
                .padding(.horizontal, 30)
            Spacer()
            Button { dismiss() } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.lakeGradient, in: .rect(cornerRadius: Theme.Radius.button))
            }
            .buttonStyle(.pressableScale(0.97))
            .padding(24)
        }
    }
}
