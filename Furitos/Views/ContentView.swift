import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var score: Int = 0
    @State private var isGameOver: Bool = false
    @State private var scene: GameScene = ContentView.makeScene()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Score bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FURITOS")
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(red: 0.0, green: 0.8, blue: 1.0))
                        Text("SCORE: \(score)")
                            .font(.system(size: 22, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button(action: restartGame) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 0.0, green: 0.8, blue: 1.0))
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Game view
                SpriteView(scene: scene)
                    .ignoresSafeArea(edges: .horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom bar: Ad
                HStack {
                    Spacer()
                    BannerAdView(adUnitID: AdConfig.bannerAdUnitID)
                        .frame(width: 320, height: 50)
                    Spacer()
                }
                .frame(height: 50)
                .background(Color.black)
                .padding(.bottom, 4)
            }

            // Game Over overlay
            if isGameOver {
                gameOverOverlay
            }
        }
        .onAppear {
            setupScene()
        }
    }

    // MARK: - Game Over Overlay
    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 44, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.2, blue: 0.2))

                VStack(spacing: 6) {
                    Text("SCORE")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("\(score)")
                        .font(.system(size: 52, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 40)
                .background(Color.white.opacity(0.08))
                .cornerRadius(16)

                Button(action: restartGame) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text("PLAY AGAIN")
                    }
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.0, green: 0.9, blue: 1.0), Color(red: 0.0, green: 0.5, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(30)
                    .shadow(color: Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.6), radius: 12)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.07, green: 0.07, blue: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.4), lineWidth: 1.5)
                    )
            )
            .shadow(color: .black.opacity(0.6), radius: 30)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeOut(duration: 0.3), value: isGameOver)
    }

    // MARK: - Setup
    private static func makeScene() -> GameScene {
        let scene = GameScene()
        scene.scaleMode = .resizeFill
        return scene
    }

    private func setupScene() {
        scene.onScoreChanged = { newScore in
            DispatchQueue.main.async {
                score = newScore
            }
        }
        scene.onGameOver = {
            DispatchQueue.main.async {
                withAnimation { isGameOver = true }
            }
        }
    }

    private func restartGame() {
        withAnimation { isGameOver = false }
        score = 0
        scene.resetGame()
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
