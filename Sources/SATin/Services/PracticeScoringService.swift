import Foundation

struct PracticeScoreBreakdown {
    let accuracyScore: Double
    let difficultyScore: Double
    let speedScore: Double
    let finalScore: Double
}

struct PracticeScoringService {
    func score(attempts: [(isCorrect: Bool, difficulty: Difficulty, timeSeconds: Double)]) -> PracticeScoreBreakdown {
        guard !attempts.isEmpty else {
            return .init(accuracyScore: 0, difficultyScore: 0, speedScore: 0, finalScore: 0)
        }

        let correctAttempts = attempts.filter { $0.isCorrect }
        let accuracy = Double(correctAttempts.count) / Double(attempts.count)
        let accuracyScore = accuracy * 100

        let difficultyScore: Double
        if correctAttempts.isEmpty {
            difficultyScore = 0
        } else {
            difficultyScore = correctAttempts.map { $0.difficulty.weightScore }.reduce(0, +) / Double(correctAttempts.count)
        }

        let avgTime = attempts.map(\.timeSeconds).reduce(0, +) / Double(attempts.count)
        let speedScore = speedScoreFrom(avgTimeSeconds: avgTime, accuracy: accuracy)

        let final = accuracyScore * 0.6 + difficultyScore * 0.2 + speedScore * 0.2
        return .init(accuracyScore: accuracyScore, difficultyScore: difficultyScore, speedScore: speedScore, finalScore: final)
    }

    private func speedScoreFrom(avgTimeSeconds: Double, accuracy: Double) -> Double {
        let baseline: Double = 75
        if avgTimeSeconds <= baseline {
            return accuracy < 0.6 ? 65 : 92
        }
        if avgTimeSeconds <= 110 {
            return 80
        }
        if avgTimeSeconds <= 150 {
            return 65
        }
        return 45
    }
}
