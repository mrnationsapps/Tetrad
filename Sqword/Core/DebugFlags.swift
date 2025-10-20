import Foundation
import SwiftUI
import Combine

#if DEBUG
final class DebugFlags: ObservableObject {
    // Persist between runs so you don’t keep retyping test values
    @AppStorage("debug.boardTest") var boardTest: Int = 0   // go forward or back in time from today
    @AppStorage("debug.boostTest") var boostTest: Int = 0   // start with extra boosts
}
#endif

