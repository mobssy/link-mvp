//
//  OpenChatRooms.swift
//  TalkMVP
//
//  The chat rooms on screen right now
//

import Foundation

/// The chat rooms showing on screen right now. A room counts as open from its chat screen's
/// appearance to its disappearance; it is counted, so two screens of the same room close it only
/// when both are gone.
@MainActor
final class OpenChatRooms {
    static let shared = OpenChatRooms()

    private var screens: [UUID: Int] = [:]

    func opened(_ roomID: UUID) {
        screens[roomID, default: 0] += 1
    }

    func closed(_ roomID: UUID) {
        guard let count = screens[roomID] else { return }
        screens[roomID] = count > 1 ? count - 1 : nil
    }

    func contains(_ roomID: UUID) -> Bool {
        screens[roomID] != nil
    }
}
