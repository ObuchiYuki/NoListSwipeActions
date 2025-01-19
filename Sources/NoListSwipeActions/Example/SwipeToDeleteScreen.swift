//
//  SwipeToDeleteScreen.swift
//  NoListSwipeActions
//
//  Created by yuki on 2025/01/19.
//

import SwiftUI

struct SwipeToDeleteScreen: View {
    @State private var items = (0...100).map { $0 }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack {
                    ForEach(self.items, id: \.self) { item in
                        Text("Item \(item)")
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            ._onDelete {
                                self.items.removeAll { $0 == item }
                            }
                    }
                }
                ._swipeActionsContainer()
            }
            .navigationTitle("Swipe to delete")
        }
    }
}

#Preview {
    SwipeToDeleteScreen()
}
