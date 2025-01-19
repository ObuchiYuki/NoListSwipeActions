//
//  ContentView.swift
//  SwipeToDelete
//
//  Created by yuki on 2025/01/16.
//

import SwiftUI
import Combine

@MainActor
private let beginFullSwipeFeedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
@MainActor
private let endFullSwipeFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)

private let customSwipeDidStartNotficationName = Notification.Name("customSwipeDidStart")

private let minimumActionWidth: CGFloat = 73

private let destructiveThreshold: CGFloat = 120

final class SwipeManager: ObservableObject {
    let close = PassthroughSubject<Void, Never>()
}

public struct SwipeAction {
    let role: ButtonRole?
    
    let tint: Color?
    
    let action: () -> Void
    
    let content: () -> AnyView
    
    public var body: some View {
        self.content()
    }
    
    init<Content: View>(
        role: ButtonRole? = nil,
        tint: Color? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.role = role
        self.tint = tint
        self.action = action
        self.content = { AnyView(content()) }
    }
}

extension View {
    public func _swipeActionsContainer() -> some View {
        SwipeActionsContainer { self }
    }
    
    public func _swipeActions(
        edge: HorizontalEdge = .trailing,
        allowsFullSwipe: Bool = true,
        actions: [SwipeAction]
    ) -> some View {
        self.modifier(SwipeActionModifier(
            allowsFullSwipe: allowsFullSwipe,
            edge: edge,
            actions: actions
        ))
    }
    
    public func _onDelete(
        edge: HorizontalEdge = .trailing,
        allowsFullSwipe: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        self._swipeActions(
            edge: edge,
            allowsFullSwipe: allowsFullSwipe,
            actions: [
                SwipeAction(role: .destructive) {
                    action()
                } content: {
                    Text("Delete")
                }
            ]
        )
    }
}

struct SwipeActionsContainer<Content: View>: View {
    @StateObject var swipeManager = SwipeManager()

    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        self.content()
            .environment(\.swipeManager, self.swipeManager)
            .overlay {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollContentOffsetKey.self,
                        value: proxy.frame(in: .global).minY // globalで良い
                    )
                }
            }
            .onPreferenceChange(ScrollContentOffsetKey.self) { value in
                MainActor.assumeIsolated {
                    self.swipeManager.close.send()
                }
            }
            .onTapGesture {
                self.swipeManager.close.send()
            }
    }
}

fileprivate extension EnvironmentValues {
    @Entry var swipeManager: SwipeManager = SwipeManager()
}

fileprivate struct ScrollContentOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

fileprivate struct ContentSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

