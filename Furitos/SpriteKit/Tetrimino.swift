import SpriteKit

// MARK: - Tetrimino Shape Types
enum TetrominoType: CaseIterable {
    case I, O, T, S, Z, L, J

    var color: SKColor {
        switch self {
        case .I: return SKColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 1.0)   // Cyan
        case .O: return SKColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0)   // Yellow
        case .T: return SKColor(red: 0.7, green: 0.0, blue: 1.0, alpha: 1.0)   // Purple
        case .S: return SKColor(red: 0.0, green: 1.0, blue: 0.3, alpha: 1.0)   // Green
        case .Z: return SKColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0)   // Red
        case .L: return SKColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)   // Orange
        case .J: return SKColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)   // Blue
        }
    }

    // Each rotation state: array of (col, row) offsets from pivot
    // Rotation 0 = spawn orientation
    var rotations: [[(Int, Int)]] {
        switch self {
        case .I:
            return [
                [(0,0),(1,0),(2,0),(3,0)],
                [(0,0),(0,1),(0,2),(0,3)],
                [(0,0),(1,0),(2,0),(3,0)],
                [(0,0),(0,1),(0,2),(0,3)]
            ]
        case .O:
            return [
                [(0,0),(1,0),(0,1),(1,1)],
                [(0,0),(1,0),(0,1),(1,1)],
                [(0,0),(1,0),(0,1),(1,1)],
                [(0,0),(1,0),(0,1),(1,1)]
            ]
        case .T:
            return [
                [(1,0),(0,1),(1,1),(2,1)],
                [(0,0),(0,1),(1,1),(0,2)],
                [(0,0),(1,0),(2,0),(1,1)],
                [(1,0),(0,1),(1,1),(1,2)]
            ]
        case .S:
            return [
                [(1,0),(2,0),(0,1),(1,1)],
                [(0,0),(0,1),(1,1),(1,2)],
                [(1,0),(2,0),(0,1),(1,1)],
                [(0,0),(0,1),(1,1),(1,2)]
            ]
        case .Z:
            return [
                [(0,0),(1,0),(1,1),(2,1)],
                [(1,0),(0,1),(1,1),(0,2)],
                [(0,0),(1,0),(1,1),(2,1)],
                [(1,0),(0,1),(1,1),(0,2)]
            ]
        case .L:
            return [
                [(2,0),(0,1),(1,1),(2,1)],
                [(0,0),(0,1),(0,2),(1,2)],
                [(0,0),(1,0),(2,0),(0,1)],
                [(0,0),(1,0),(1,1),(1,2)]
            ]
        case .J:
            return [
                [(0,0),(0,1),(1,1),(2,1)],
                [(0,0),(1,0),(0,1),(0,2)],
                [(0,0),(1,0),(2,0),(2,1)],
                [(1,0),(1,1),(0,2),(1,2)]
            ]
        }
    }

    func cells(rotation: Int) -> [(Int, Int)] {
        return rotations[rotation % rotations.count]
    }
}

// MARK: - Active Piece
struct ActivePiece {
    var type: TetrominoType
    var rotation: Int
    var col: Int  // top-left col offset in grid
    var row: Int  // top-left row offset in grid

    var cells: [(Int, Int)] {
        return type.cells(rotation: rotation).map { (c, r) in
            (col + c, row + r)
        }
    }

    mutating func rotate() {
        rotation = (rotation + 1) % 4
    }

    mutating func rotateBack() {
        rotation = (rotation + 3) % 4
    }
}
