//
//  TutorialTypes.swift
//  Tetrad
//
//  Created by kevin nations on 10/4/25.
//

import SwiftUI

// Shared step machine for Level 1’s one-line helper
public enum L1Step: Equatable {
    case placeFirst, explainCost, promptBoost, done
}

// Hard-coded tutorial squares (so you don’t need a dictionary file)
public enum TutorialRows {
    public static let level1_2x2 = ["AT", "TO"]            // L1
    public static let level2_3x3 = ["APE", "PEN", "END"]    // L2
}
