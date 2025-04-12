//
//  CreditsView.swift
//  free ai
//
//

import SwiftUI

struct CreditsView: View {
    var body: some View {
        Form {
            Section {
                Link("MLX Swift", destination: URL(string: "https://github.com/ml-explore/mlx-swift")!)
                    .badge(Text(Image(systemName: "arrow.up.right")))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("credits")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    CreditsView()
}
