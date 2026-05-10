import Foundation

enum GameEvent: Equatable {
    case none
    case normal
    case wild           // 2 played - wild card, pile not cleared
    case sevenPlayed    // 7 played - under-7 constraint set for next play
    case skip           // 8 played
    case reverse        // 9 played
    case burn           // 10 played or four-of-a-kind on top
    case pickup         // current player picked up the pile
    case failedFlip     // face-down flip was illegal; player took the pile
}
