# NoListSwipeActions

**SwiftUIの`List`を使わずに、iOS15以降で使える「swipeActions」とほぼ同等の機能を実現できるカスタム実装ライブラリ**です。`ScrollView`や任意のViewでスワイプアクションを表示し、スワイプして削除・お気に入りなどのアクションを呼び出すUIを実装できます。

<img src="https://github.com/user-attachments/assets/abb8559b-e374-407c-a370-1193872ef5b5" width="300px">

## 特徴

- **Listを使わずにスワイプアクション**を実装  
  これまで`List`や`ForEach(in: List)`だけで使えたiOS15のスワイプアクションを、`ScrollView`や`VStack`など任意のView構造でも再現します。

- **フルスワイプに対応**  
  `allowsFullSwipe`オプションを有効にすると、最後のアクションに指定した削除などの操作をフルスワイプで実行できます。純正`List`に近い動きを実現しています。

- **アクションに色を指定**可能  
  `tint`でアクションの背景色を自由に設定できます。  
  また、`role: .destructive`を指定したアクションは自動的に赤色(`.red`)になります。

- **タップやスクロールで自動クローズ**  
  アクションを表示した状態で他のセルをスワイプしたり、画面をタップ・スクロールすると、自動的に以前のスワイプアクションが閉じるように設計されています。



## デモ

### 複数アクションの例

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
                        // ↓ カスタムスワイプアクションを適用
                        ._swipeActions(actions: [
                            // お気に入り切り替えアクション
                            SwipeAction(tint: .green, action: {
                                guard let index = self.items.firstIndex(where: { $0.id == item.id }) else { return }
                                self.items[index].isFavorite.toggle()
                            }, content: {
                                Text("Favorite")
                            }),
                            // その他のアクション
                            SwipeAction(action: {
                                // ここに処理
                            }, content: {
                                Text("Other")
                            })
                        ])
                    }
                }
                // ↓ スワイプアクションのコンテナ
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

### 削除アクションの例

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
                            // ↓ 削除アクションをワンライナーで実装
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



## 使い方

1. **`_swipeActionsContainer()`を適用**
   スワイプアクションを適用したいView(多くの場合、`LazyVStack`や`VStack`)のラッパに `._swipeActionsContainer()` 修飾子を使います。
   
2. **スワイプするセル（行）に `._swipeActions()` または `._onDelete()` を追加**
   個々のセルとなるViewに対して、左スワイプまたは右スワイプアクションを設定します。  
   - `._swipeActions(edge:allowsFullSwipe:actions:)` 
     複数のアクションを指定したいときはこちらを使います。`edge`で左右を指定可能、`allowsFullSwipe`でフルスワイプの可否を制御できます。  
   - `._onDelete(edge:allowsFullSwipe:_:)` 
     削除のみを簡単に実装したい場合に使います。

### APIの概要

```swift
// SwipeAction
public struct SwipeAction {
    let role: ButtonRole?  // .destructiveなど
    let tint: Color?       // アクションの背景色
    let action: () -> Void // タップ時の処理
    let content: () -> AnyView // 表示するラベル

    ...
}

// スワイプアクションのコンテナ（スクロールやタップでアクションを閉じる管理をしている）
public func _swipeActionsContainer() -> some View

// 複数アクションを設定
public func _swipeActions(
    edge: HorizontalEdge = .trailing,
    allowsFullSwipe: Bool = true,
    actions: [SwipeAction]
) -> some View

// 削除用のショートハンド
public func _onDelete(
    edge: HorizontalEdge = .trailing,
    allowsFullSwipe: Bool = true,
    action: @escaping () -> Void
) -> some View
```



## インストール

### Swift Package Manager (推奨)

1. Xcodeのメニューから `File > Add Packages...` を選択
2. 以下のリポジトリURLを入力  
   ```
   https://github.com/YourUserName/NoListSwipeActions.git
   ```
3. バージョンやブランチを選択して`Add Package`を押下

`Package.swift`に直接記述する場合:

```swift
dependencies: [
    .package(
       url: "https://github.com/ObuchiYuki/NoListSwipeActions.git",
       from: "1.0.0"
    )
]
```



## 制限 / 注意事項

- 本ライブラリは「ほぼ」純正のスワイプアクション動作を再現していますが、あくまでカスタム実装です。将来のiOSアップデートや複雑なUIとの組み合わせで、純正とは異なる挙動を取る可能性があります。
- `LayoutDirection`(右から左言語など)を考慮した内部実装を含みますが、特殊なケースで検証不足の可能性があります。フィードバックやPR大歓迎です。
- `UIImpactFeedbackGenerator`など、Hapticsの追加を行っていますが、振動がデバイスや設定によっては異なる場合があります。



## ライセンス

このライブラリは[MIT License](LICENSE)のもとで公開されています。ご自由にお使いください。PRやIssueも歓迎します！



## 作者・貢献

バグ報告や改善点がありましたら、IssueやPull Requestをお寄せください。  
