import SpriteKit
import UIKit

// MARK: - Fever Manager
class FeverManager {
    weak var scene: SKScene?
    private var comboCount: Int = 0
    private var feverLevel: Int = 0
    private var feverActive: Bool = false

    init(scene: SKScene) {
        self.scene = scene
    }

    // MARK: - Public Entry Points

    func triggerLineClear(count: Int) {
        comboCount += 1
        switch count {
        case 1:
            singleLineClear()
        case 2:
            doubleLineClear()
        default:
            triplePlusClear(count: count)
        }
        if comboCount >= 3 {
            triggerCombo(level: min(comboCount, 5))
        }
    }

    func resetCombo() {
        comboCount = 0
        feverLevel = 0
        feverActive = false
    }

    func triggerFever() {
        feverActive = true
        feverLevel += 1
        guard let scene = scene else { return }

        SoundManager.shared.playExplosion()

        // Massive screen shake
        scene.run(screenShake(intensity: 18, duration: 0.7))

        // Rainbow background flash sequence
        rainbowBackgroundFlash()

        // Fireworks particles from multiple points
        for i in 0..<6 {
            let delay = Double(i) * 0.12
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.spawnFireworks()
            }
        }

        // Star burst
        spawnStarBurst()

        // Lightning arcs
        spawnLightning()

        // FEVER!! text
        showFeverText()

