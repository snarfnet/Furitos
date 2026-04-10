import CoreMotion
import Foundation

enum GravityDirection {
    case down, up, left, right
}

class GyroManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private var currentDirection: GravityDirection = .down
    private var lastSwitchTime: TimeInterval = 0
    private let debounceDuration: TimeInterval = 0.5
    private let threshold: Double = 0.4

    var onGravityChanged: ((GravityDirection) -> Void)?
    var onShake: (() -> Void)?

    var gravityDirection: GravityDirection { currentDirection }

    // Shake detection
    private var lastShakeTime: TimeInterval = 0
    private let shakeCooldown: TimeInterval = 0.4
    private let shakeThreshold: Double = 2.5
    private var prevAccel: CMAcceleration?

    func start() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.03
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            self.processAcceleration(data.acceleration)
            self.detectShake(data.acceleration)
        }
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
        prevAccel = nil
    }

    private func detectShake(_ acc: CMAcceleration) {
        guard let prev = prevAccel else {
            prevAccel = acc
            return
        }
        let dx = acc.x - prev.x
        let dy = acc.y - prev.y
        let dz = acc.z - prev.z
        let jerk = sqrt(dx * dx + dy * dy + dz * dz)
        prevAccel = acc

        let now = Date().timeIntervalSince1970
        if jerk > shakeThreshold && now - lastShakeTime > shakeCooldown {
            lastShakeTime = now
            onShake?()
        }
    }

    private func processAcceleration(_ acc: CMAcceleration) {
        let now = Date().timeIntervalSince1970
        guard now - lastSwitchTime > debounceDuration else { return }

        let x = acc.x
        let y = acc.y

        let absX = abs(x)
        let absY = abs(y)

        guard max(absX, absY) > threshold else { return }

        let newDirection: GravityDirection
        if absY >= absX {
            newDirection = y < 0 ? .down : .up
        } else {
            newDirection = x > 0 ? .right : .left
        }

        if newDirection != currentDirection {
            currentDirection = newDirection
            lastSwitchTime = now
            onGravityChanged?(currentDirection)
        }
    }
}
