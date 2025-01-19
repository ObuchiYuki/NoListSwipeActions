# NoListSwipeActions

**A custom SwiftUI library that replicates the iOS 15 “swipeActions” feature without using `List`.** 

With this library, you can display swipe actions in `ScrollView` or any custom view, enabling swipe gestures for actions like delete or favorite.



## Features

- **Swipe actions without using a List** 
  Previously, iOS 15 swipe actions were only available for rows in a `List` (or `ForEach` within a `List`). This library replicates those behaviors with `ScrollView`, `VStack`, or any other view hierarchy.

- **Full swipe support** 
  By enabling the `allowsFullSwipe` option, you can trigger the last action (such as a destructive delete) via a full swipe, closely mirroring the native `List` behavior.

- **Customizable action colors** 
  You can freely set the background color for each action via the `tint` modifier.  
  If you set `role: .destructive`, it automatically uses `.red`.

- **Automatically closes on tap or scroll** 
  If you swipe open an action and then swipe another row, tap the screen, or scroll, previously opened actions automatically close.

---

## Demo

### Example: Multiple Actions

```swift
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
                        // ↓ Apply custom swipe actions
                        ._swipeActions(actions: [
                            // Toggle favorite action
                            SwipeAction(tint: .green, action: {
                                guard let index = self.items.firstIndex(where: { $0.id == item.id }) else { return }
                                self.items[index].isFavorite.toggle()
                            }, content: {
                                Text("Favorite")
                            }),
                            // Another action
                            SwipeAction(action: {
                                // Add your action here
                            }, content: {
                                Text("Other")
                            })
                        ])
                    }
                }
                // ↓ Swipe actions container
                ._swipeActionsContainer()
            }
            .navigationTitle("Multi Actions")
        }
    }
}

#Preview {
    MultiActionsScreen()
}
```

### Example: Swipe to Delete

```swift
import SwiftUI

struct SwipeToDeleteScreen: View {
    @State private var items = (0...100).map { $0 }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    ForEach(self.items, id: \.self) { item in
                        Text("Item \(item)")
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // ↓ One-line delete action
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
```



## Usage

1. **Wrap your content with `._swipeActionsContainer()`** 
   Usually applied to the parent view (e.g., `LazyVStack` or `VStack`) that contains the rows you want to swipe. This container manages closing open actions when tapping or scrolling outside.

2. **Add `._swipeActions()` or `._onDelete()` to each swipable row (cell)**  
   - `._swipeActions(edge:allowsFullSwipe:actions:)` 
     Use this if you want to specify multiple actions. You can customize the edge (`.leading` or `.trailing`) and enable/disable full swipe.
   - `._onDelete(edge:allowsFullSwipe:action:)` 
     A convenient shortcut if you only need a delete action.

### API Overview

```swift
// SwipeAction
public struct SwipeAction {
    let role: ButtonRole?    // e.g., .destructive
    let tint: Color?         // Background color for the action
    let action: () -> Void   // Handler when tapped
    let content: () -> AnyView  // Action label view
}

// Container to manage swipe actions (closes actions on tap or scroll)
public func _swipeActionsContainer() -> some View

// Multiple actions
public func _swipeActions(
    edge: HorizontalEdge = .trailing,
    allowsFullSwipe: Bool = true,
    actions: [SwipeAction]
) -> some View

// Convenient delete action
public func _onDelete(
    edge: HorizontalEdge = .trailing,
    allowsFullSwipe: Bool = true,
    action: @escaping () -> Void
) -> some View
```



## Installation

### Swift Package Manager (Recommended)

1. In Xcode, choose `File > Add Packages...`
2. Enter the repository URL:
   ```
   https://github.com/YourUserName/NoListSwipeActions.git
   ```
3. Select a version or branch and click “Add Package.”

If editing your `Package.swift` directly:

```swift
dependencies: [
    .package(
       url: "https://github.com/YourUserName/NoListSwipeActions.git",
       from: "1.0.0"
    )
]
```



## Limitations / Notes

- This library closely replicates the native swipe actions but is still a custom implementation. Future iOS updates or complex UI requirements may cause behaviors that differ from the native implementation.
- It accounts for `LayoutDirection` (e.g., right-to-left languages), but testing in certain complex scenarios may be incomplete. Feedback and PRs are welcome!
- Includes haptic feedback via `UIImpactFeedbackGenerator`, but vibration behavior may vary by device or user settings.



## License

This library is available under the [MIT License](LICENSE). Feel free to use it for any purpose. Contributions via PR or Issues are welcome!



## Author & Contributions

Please open an Issue or pull request if you encounter bugs or have suggestions!