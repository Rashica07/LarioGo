//
//  Tab.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  ContentView.swift
//  LarioGo
//

import SwiftUI

enum Tab: Hashable {
    case explore, map, tickets, profile
}

struct ContentView: View {
    @State private var selectedTab: Tab = .explore
    @State private var explorePath = NavigationPath()
    @State private var mapPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $explorePath) {
                ExploreView { site in explorePath.append(site) }
                    .navigationDestination(for: Site.self) { SiteDetailView(site: $0) }
            }
            .tabItem { Label("Explore", systemImage: "sparkles") }
            .tag(Tab.explore)

            NavigationStack(path: $mapPath) {
                MapTabView { site in mapPath.append(site) }
                    .navigationDestination(for: Site.self) { SiteDetailView(site: $0) }
            }
            .tabItem { Label("Map", systemImage: "map.fill") }
            .tag(Tab.map)

            NavigationStack {
                TicketsView()
            }
            .tabItem { Label("Tickets", systemImage: "ticket.fill") }
            .tag(Tab.tickets)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }
            .tag(Tab.profile)
        }
        .tint(Theme.teal)
        .onChange(of: selectedTab) { _, _ in Haptics.selection() }
    }
}

#Preview {
    ContentView()
}
