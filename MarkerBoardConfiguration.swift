import Foundation

/// The printed boards use OpenCV DICT_4X4_250, with eight distinct marker IDs per board.
/// This mapping is shared by the camera detector and the lift overview.
enum MarkerBoardConfiguration {
    static let dictionary = "DICT_4X4_250"
    static let boardSizeMillimeters: Double = 140
    static let squareSizeMillimeters: Double = 35
    static let markerSizeMillimeters: Double = 26
    static let markerIDsPerBoard = 8

    static func boardNumber(forArUcoID id: Int) -> Int? {
        guard (0..<64).contains(id) else { return nil }
        return id / markerIDsPerBoard + 1
    }

    static func isReferenceBoard(_ board: Int) -> Bool { (1...4).contains(board) }
    static func isWheelBoard(_ board: Int) -> Bool { (5...8).contains(board) }
}
