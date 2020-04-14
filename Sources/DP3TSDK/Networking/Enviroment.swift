/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// The environment of the app
public enum Enviroment {
    /// Production environment
    case prod
    /// A development environment
    case dev

    /// The endpoint for the discovery
    var discoveryEndpoint: URL {
        switch self {
        case .prod:
            return URL(string: "https://discovery.dpppt.org/discovery.json")!
        case .dev:
            return URL(string: "https://discovery.dpppt.org/discovery_dev.json")!
        }
    }
}