fileprivate struct SwipeActionsSizeKey: PreferenceKey {
    static var defaultValue: [Int: CGSize] { [:] }

    static func reduce(value: inout [Int: CGSize], nextValue: () -> [Int: CGSize]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct SwipeActionModifier: ViewModifier {
    @State private var startLocation: CGPoint = .zero
    
    @State private var dragOffset: CGFloat = 0
    @State private var lastDragOffset: CGFloat = 0
    @State private var additionalDragOffset: CGFloat = 0
    
    @State private var isDeleted = false
    @State private var isDragging = false
    @State private var isSwiping = false
    @State private var isFullSwiping = false
    
    @State private var contentSize: CGSize = .zero
    @State private var actionsSize: [Int: CGSize] = [:]
    
    @State private var textAlignment: Alignment = .leading
    
    @Environment(\.swipeManager) var swipeManager
    @Environment(\.layoutDirection) var layoutDirection
    
    let allowsFullSwipe: Bool
    
    let edge: HorizontalEdge
    
    let actions: [SwipeAction]
    
    private let notificationID = UUID()
        
    private var actionsCount: Int {
        self.actions.count
    }

    init(
        allowsFullSwipe: Bool,
        edge: HorizontalEdge,
        actions: [SwipeAction]
    ) {
        self.allowsFullSwipe = allowsFullSwipe
        self.edge = edge
        switch edge {
        case .trailing: self.actions = actions.reversed().map { $0 }
        case .leading: self.actions = actions
        }
    }
    
    private var totalActionWidth: CGFloat {
        self.actionsSize.values.reduce(0) { $0 + max(minimumActionWidth, $1.width) }
    }
    
    private func cellOffset(_ dragOffset: CGFloat) -> CGFloat {
        let edgeSign = self.edge.sign(self.layoutDirection)
        
        if self.isDeleted {
            return -edgeSign*self.contentSize.width
        }
        
        var cellOffset = edgeSign * dragOffset // 正しい方向の場合は常に正
        if cellOffset < 0 { cellOffset = -pow(-cellOffset, 0.68) }
                
        if self.allowsFullSwipe {
            let isLastActionDestructive = self.isLastActionDestructive()
            
            if isLastActionDestructive {
                let preferedContentWidth = self.contentSize.width-16
                
                if cellOffset > preferedContentWidth {
                    let additionalOffset = cellOffset - preferedContentWidth
                    return preferedContentWidth + pow(additionalOffset, 0.52)
                }
            } else {
                let preferedContentWidth = self.contentSize.width/2
                
                if cellOffset > preferedContentWidth {
                    let additionalOffset = cellOffset - preferedContentWidth
                    return preferedContentWidth + pow(additionalOffset, 0.68)
                }
            }
            
            
        } else {
            let totalActionWidth = self.totalActionWidth
            if cellOffset > totalActionWidth {
                let additionalOffset = cellOffset - totalActionWidth
                return totalActionWidth + pow(additionalOffset, 0.68)
            }
        }
        
        return cellOffset
    }
    
    private func actionWidth(_ index: Int, cellOffset: CGFloat) -> CGFloat {
        let totalActionWidth = self.totalActionWidth
        guard let actionSize = self.actionsSize[index] else { return 0 }
        let adjustedActionWidth = max(minimumActionWidth, actionSize.width)
        let actionWidth = cellOffset / totalActionWidth * adjustedActionWidth
        let isLast = index == self.actionsCount - 1
        
        if self.isDeleted {
            if isLast {
                return self.contentSize.width
            } else {
                return 0
            }
        }
        
        if self.isFullSwiping {
            if isLast {
                return cellOffset
            } else {
                return 0
            }
        } else {
            return actionWidth
        }
    }
    
    private func isLastActionDestructive() -> Bool {
        self.actions.last?.role == .destructive
    }
    
    private func fullSwipeThreshold() -> CGFloat {
        let isLastActionDestructive = self.isLastActionDestructive()
        return isLastActionDestructive ?
            self.contentSize.width-destructiveThreshold :
            self.contentSize.width / 2
    }
        
    private func onDragChange(_ value: DragGesture.Value) {
        if !self.isDragging {
            // 他のCellを閉じる
            NotificationCenter.default.post(
                Notification(
                    name: customSwipeDidStartNotficationName,
                    userInfo: ["id": self.notificationID]
                )
            )

            self.startLocation = value.location
            self.isDragging = true
            
            beginFullSwipeFeedbackGenerator.prepare()
            endFullSwipeFeedbackGenerator.prepare()
        }
        
        let translation = value.location - self.startLocation
        let newDragOffset = self.lastDragOffset + translation.x + self.additionalDragOffset
        let edgeSign = self.edge.sign(self.layoutDirection)
        
        if edgeSign*newDragOffset > 0 { // 一回でも正しい方向にスワイプ開始したらスタート
            self.isSwiping = true
        }

        if !self.isSwiping { return }
        
        let cellOffset = self.cellOffset(newDragOffset)
                
        if self.allowsFullSwipe {
            let fullSwipeThreshold = self.fullSwipeThreshold()
            let newIsFullSwiping = cellOffset >= fullSwipeThreshold
            let isLastActionDestructive = self.isLastActionDestructive()

            if self.isFullSwiping != newIsFullSwiping {
                if newIsFullSwiping {
                    beginFullSwipeFeedbackGenerator.impactOccurred()
                } else {
                    endFullSwipeFeedbackGenerator.impactOccurred()
                }
                
                DispatchQueue.main.async {
                    if isLastActionDestructive {
                        withAnimation(
                            .interpolatingSpring(Spring.smooth(duration: 0.51))
                        ) {
                            self.isFullSwiping = newIsFullSwiping
                            if newIsFullSwiping && self.additionalDragOffset == 0 {
                                self.additionalDragOffset = edgeSign*(destructiveThreshold - 32)
                                self.dragOffset = newDragOffset + self.additionalDragOffset
                            } else {
                                self.dragOffset = newDragOffset
                            }
                        }
                    } else {
                        withAnimation(.interpolatingSpring(Spring.snappy(duration: 0.31))) {
                            self.isFullSwiping = newIsFullSwiping
                            self.dragOffset = newDragOffset
                        }
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                self.dragOffset = newDragOffset
            }
        } else {
            self.dragOffset = newDragOffset
        }
    }
    
    private func onDragEnd(_ value: DragGesture.Value) {
        DispatchQueue.main.async {
            self.isSwiping = false
            self.isDragging = false
            let isLastActionDestructive = self.isLastActionDestructive()
            
            if self.isFullSwiping {
                if isLastActionDestructive {
                    self.dismissDestructiveAndExecuteAction()
                } else {
                    self.dismiss()
                    self.actions.last?.action()
                }
                return
            }
            
            let translation = value.location - self.startLocation
            let newDragOffset = self.lastDragOffset + translation.x + self.additionalDragOffset
            let edgeSign = self.edge.sign(self.layoutDirection)
            let openOffset = self.totalActionWidth
            
            if edgeSign*newDragOffset > openOffset/2 - 32 { // on open
                let openOffset = edgeSign*openOffset
                
                withAnimation(
                    .interpolatingSpring(
                        Spring.smooth(duration: 0.68),
                        initialVelocity: -value.velocity.width / 1000
                    )
                ) {
                    self.dragOffset = openOffset
                    self.lastDragOffset = openOffset
                    self.additionalDragOffset = 0
                }
                
                return
            }
            
            self.dismiss()
        }
    }
    
    private func dismissDestructiveAndExecuteAction() {
        withAnimation(.interpolatingSpring(
            .smooth(duration: 0.28)
        )) {
            self.isDeleted = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now()+0.282) {
            self.actions.last?.action()
            
            self.startLocation = .zero
            
            self.dragOffset = 0
            self.lastDragOffset = 0
            self.additionalDragOffset = 0
            
            self.isDeleted = false
            self.isDragging = false
            self.isSwiping = false
            self.isFullSwiping = false
            
            self.contentSize = .zero
            self.actionsSize = [:]
            
            self.textAlignment = .leading
        }
    }
    
    private func dismiss() {
        withAnimation(.interpolatingSpring(
            .snappy(duration: 0.68)
        )) {
            self.dragOffset = 0
            self.lastDragOffset = 0
            self.additionalDragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now()+0.68) {
            self.isFullSwiping = false
        }
    }

    func body(content: Content) -> some View {
        let cellOffset = self.cellOffset(self.dragOffset)
        let offsetSign = self.edge.offsetSign(self.layoutDirection)
        
        content
            .contentShape(Rectangle())
            .offset(x: offsetSign*cellOffset)
            .gesture(
                DragGesture(minimumDistance: 26.0)
                    .onChanged(self.onDragChange)
                    .onEnded(self.onDragEnd)
            )
            .overlay {
                GeometryReader { proxy in
                    Color.clear.preference(key: ContentSizeKey.self, value: proxy.size)
                }
            }
            .onPreferenceChange(ContentSizeKey.self) { size in
                MainActor.assumeIsolated {
                    self.contentSize = size
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: customSwipeDidStartNotficationName
                )
            ) { notification in
                let id = notification.userInfo?["id"] as? UUID
                if id != self.notificationID {
                    self.dismiss()
                }
            }
            .onReceive(self.swipeManager.close) { _ in
                self.dismiss()
            }
            .background(alignment: self.edge.alignment) {
                HStack(spacing: 0) {
                    ForEach(zip(self.actions, self.actions.indices).map{ $0 }, id: \.1) { action, index in
                        let actionWidth = self.actionWidth(index, cellOffset: cellOffset)
                        
                        action.content()
                            .fixedSize()
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .overlay {
                                GeometryReader { proxy in
                                    Color.clear
                                        .preference(key: SwipeActionsSizeKey.self, value: [index: proxy.size])
                                }
                            }
                            .frame(minWidth: minimumActionWidth, alignment: .center)
                            .frame(
                                maxWidth: .infinity,
                                alignment: self.actions.count > 1 ?
                                    Alignment.leading :
                                    self.isFullSwiping ? self.edge.reversedAlignment : self.edge.alignment
                            )
                            .frame(width: actionWidth, alignment: .leading)
                            .frame(maxHeight: .infinity)
                            .clipped()
                            .background(
                                action.role == .destructive ? Color.red : action.tint ?? Color.gray
                            )
                            .onTapGesture {
                                let isLast = index == self.actionsCount - 1
                                let isLastActionDestructive = self.isLastActionDestructive()
                                if isLast && isLastActionDestructive {
                                    self.dismissDestructiveAndExecuteAction()
                                } else {
                                    self.dismiss()
                                    action.action()
                                }
                            }
                    }
                }
            }
            .frame(height: self.isDeleted ? 0 : nil, alignment: .top)
            .clipped()
            .onPreferenceChange(SwipeActionsSizeKey.self) { value in
                MainActor.assumeIsolated {
                    self.actionsSize = value
                }
            }
    }
}

fileprivate extension CGPoint {
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
}

fileprivate extension HorizontalEdge {
    func offsetSign(_ layoutDirection: LayoutDirection) -> CGFloat {
        switch self {
        case .leading: return 1
        case .trailing: return -1
        }
    }
    
    func sign(_ layoutDirection: LayoutDirection) -> CGFloat {
        switch layoutDirection {
        case .leftToRight:
            switch self {
            case .leading: return 1
            case .trailing: return -1
            }
        case .rightToLeft:
            switch self {
            case .leading: return -1
            case .trailing: return 1
            }
        @unknown default:
            switch self {
            case .leading: return 1
            case .trailing: return -1
            }
        }
    }
    
    var alignment: Alignment {
        switch self {
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
    
    var reversedAlignment: Alignment {
        switch self {
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }
}

#Preview {
    @Previewable @State var titles = ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5", "Item 6", "Item 7", "Item 8", "Item 9", "Item 10"]
    
    VStack {
        Text("ScrollView")
            .font(.title)
        
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(titles, id: \.self) { title in
                    Text(title)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ._swipeActions(edge: .trailing, allowsFullSwipe: true, actions: [
                        SwipeAction(role: .destructive) {
                            titles.removeAll { $0 == title }
                        } content: {
                            Text("Delete")
                        },
                        SwipeAction(tint: .green) {} content: {
                            Text("Favorite")
                        }
                    ])
                }
            }
            ._swipeActionsContainer()
        }
        
        Divider()
        
        Text("List")
            .font(.title)
        
        List {
            ForEach(titles, id: \.self) { title in
                Text(title)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            titles.removeAll { $0 == title }
                        } label: {
                            Text("Delete")
                        }
                        Button() {} label: {
                            Text("Favorite")
                        }
                        .tint(.green)
                    }
            }
        }
        .listStyle(.plain)
    }
}