        // Haptic bursts
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                let gen = UIImpactFeedbackGenerator(style: .heavy)
                gen.impactOccurred()
            }
        }
    }

    func triggerCombo(level: Int) {
        guard let scene = scene else { return }
        let labels = ["COMBO!", "DOUBLE COMBO!!", "AMAZING!!", "INCREDIBLE!!", "FEVER!!"]
        let idx = min(level - 1, labels.count - 1)
        let text = labels[idx]
        let colors: [SKColor] = [.white, .yellow, .cyan, .orange, .magenta]
        let color = colors[idx]

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 28 + CGFloat(idx * 6)
        label.fontColor = color
        label.position = CGPoint(x: scene.size.width / 2,
                                  y: scene.size.height / 2 + 60)
        label.zPosition = 200
        label.alpha = 0
        label.setScale(0.5)
        scene.addChild(label)

        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.1),
            SKAction.scale(to: 1.2, duration: 0.1)
        ])
        let hold = SKAction.scale(to: 1.0, duration: 0.1)
        let fly = SKAction.moveBy(x: 0, y: 40, duration: 0.6)
        let fade = SKAction.fadeOut(withDuration: 0.4)
        let remove = SKAction.removeFromParent()
        label.run(SKAction.sequence([appear, hold, SKAction.group([fly, SKAction.sequence([SKAction.wait(forDuration: 0.3), fade])]), remove]))

        if level >= 4 {
            triggerFever()
        }
    }

    // MARK: - Single Line Clear
    private func singleLineClear() {
        guard let scene = scene else { return }
        SoundManager.shared.playChime()

        // Screen flash
        let flash = SKSpriteNode(color: .white, size: scene.size)
        flash.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        flash.zPosition = 150
        flash.alpha = 0
        scene.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.25, duration: 0.05),
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))

        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()

        // Small sparkle burst
        spawnSparkles(at: CGPoint(x: scene.size.width / 2, y: scene.size.height / 2), count: 12, color: .cyan)
    }

    // MARK: - Double Line Clear
    private func doubleLineClear() {
        guard let scene = scene else { return }
        SoundManager.shared.playDoubleLineClear()

        scene.run(screenShake(intensity: 8, duration: 0.3))

        // Rainbow particles
        let colors: [SKColor] = [.red, .orange, .yellow, .green, .cyan, .blue, .magenta]
        for (i, color) in colors.enumerated() {
            let x = scene.size.width * CGFloat(i + 1) / CGFloat(colors.count + 1)
            spawnSparkles(at: CGPoint(x: x, y: scene.size.height / 2), count: 15, color: color)
        }

        // Flash
        let flash = SKSpriteNode(color: .yellow, size: scene.size)
        flash.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        flash.zPosition = 150
        flash.alpha = 0
        scene.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.35, duration: 0.06),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))

        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.impactOccurred()

        showAmazingText(text: "EXCELLENT!")
    }

    // MARK: - Triple+ Line Clear
    private func triplePlusClear(count: Int) {
        triggerFever()
    }

    // MARK: - Particles

    private func spawnSparkles(at position: CGPoint, count: Int, color: SKColor) {
        guard let scene = scene else { return }
        for _ in 0..<count {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            spark.fillColor = color
            spark.strokeColor = .clear
            spark.position = position
            spark.zPosition = 160
            scene.addChild(spark)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 60...200)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed
            let duration = Double.random(in: 0.4...0.9)

            spark.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: duration),
                    SKAction.fadeOut(withDuration: duration),
                    SKAction.scale(to: 0.1, duration: duration)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func spawnFireworks() {
        guard let scene = scene else { return }
        let x = CGFloat.random(in: scene.size.width * 0.1...scene.size.width * 0.9)
        let y = CGFloat.random(in: scene.size.height * 0.2...scene.size.height * 0.9)
        let center = CGPoint(x: x, y: y)

        let burstColors: [SKColor] = [.red, .orange, .yellow, .cyan, .magenta, .green, .white]
        let color = burstColors.randomElement()!
        spawnSparkles(at: center, count: 30, color: color)

        // Trailing star
        let star = SKLabelNode(text: "★")
        star.fontSize = CGFloat.random(in: 16...32)
        star.fontColor = color
        star.position = center
        star.zPosition = 165
        scene.addChild(star)
        star.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.5, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.4)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func spawnStarBurst() {
        guard let scene = scene else { return }
        let center = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        let starSymbols = ["★", "✦", "✧", "⚡", "◆", "●"]

        for i in 0..<20 {
            let sym = starSymbols.randomElement()!
            let node = SKLabelNode(text: sym)
            node.fontSize = CGFloat.random(in: 12...28)
            let hue = CGFloat(i) / 20.0
            node.fontColor = SKColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
            node.position = center
            node.zPosition = 170

            let angle = CGFloat(i) * (2 * .pi / 20)
            let radius = CGFloat.random(in: 80...250)
            let dx = cos(angle) * radius
            let dy = sin(angle) * radius
            let dur = Double.random(in: 0.5...1.0)

            scene.addChild(node)
            node.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: dur),
                    SKAction.rotate(byAngle: .pi * 2, duration: dur),
                    SKAction.sequence([
                        SKAction.scale(to: 1.5, duration: dur * 0.3),
                        SKAction.scale(to: 0, duration: dur * 0.7)
                    ]),
                    SKAction.fadeOut(withDuration: dur)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func spawnLightning() {
        guard let scene = scene else { return }
        for _ in 0..<4 {
            let start = CGPoint(
                x: CGFloat.random(in: 0...scene.size.width),
                y: scene.size.height
            )
            let end = CGPoint(
                x: CGFloat.random(in: 0...scene.size.width),
                y: CGFloat.random(in: 0...scene.size.height * 0.5)
            )
            drawLightningBolt(from: start, to: end)
        }
    }

    private func drawLightningBolt(from start: CGPoint, to end: CGPoint) {
        guard let scene = scene else { return }
        let path = CGMutablePath()
        path.move(to: start)

        let segments = 6
        let dx = (end.x - start.x) / CGFloat(segments)
        let dy = (end.y - start.y) / CGFloat(segments)

        for i in 1...segments {
            let nx = start.x + dx * CGFloat(i) + CGFloat.random(in: -20...20)
            let ny = start.y + dy * CGFloat(i) + CGFloat.random(in: -10...10)
            path.addLine(to: CGPoint(x: nx, y: ny))
        }

        let bolt = SKShapeNode(path: path)
        bolt.strokeColor = SKColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0)
        bolt.lineWidth = 2
        bolt.glowWidth = 4
        bolt.zPosition = 175
        scene.addChild(bolt)

        bolt.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.9, duration: 0.05),
            SKAction.fadeOut(withDuration: 0.25),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Text Effects

    private func showFeverText() {
        guard let scene = scene else { return }

        // Background glow label
        let shadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        shadow.text = "FEVER!!"
        shadow.fontSize = 72
        shadow.fontColor = SKColor(red: 1.0, green: 0.3, blue: 0.0, alpha: 0.5)
        shadow.position = CGPoint(x: scene.size.width / 2 + 3, y: scene.size.height / 2 - 3)
        shadow.zPosition = 198
        shadow.setScale(0.1)
        scene.addChild(shadow)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "FEVER!!"
        label.fontSize = 72
        label.fontColor = SKColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        label.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        label.zPosition = 200
        label.setScale(0.1)
        scene.addChild(label)

        let zoomIn = SKAction.scale(to: 1.3, duration: 0.2)
        let bounce = SKAction.scale(to: 0.95, duration: 0.1)
        let settle = SKAction.scale(to: 1.1, duration: 0.08)
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.12),
            SKAction.scale(to: 1.0, duration: 0.12)
        ])
        let hold = SKAction.wait(forDuration: 0.5)
        let exit = SKAction.group([
            SKAction.scale(to: 3.0, duration: 0.4),
            SKAction.fadeOut(withDuration: 0.4)
        ])
        let remove = SKAction.removeFromParent()

        let seq = SKAction.sequence([zoomIn, bounce, settle, SKAction.repeat(pulse, count: 3), hold, exit, remove])
        label.run(seq)
        shadow.run(seq.copy() as! SKAction)

        // Rotating rainbow letters
        let letters = ["F","E","V","E","R","!","!"]
        let feverColors: [SKColor] = [.red, .orange, .yellow, .green, .cyan, .blue, .magenta]
        for (i, letter) in letters.enumerated() {
            let x = scene.size.width * 0.15 + CGFloat(i) * (scene.size.width * 0.12)
            let lNode = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            lNode.text = letter
            lNode.fontSize = 36
            lNode.fontColor = feverColors[i]
            lNode.position = CGPoint(x: x, y: scene.size.height * 0.25)
            lNode.zPosition = 202
            lNode.alpha = 0
            lNode.setScale(0.1)
            scene.addChild(lNode)

            let delay = SKAction.wait(forDuration: Double(i) * 0.05)
            let appear = SKAction.group([
                SKAction.fadeIn(withDuration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.15),
                SKAction.moveBy(x: 0, y: 20, duration: 0.15)
            ])
            let spin = SKAction.rotate(byAngle: .pi * 4, duration: 1.0)
            let floatUp = SKAction.moveBy(x: 0, y: 60, duration: 1.2)
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            lNode.run(SKAction.sequence([
                delay,
                appear,
                SKAction.group([spin, floatUp, SKAction.sequence([SKAction.wait(forDuration: 0.7), fadeOut])]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func showAmazingText(text: String) {
        guard let scene = scene else { return }
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 40
        label.fontColor = .yellow
        label.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.65)
        label.zPosition = 200
        label.setScale(0.3)
        label.alpha = 0
        scene.addChild(label)

        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.1),
                SKAction.scale(to: 1.1, duration: 0.15)
            ]),
            SKAction.scale(to: 1.0, duration: 0.08),
            SKAction.wait(forDuration: 0.4),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 50, duration: 0.5),
                SKAction.fadeOut(withDuration: 0.4)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Rainbow Background Flash
    private func rainbowBackgroundFlash() {
        guard let scene = scene else { return }
        let colors: [SKColor] = [
            SKColor(red: 1, green: 0, blue: 0, alpha: 0.3),
            SKColor(red: 1, green: 0.5, blue: 0, alpha: 0.3),
            SKColor(red: 1, green: 1, blue: 0, alpha: 0.3),
            SKColor(red: 0, green: 1, blue: 0, alpha: 0.3),
            SKColor(red: 0, green: 0.5, blue: 1, alpha: 0.3),
            SKColor(red: 0.5, green: 0, blue: 1, alpha: 0.3),
        ]

        for (i, color) in colors.enumerated() {
            let flash = SKSpriteNode(color: color, size: scene.size)
            flash.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
            flash.zPosition = 140
            flash.alpha = 0
            scene.addChild(flash)
            let delay = Double(i) * 0.08
            flash.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.fadeIn(withDuration: 0.05),
                SKAction.fadeOut(withDuration: 0.1),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Screen Shake
    func screenShake(intensity: CGFloat, duration: Double) -> SKAction {
        let count = Int(duration / 0.04)
        var actions: [SKAction] = []
        for _ in 0..<count {
            let dx = CGFloat.random(in: -intensity...intensity)
            let dy = CGFloat.random(in: -intensity...intensity)
            actions.append(SKAction.moveBy(x: dx, y: dy, duration: 0.04))
        }
        actions.append(SKAction.move(to: .zero, duration: 0.05))
        return SKAction.sequence(actions)
    }
}
