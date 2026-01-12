//
//  AddStreamSheet.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import SwiftUI

struct AddStreamSheet: View {
    @Binding var name: String
    @Binding var url: String
    var onAdd: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Stream")
                .font(.headline)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("URL", text: $url)
                .textFieldStyle(.roundedBorder)

            buttonRow
        }
        .padding()
        .frame(width: 300)
    }

    private var buttonRow: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Add", action: onAdd)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || url.isEmpty)
        }
    }
}
