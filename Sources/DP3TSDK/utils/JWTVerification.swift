/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import Foundation
import SwiftJWT

/// A class or structure conforming to the standard JWT content required by DP3T SDK
public protocol DP3TClaims: Claims {
    /// (Issuer) Claim
    var iss: String { get }
    /// (Issued At) Claim
    var iat: Date { get }
    /// (Expiration Time) Claim
    var exp: Date { get }
    /// (hash algorithm) Claim
    var hashAlg: String { get }
    /// (http body content hash) Claim
    var contentHash: String { get }
}

/// A JWT token verifier
public class DP3TJWTVerifier {
    private let jwtVerifier: JWTVerifier
    /// The HTTP Header field key of the JWT Token
    public let jwtTokenHeaderKey: String

    /// Initializes a verifier with a public key and the corresponding HTTP header field key
    ///
    /// - note: This function is only available as of `iOS 11` because it uses Elliptic Keys with SHA 256 that are only supported on `iOS 11 +`
    ///
    /// - Parameters:
    ///   - publicKey: The public key to verify the JWT signiture
    ///   - jwtTokenHeaderKey: The HTTP Header field key of the JWT Token
    public init(publicKey: Data, jwtTokenHeaderKey: String) {
        jwtVerifier = JWTVerifier.es256(publicKey: publicKey)
        self.jwtTokenHeaderKey = jwtTokenHeaderKey
    }

    /// Verify and return the claims from the JWT token
    ///
    /// Validate the time based standard JWT claims.
    /// This function checks that the "exp" (expiration time) is in the future
    /// and the "iat" (issued at) and "nbf" (not before) headers are in the past,
    ///
    /// - Parameters:
    ///   - httpResponse: The HTTP Response containing the JWT Token header field
    ///   - httpBody: The HTTP body returned
    ///   - claimsLeeway: The time in seconds that the JWT can be invalid but still accepted to account for clock differences.
    /// - Throws: `DP3TNetworkingError` in case of validation failures
    /// - Returns: The verified claims
    @discardableResult
    public func verify<ClaimType: DP3TClaims>(claimType: ClaimType.Type, httpResponse: HTTPURLResponse, httpBody: Data, claimsLeeway _: TimeInterval = 10) throws -> ClaimType {
        guard let jwtString = httpResponse.value(forHeaderField: jwtTokenHeaderKey) else {
            throw DP3TNetworkingError.jwtSignatureError(code: 1, debugDescription: "No JWT Token found in the provided response header field \(jwtTokenHeaderKey)")
        }
        do {
            let jwt = try JWT<ClaimType>(jwtString: jwtString, verifier: jwtVerifier)
            let validationResult = jwt.validateClaims(leeway: 10)
            guard validationResult == .success else {
                throw DP3TNetworkingError.jwtSignatureError(code: 2, debugDescription: "JWT signature don't match")
            }

            // Verify the hash
            let claimContentHash = Data(base64Encoded: jwt.claims.contentHash)
            let computedContentHash = Crypto.sha256(httpBody)
            guard claimContentHash == computedContentHash else {
                throw DP3TNetworkingError.jwtSignatureError(code: 4, debugDescription: "Content Hash missmatch")
            }

            return jwt.claims

        } catch let error as JWTError {
            throw DP3TNetworkingError.jwtSignatureError(code: 5, debugDescription: "Generic JWC framework error \(error.localizedDescription)")
        }
    }
}
