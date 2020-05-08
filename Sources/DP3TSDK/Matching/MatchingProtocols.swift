/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// A delegate used to respond on DP3T events
protocol MatcherDelegate: class {
    /// We found a match
    func didFindMatch()
}

protocol Matcher: class {
    /// Delegate to notify on DP3T events
    var delegate: MatcherDelegate? { get set }

    func receivedNewKnownCaseData(_ data: Data, batchTimestamp: Date) throws

    func finalizeMatchingSession() throws
}
