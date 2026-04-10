import SpriteKit
import UIKit

// MARK: - Game Constants
private let gridCols = 10
private let gridRows = 10

// MARK: - GameScene
class GameScene: SKScene {

    // MARK: - Public State
    var onScoreChanged: ((Int) -> Void)?
    var onGameOver: (() -> Void)?

    // MARK: - Grid
    private var cellSize: CGFloat = 0
    private var gridOriginX: CGFloat = 0
    private var gridOriginY: CGFloat = 0

    // board[row][col] = color or nil
    private var board: [[SKColor?]] = Array(
        repeating: Array(repeating: nil, count: gridCols),
        count: gridRows
    )
    private var blockNodes: [[SKShapeNode?]] = Array(
        repeating: Array(repeating: nil, count: gridCols),
        count: gridRows
    )

    // MARK: - Current Piece
    private var currentPiece: ActivePiece?
    private var pieceNodes: [SKShapeNode] = []
    private var ghostNodes: [SKShapeNode] = []

    // MARK: - Gravity
    private var gravityDir: GravityDirection = .down
    private let gyroManager = GyroManager()

    // MARK: - Timing
    private var dropInterval: TimeInterval = 0.6
    private var lastDropTime: TimeInterval = 0
    private var isGameOver = false
    private var isPaused2 = false

    // MARK: - Score
    private var score: Int = 0 {
        didSet { onScoreChanged?(score) }
    }
    private var level: Int = 1
    private var linesCleared: Int = 0

    // MARK: - Fever
    private var feverManager: FeverManager!

    // MARK: - Grid visual nodes
    private var gridNode: SKNode!
    private var boardNode: SKNode!

