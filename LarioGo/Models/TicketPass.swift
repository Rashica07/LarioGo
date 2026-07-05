//
//  TicketPass.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  TicketPass.swift
//  LarioGo
//

import Foundation

/// A transport / experience pass purchasable through LarioGo.
nonisolated struct TicketPass: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let kind: TicketKind
    let price: Double
    let validity: String
    let highlights: [String]

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        kind: TicketKind,
        price: Double,
        validity: String,
        highlights: [String]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.price = price
        self.validity = validity
        self.highlights = highlights
    }

    var priceString: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "it_IT")
        return f.string(from: NSNumber(value: price)) ?? "€\(price)"
    }
}

nonisolated enum TicketKind: String, CaseIterable, Identifiable, Hashable {
    case boat = "Boat"
    case bus = "Bus"
    case cable = "Funicular"
    case combo = "City Pass"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .boat: return "ferry.fill"
        case .bus: return "bus.fill"
        case .cable: return "cablecar.fill"
        case .combo: return "ticket.fill"
        }
    }
}
