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

    var gravityDirection: GravityDirection { currentDirection }

    func start() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.05
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            self.processAcceleration(data.acceleration)
        }
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
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
