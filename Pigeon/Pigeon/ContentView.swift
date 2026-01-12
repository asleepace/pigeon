//
//  ContentView.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var streamManager: StreamManager
    @State private var selectedStream: StreamConnection? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedStream: $selectedStream)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            if let stream = selectedStream {
                TextEventListView(stream: stream)
            } else {
                ContentUnavailableView(
                    "No Stream Selected",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Select or add a stream from the sidebar")
                )
            }
        }
        .frame(minWidth: 700, minHeight: 400)
    }
}