    // MARK: - Setup
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)

        setupGrid()
        feverManager = FeverManager(scene: self)
        setupGestures(in: view)
        setupGyro()
        spawnPiece()
        BGMManager.shared.start()

        // Grid line overlay
        drawGridLines()
    }

    private func setupGrid() {
        let padding: CGFloat = 8
        let availW = size.width - padding * 2
        let availH = size.height - 120 // leave room for HUD and ad

        let cellW = availW / CGFloat(gridCols)
        let cellH = availH / CGFloat(gridRows)
        cellSize = min(cellW, cellH)

        let totalW = cellSize * CGFloat(gridCols)
        let totalH = cellSize * CGFloat(gridRows)

        gridOriginX = (size.width - totalW) / 2
        gridOriginY = 60 + (availH - totalH) / 2  // 60pt above bottom for ad bar

        gridNode = SKNode()
        gridNode.zPosition = 1
        addChild(gridNode)

        boardNode = SKNode()
        boardNode.zPosition = 2
        addChild(boardNode)
    }

    private func drawGridLines() {
        let lineColor = SKColor(white: 1.0, alpha: 0.06)
        let lineWidth: CGFloat = 0.5

        for col in 0...gridCols {
            let x = gridOriginX + CGFloat(col) * cellSize
            let line = SKShapeNode(rectOf: CGSize(width: lineWidth, height: cellSize * CGFloat(gridRows)))
            line.position = CGPoint(x: x, y: gridOriginY + cellSize * CGFloat(gridRows) / 2)
            line.fillColor = lineColor
            line.strokeColor = .clear
            line.zPosition = 1
            gridNode.addChild(line)
        }
        for row in 0...gridRows {
            let y = gridOriginY + CGFloat(row) * cellSize
            let line = SKShapeNode(rectOf: CGSize(width: cellSize * CGFloat(gridCols), height: lineWidth))
            line.position = CGPoint(x: gridOriginX + cellSize * CGFloat(gridCols) / 2, y: y)
            line.fillColor = lineColor
            line.strokeColor = .clear
            line.zPosition = 1
            gridNode.addChild(line)
        }

        // Border
        let border = SKShapeNode(rectOf: CGSize(
            width: cellSize * CGFloat(gridCols) + 2,
            height: cellSize * CGFloat(gridRows) + 2
        ), cornerRadius: 2)
        border.position = CGPoint(
            x: gridOriginX + cellSize * CGFloat(gridCols) / 2,
            y: gridOriginY + cellSize * CGFloat(gridRows) / 2
        )
        border.fillColor = .clear
        border.strokeColor = SKColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.4)
        border.lineWidth = 1.5
        border.zPosition = 3
        addChild(border)
    }

    // MARK: - Gyroscope
    private func setupGyro() {
        gyroManager.onGravityChanged = { [weak self] direction in
            self?.gravityChanged(to: direction)
        }
        gyroManager.onShake = { [weak self] in
            self?.rotatePiece()
        }
        gyroManager.start()
    }

    private func gravityChanged(to direction: GravityDirection) {
        let oldDir = gravityDir
        gravityDir = direction
        // Redraw ghost with new gravity
        updateGhost()
        // Shake landed blocks when gravity changes
        if oldDir != direction {
            shakeSettledBlocks(toward: direction)
        }
    }

    private func shakeSettledBlocks(toward direction: GravityDirection) {
        let dx: CGFloat
        let dy: CGFloat
        switch direction {
        case .down:  dx = 0;  dy = -2.5
        case .up:    dx = 0;  dy = 2.5
        case .left:  dx = -2.5; dy = 0
        case .right: dx = 2.5;  dy = 0
        }
        for r in 0..<gridRows {
            for c in 0..<gridCols {
                if let node = blockNodes[r][c] {
                    let jitter = CGFloat.random(in: 0.5...1.5)
                    let delay = Double.random(in: 0...0.05)
                    node.run(SKAction.sequence([
                        SKAction.wait(forDuration: delay),
                        SKAction.moveBy(x: dx * jitter, y: dy * jitter, duration: 0.04),
                        SKAction.moveBy(x: -dx * jitter * 0.6, y: -dy * jitter * 0.6, duration: 0.04),
                        SKAction.moveBy(x: dx * jitter * 0.2, y: dy * jitter * 0.2, duration: 0.03),
                        SKAction.moveBy(x: -dx * jitter * 0.2 + dx * jitter * 0.6 - dx * jitter,
                                        y: -dy * jitter * 0.2 + dy * jitter * 0.6 - dy * jitter,
                                        duration: 0.03)
                    ]))
                }
            }
        }
    }

    // MARK: - Gestures
    private func setupGestures(in view: SKView) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tap)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)

        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp))
        swipeUp.direction = .up
        view.addGestureRecognizer(swipeUp)

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        swipeDown.direction = .down
        view.addGestureRecognizer(swipeDown)
    }

    @objc private func handleTap() {
        guard !isGameOver, !isPaused2 else { return }
        rotatePiece()
    }

    @objc private func handleSwipeRight() {
        guard !isGameOver, !isPaused2 else { return }
        switch gravityDir {
        case .down, .up:
            movePiece(dc: 1, dr: 0)
        case .left:
            // swipe right = move opposite to gravity = move right (dc+1)
            movePiece(dc: 1, dr: 0)
        case .right:
            // swipe right = move with gravity = hard drop
            hardDrop()
        }
    }

    @objc private func handleSwipeLeft() {
        guard !isGameOver, !isPaused2 else { return }
        switch gravityDir {
        case .down, .up:
            movePiece(dc: -1, dr: 0)
        case .left:
            hardDrop()
        case .right:
            movePiece(dc: -1, dr: 0)
        }
    }

    @objc private func handleSwipeUp() {
        guard !isGameOver, !isPaused2 else { return }
        switch gravityDir {
        case .down:
            hardDrop()
        case .up:
            // swipe up = move opposite to gravity
            movePiece(dc: 0, dr: 1)
        case .left, .right:
            movePiece(dc: 0, dr: 1)
        }
    }

    @objc private func handleSwipeDown() {
        guard !isGameOver, !isPaused2 else { return }
        switch gravityDir {
        case .down:
            softDrop()
        case .up:
            hardDrop()
        case .left, .right:
            movePiece(dc: 0, dr: -1)
        }
    }

    // MARK: - Spawn
    private func spawnPiece() {
        let type = TetrominoType.allCases.randomElement()!
        var piece = ActivePiece(type: type, rotation: 0, col: 0, row: 0)

        // Place spawn at edge opposite gravity
        let spawnPos = spawnPosition(for: type, gravity: gravityDir, rotation: 0)
        piece.col = spawnPos.col
        piece.row = spawnPos.row

        if !isValidPosition(piece) {
            triggerGameOver()
            return
        }

        currentPiece = piece
        renderCurrentPiece()
        updateGhost()
    }

    private func spawnPosition(for type: TetrominoType, gravity: GravityDirection, rotation: Int) -> (col: Int, row: Int) {
        let cells = type.cells(rotation: rotation)
        let maxC = cells.map { $0.0 }.max() ?? 0
        let maxR = cells.map { $0.1 }.max() ?? 0

        switch gravity {
        case .down:
            // Spawn at top, centered horizontally
            return (col: (gridCols - maxC - 1) / 2, row: gridRows - maxR - 1)
        case .up:
            // Spawn at bottom
            return (col: (gridCols - maxC - 1) / 2, row: 0)
        case .right:
            // Spawn at left edge
            return (col: 0, row: (gridRows - maxR - 1) / 2)
        case .left:
            // Spawn at right edge
            return (col: gridCols - maxC - 1, row: (gridRows - maxR - 1) / 2)
        }
    }

    // MARK: - Gravity Drop Direction
    private func dropDelta(for gravity: GravityDirection) -> (dc: Int, dr: Int) {
        switch gravity {
        case .down:  return (0, -1)
        case .up:    return (0,  1)
        case .left:  return (-1, 0)
        case .right: return (1,  0)
        }
    }

    // MARK: - Validation
    private func isValidPosition(_ piece: ActivePiece) -> Bool {
        for (c, r) in piece.cells {
            if c < 0 || c >= gridCols || r < 0 || r >= gridRows { return false }
            if board[r][c] != nil { return false }
        }
        return true
    }

    // MARK: - Movement
    private func movePiece(dc: Int, dr: Int) {
        guard var piece = currentPiece else { return }
        piece.col += dc
        piece.row += dr
        if isValidPosition(piece) {
            currentPiece = piece
            renderCurrentPiece()
            updateGhost()
            SoundManager.shared.playClick()
        }
    }

    private func rotatePiece() {
        guard var piece = currentPiece else { return }
        piece.rotate()
        if isValidPosition(piece) {
            currentPiece = piece
        } else {
            // Wall kick attempts
            let kicks = [(1,0),(-1,0),(2,0),(-2,0),(0,1),(0,-1)]
            var kicked = false
            for (dc, dr) in kicks {
                var kicked_piece = piece
                kicked_piece.col += dc
                kicked_piece.row += dr
                if isValidPosition(kicked_piece) {
                    currentPiece = kicked_piece
                    kicked = true
                    break
                }
            }
            if !kicked {
                // revert
                currentPiece?.rotateBack()
                return
            }
        }
        renderCurrentPiece()
        updateGhost()
        SoundManager.shared.playWhoosh()
    }

    private func softDrop() {
        let (dc, dr) = dropDelta(for: gravityDir)
        guard var piece = currentPiece else { return }
        piece.col += dc
        piece.row += dr
        if isValidPosition(piece) {
            currentPiece = piece
            renderCurrentPiece()
            updateGhost()
            score += 1
        } else {
            lockPiece()
        }
    }

    private func hardDrop() {
        guard var piece = currentPiece else { return }
        let (dc, dr) = dropDelta(for: gravityDir)
        var dropped = 0
        while true {
            var next = piece
            next.col += dc
            next.row += dr
            if isValidPosition(next) {
                piece = next
                dropped += 1
            } else {
                break
            }
        }
        currentPiece = piece
        score += dropped * 2
        renderCurrentPiece()
        lockPiece()
    }

    // MARK: - Ghost Piece
    private func updateGhost() {
        for n in ghostNodes { n.removeFromParent() }
        ghostNodes.removeAll()

        guard var piece = currentPiece else { return }
        let (dc, dr) = dropDelta(for: gravityDir)
        while true {
            var next = piece
            next.col += dc
            next.row += dr
            if isValidPosition(next) {
                piece = next
            } else {
                break
            }
        }

        // Only show ghost if it differs from current position
        guard piece.col != currentPiece?.col || piece.row != currentPiece?.row else { return }

        for (c, r) in piece.cells {
            let node = makeBlockNode(color: piece.type.color.withAlphaComponent(0.2), size: cellSize - 2)
            node.position = cellPosition(col: c, row: r)
            node.zPosition = 4
            node.strokeColor = piece.type.color.withAlphaComponent(0.5)
            node.lineWidth = 1
            addChild(node)
            ghostNodes.append(node)
        }
    }

    // MARK: - Lock Piece
    private func lockPiece() {
        guard let piece = currentPiece else { return }

        SoundManager.shared.playThud()
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()

        for (c, r) in piece.cells {
            guard c >= 0, c < gridCols, r >= 0, r < gridRows else { continue }
            board[r][c] = piece.type.color

            let node = makeBlockNode(color: piece.type.color, size: cellSize - 2)
            node.position = cellPosition(col: c, row: r)
            node.zPosition = 5
            boardNode.addChild(node)
            blockNodes[r][c] = node
        }

        // Lock flash effect
        for (c, r) in piece.cells {
            let flash = makeBlockNode(color: .white, size: cellSize - 2)
            flash.position = cellPosition(col: c, row: r)
            flash.zPosition = 6
            flash.alpha = 0.6
            addChild(flash)
            flash.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.15),
                SKAction.removeFromParent()
            ]))
        }

        for n in pieceNodes { n.removeFromParent() }
        pieceNodes.removeAll()
        for n in ghostNodes { n.removeFromParent() }
        ghostNodes.removeAll()

        currentPiece = nil

        let cleared = checkAndClearLines()
        if cleared > 0 {
            updateScore(linesCleared: cleared)
            feverManager.triggerLineClear(count: cleared)
        } else {
            feverManager.resetCombo()
        }

        if !isGameOver {
            spawnPiece()
        }
    }

    // MARK: - Line Clearing
    private func checkAndClearLines() -> Int {
        var linesToClear: [Int] = []

        switch gravityDir {
        case .down, .up:
            // Check rows (horizontal lines)
            for r in 0..<gridRows {
                if board[r].allSatisfy({ $0 != nil }) {
                    linesToClear.append(r)
                }
            }
            if !linesToClear.isEmpty {
                clearRows(linesToClear)
            }
        case .left, .right:
            // Check columns (vertical lines)
            for c in 0..<gridCols {
                if (0..<gridRows).allSatisfy({ board[$0][c] != nil }) {
                    linesToClear.append(c)
                }
            }
            if !linesToClear.isEmpty {
                clearCols(linesToClear)
            }
        }

        return linesToClear.count
    }

    private func clearRows(_ rows: [Int]) {
        // Animate cleared cells
        for r in rows {
            for c in 0..<gridCols {
                if let node = blockNodes[r][c] {
                    node.run(SKAction.sequence([
                        SKAction.group([
                            SKAction.scale(to: 0, duration: 0.15),
                            SKAction.fadeOut(withDuration: 0.15)
                        ]),
                        SKAction.removeFromParent()
                    ]))
                    blockNodes[r][c] = nil
                }
                board[r][c] = nil
            }
        }

        // Collapse based on gravity direction
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self = self else { return }
            self.collapseRows(cleared: rows)
            self.rebuildBoardNodes()
        }
    }

    private func collapseRows(cleared: [Int]) {
        let clearedSet = Set(cleared)
        var newBoard: [[SKColor?]] = []
        var keptRows: [Int] = []

        switch gravityDir {
        case .down:
            // Keep non-cleared rows, shift down (cleared rows fall from top)
            for r in 0..<gridRows {
                if !clearedSet.contains(r) {
                    newBoard.append(board[r])
                    keptRows.append(r)
                }
            }
            // Add empty rows at top
            while newBoard.count < gridRows {
                newBoard.append(Array(repeating: nil, count: gridCols))
            }
        case .up:
            // Keep non-cleared rows, shift up
            for r in 0..<gridRows {
                if !clearedSet.contains(r) {
                    newBoard.append(board[r])
                    keptRows.append(r)
                }
            }
            // Add empty rows at bottom
            while newBoard.count < gridRows {
                newBoard.insert(Array(repeating: nil, count: gridCols), at: 0)
            }
        default:
            return
        }
        board = newBoard
    }

    private func clearCols(_ cols: [Int]) {
        for c in cols {
            for r in 0..<gridRows {
                if let node = blockNodes[r][c] {
                    node.run(SKAction.sequence([
                        SKAction.group([
                            SKAction.scale(to: 0, duration: 0.15),
                            SKAction.fadeOut(withDuration: 0.15)
                        ]),
                        SKAction.removeFromParent()
                    ]))
                    blockNodes[r][c] = nil
                }
                board[r][c] = nil
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self = self else { return }
            self.collapseCols(cleared: cols)
            self.rebuildBoardNodes()
        }
    }

    private func collapseCols(cleared: [Int]) {
        let clearedSet = Set(cleared)

        switch gravityDir {
        case .right:
            // Shift columns left (gravity pulls right, cleared cols from left)
            var newBoard = Array(repeating: Array(repeating: Optional<SKColor>(nil), count: gridCols), count: gridRows)
            var newCol = 0
            for c in 0..<gridCols {
                if !clearedSet.contains(c) {
                    for r in 0..<gridRows {
                        newBoard[r][newCol] = board[r][c]
                    }
                    newCol += 1
                }
            }
            board = newBoard
        case .left:
            var newBoard = Array(repeating: Array(repeating: Optional<SKColor>(nil), count: gridCols), count: gridRows)
            var newCol = gridCols - 1
            for c in stride(from: gridCols - 1, through: 0, by: -1) {
                if !clearedSet.contains(c) {
                    for r in 0..<gridRows {
                        newBoard[r][newCol] = board[r][c]
                    }
                    newCol -= 1
                }
            }
            board = newBoard
        default:
            return
        }
    }

    private func rebuildBoardNodes() {
        // Remove all board nodes and rebuild
        boardNode.removeAllChildren()
        blockNodes = Array(repeating: Array(repeating: nil, count: gridCols), count: gridRows)

        for r in 0..<gridRows {
            for c in 0..<gridCols {
                if let color = board[r][c] {
                    let node = makeBlockNode(color: color, size: cellSize - 2)
                    node.position = cellPosition(col: c, row: r)
                    node.zPosition = 5
                    boardNode.addChild(node)
                    blockNodes[r][c] = node
                }
            }
        }
    }

    // MARK: - Score
    private func updateScore(linesCleared lines: Int) {
        let points = [0, 100, 300, 500, 800]
        let pts = lines < points.count ? points[lines] : 1200
        score += pts * level
        linesCleared += lines

        let newLevel = linesCleared / 10 + 1
        if newLevel > level {
            level = newLevel
            dropInterval = max(0.1, 0.6 - Double(level - 1) * 0.05)
        }
    }

    // MARK: - Rendering
    private func renderCurrentPiece() {
        for n in pieceNodes { n.removeFromParent() }
        pieceNodes.removeAll()

        guard let piece = currentPiece else { return }

        for (c, r) in piece.cells {
            guard c >= 0, c < gridCols, r >= 0, r < gridRows else { continue }
            let node = makeBlockNode(color: piece.type.color, size: cellSize - 2)
            node.position = cellPosition(col: c, row: r)
            node.zPosition = 10
            // Glow effect
            node.glowWidth = 3
            addChild(node)
            pieceNodes.append(node)
        }
    }

    private func makeBlockNode(color: SKColor, size: CGFloat) -> SKShapeNode {
        let inset: CGFloat = 1
        let node = SKShapeNode(rectOf: CGSize(width: size - inset, height: size - inset), cornerRadius: 3)
        node.fillColor = color
        node.strokeColor = color.withAlphaComponent(0.6)
        node.lineWidth = 1
        return node
    }

    private func cellPosition(col: Int, row: Int) -> CGPoint {
        return CGPoint(
            x: gridOriginX + CGFloat(col) * cellSize + cellSize / 2,
            y: gridOriginY + CGFloat(row) * cellSize + cellSize / 2
        )
    }

    // MARK: - Game Loop
    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver, !isPaused2 else { return }

        if lastDropTime == 0 { lastDropTime = currentTime }

        if currentTime - lastDropTime >= dropInterval {
            lastDropTime = currentTime
            dropOneTick()
        }
    }

    private func dropOneTick() {
        guard var piece = currentPiece else { return }
        let (dc, dr) = dropDelta(for: gravityDir)
        piece.col += dc
        piece.row += dr

        if isValidPosition(piece) {
            currentPiece = piece
            renderCurrentPiece()
        } else {
            lockPiece()
        }
    }

    // MARK: - Game Over
    private func triggerGameOver() {
        isGameOver = true
        gyroManager.stop()
        BGMManager.shared.stop()

        // Board flash red
        let flash = SKSpriteNode(color: SKColor(red: 1, green: 0, blue: 0, alpha: 0.4), size: size)
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 300
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.1),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))

        // Cascade blocks falling off screen
        for r in 0..<gridRows {
            for c in 0..<gridCols {
                if let node = blockNodes[r][c] {
                    let delay = Double.random(in: 0...0.4)
                    let fallDist = CGFloat.random(in: -size.height * 0.5 ... size.height * 0.5)
                    node.run(SKAction.sequence([
                        SKAction.wait(forDuration: delay),
                        SKAction.group([
                            SKAction.moveBy(x: CGFloat.random(in: -30...30), y: fallDist, duration: 0.5),
                            SKAction.rotate(byAngle: CGFloat.random(in: -.pi * 2 ... .pi * 2), duration: 0.5),
                            SKAction.fadeOut(withDuration: 0.5)
                        ]),
                        SKAction.removeFromParent()
                    ]))
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.onGameOver?()
        }
    }

    // MARK: - Reset
    func resetGame() {
        isGameOver = false
        score = 0
        level = 1
        linesCleared = 0
        dropInterval = 0.6
        lastDropTime = 0
        feverManager.resetCombo()

        board = Array(repeating: Array(repeating: nil, count: gridCols), count: gridRows)
        blockNodes = Array(repeating: Array(repeating: nil, count: gridCols), count: gridRows)

        boardNode.removeAllChildren()
        for n in pieceNodes { n.removeFromParent() }
        for n in ghostNodes { n.removeFromParent() }
        pieceNodes.removeAll()
        ghostNodes.removeAll()
        currentPiece = nil

        gravityDir = .down
        gyroManager.start()
        spawnPiece()
        BGMManager.shared.start()
    }
}
