//
//  ContentView.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import SwiftUI

struct ContentView: View {
    let events: [TextEvent]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                        TextEventView(event: event)
                        Divider()
                    }
                }
            }
            .onChange(of: events.count) { _, _ in
                if let last = events.indices.last {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

#Preview {
    ContentView(events: [TextEvent("id: 1\nevent: Hello world!\ndata: hello world!")])
}
