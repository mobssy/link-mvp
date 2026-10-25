//
//  AppRouter.swift
//  TalkMVP
//

import Foundation
import Observation

enum AppTab: Hashable {
    case friends, chats, settings
}

/// Moves between the tabs on a screen's behalf, so a screen in one tab can open something in
/// another instead of presenting a copy of it in a sheet.
@MainActor
protocol AppRouting: AnyObject {
    var selectedTab: AppTab { get set }
    /// Switches to Chats and asks it to open `roomID`.
    func openChat(_ roomID: UUID)
    /// The room Chats should open, handed over once.
    func takeRoomToOpen() -> UUID?
}

@MainActor
@Observable
final class AppRouter: AppRouting {
    var selectedTab: AppTab = .friends
    /// Read by the chat list to notice a hand-over; take it with `takeRoomToOpen()`.
    private(set) var roomToOpen: UUID?

    func openChat(_ roomID: UUID) {
        roomToOpen = roomID
        selectedTab = .chats
    }

    func takeRoomToOpen() -> UUID? {
        defer { roomToOpen = nil }
        return roomToOpen
    }
}
