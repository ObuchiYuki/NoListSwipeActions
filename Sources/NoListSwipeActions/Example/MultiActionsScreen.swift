//
//  MultiActionsScreen.swift
//  NoListSwipeActions
//
//  Created by yuki on 2025/01/19.
//

import SwiftUI

fileprivate struct Item: Identifiable {
    var id: Int
    var isFavorite: Bool
}

struct MultiActionsScreen: View {
    @State private var items: [Item] = (0...100).map { Item(id: $0, isFavorite: false) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    ForEach(self.items) { item in
                        HStack {
                            Text("Item \(item.id)")
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .opacity(item.isFavorite ? 1 : 0)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        ._swipeActions(actions: [
                            SwipeAction(tint: .green, action: {
                                guard let index = self.items.firstIndex(where: { $0.id == item.id }) else {
                                    return
                                }
                                self.items[index].isFavorite.toggle()
                            }, content: {
                                Text("Favorite")
                            }),
                            SwipeAction(action: {
                                
                            }, content: {
                                Text("Other")
                            }),
                            
                        ])
                    }
                }
                ._swipeActionsContainer()
            }
            .navigationTitle("Multi Actions")
        }
    }
}

#Preview {
    MultiActionsScreen()
}
