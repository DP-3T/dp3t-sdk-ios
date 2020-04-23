/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

@testable import DP3TSDK
import XCTest

final class CryptoModuleTest: XCTestCase {

    func testGenerateEphIDs() {
        let store = KeyStoreMock()
        let crypto: DP3TCryptoModule = try! DP3TCryptoModule(store: store)
        let allEphsOfToday = try! DP3TCryptoModule.createEphIDs(secretKey: crypto.getSecretKeyForPublishing(onsetDate: Date())!.1)
        let currentEphID = try! crypto.getCurrentEphID()
        var matchingCount = 0
        for ephID in allEphsOfToday {
            XCTAssert(ephID.count == CryptoConstants.keyLenght)
            if ephID == currentEphID {
                matchingCount += 1
            }
        }
        XCTAssert(matchingCount == 1)
    }

    func testStorageEphIDs() {
        let store = KeyStoreMock()
        let crypto: DP3TCryptoModule = try! DP3TCryptoModule(store: store)
        let currentEphID = try! crypto.getCurrentEphID()
        XCTAssertNotNil(store.ephIDs)
        XCTAssertTrue(store.ephIDs!.ephIDs.contains(currentEphID))
        XCTAssertEqual(currentEphID, try! crypto.getCurrentEphID())
    }

    func testGenerationEphsIdsWithAndorid() {
        let base64SecretKey = "kII4qPNuq5STANO8KUs7+/JiGhiSfJZYrL58eXpDzhk="
        let base64EncodedEphIDs = [
    "930QsNuTdtYUPqN2T5Cf1Q==",
    "i1x2+0f2LgCtw2fXjuiv2g==",
    "JUYSxt8h2XvXI50twtYsbg==",
    "Cbf3eJ2UOhQL9UqLbELwGQ==",
    "ouHe41hdky6Nq2QsYxOVeg==",
    "vraohkWxDMpJk+o93075vg==",
    "EkiKnfDRss5abHOD6WSlgA==",
    "cLNOcNsWbyTnD3teG52DlA==",
    "KXnYlKI0x6CKHwrMCX7lzg==",
    "G8uxMcdt80YX7vp9z2a8XA==",
    "V8F62iXKwAVFKL2IyAW6xQ==",
    "zglsu/ou24zwAexVDc+7og==",
    "NI8Q65NlCCt4FW+dwnMK8g==",
    "qhKSB7ifz3Kkq+Z5RC1jkw==",
    "OfvekcLZClxcRYhQUY0fKg==",
    "bNQtZavfZe33lMrMAUIRcA==",
    "fNIa5JHspKdRRXLc3N9irQ==",
    "4+JNxLrSQ2ecZhsQZBvAyg==",
    "wUSERjxQXKnsa/pwtfdpfg==",
    "kj4aRda2OASTSsAf8qNgwA==",
    "c/DDzegKPjr+vLmsNLu2kg==",
    "kKnoZ8rrBBQ0UljdYAQ5Cw==",
    "cfv5ayi9gSqoE9WVX7gNTQ==",
    "zZ7j/u07Bf4Hj3uhGu8KDg==",
    "fq2BqXpKLQ93DU1/5NmPWg==",
    "qq0NPYz+7tnB7jVQ8EAaVQ==",
    "Ql2+0GK50IPCAPRi0KLK+Q==",
    "5sOIA9UcP3OjcWtjCNttkg==",
    "uuLsf/+o5sjevUGBw6/F+A==",
    "iG9TOK7/V1tt0io2wFfVJQ==",
    "XGJ8yY6KMIQ5xHOEoCRbiA==",
    "aZ/nvZLI4otKSArCKL1XvQ==",
    "nvUfKVAANE5lvD3BHMxDXg==",
    "8pCkQ2m3B7TMN1MhrW5FDg==",
    "TZTmq3nh3N61UbpYhJqYDw==",
    "vpii9Hv45mqa6f24iDShUw==",
    "2oZsn59vsfLj0BwR2a2WRw==",
    "bLeudOWd+oiEqiZCtGqoTA==",
    "ifeIWfZzVcFtq3QlWg2VYQ==",
    "ZzSeibxKFt3ngAIZyH76QA==",
    "ducOZpwX1v4hWbqd6Ru57g==",
    "nIy8+jj5pJNd5yWh/8lnbA==",
    "0DuSTLeG5X9dJyFs8afWqA==",
    "Bskq3MLXQj++7SjQZ32Wkw==",
    "wxhmQt9rcNwaglIyYZXeKA==",
    "8yKm+vi9pJvHigBr98iNOw==",
    "I5sqDcKeWdxny0c+zcDBhg==",
    "1UIN4qB7YdPEUmDv2Re3rw==",
    "44gMimbWzzoBIy8HUWUMlQ==",
    "pg0CnAVPHCksnp6ZF0MIoA==",
    "wQu1LukKSN60x28R+J5c/A==",
    "Wsm6baao7KjPprW3lZO6Ng==",
    "3O+jStm51g5yefp/drIkDQ==",
    "mvN3ZrPt0ZgFCaCpu70stg==",
    "EcQxW/bCbmlIj2EbjH93ug==",
    "DiIrzdVnQOSxSqo0AgcoDA==",
    "Boyp8DxO1Yk28D0wjzStTQ==",
    "EADucqFnYoNj+mRznpTMpg==",
    "JkNZHC2pXzCcJhONdV5Psw==",
    "xDfW/RYnfCtOgNi6eNpypA==",
    "R3VCJhqR2pOsGcN/iIs7og==",
    "Mll2X3NJaI1l3FLyph5dsw==",
    "2z8XZDym/Kd4XTl/VUnuiA==",
    "o8l9avA0jUorbhVvPkq1nQ==",
    "hrj2vJABQMVmHhh4XRSdXA==",
    "m81F9khVPby4NT3Lylq+yg==",
    "BxU1mjtuAO1Vgg22V1U5Cg==",
    "geVwEwzzAWC3USHEu7Gjrg==",
    "7UrHbWU/YYK0mcTixjAN7A==",
    "QIB54d0UAgSC8r17odvR1g==",
    "DKw/Zet13WxrJU5RAqDtKw==",
    "GF8Sjw+PwDfUphdbLcddWw==",
    "Pqab4NmigvVOTPo09/g14A==",
    "R+8T7hxRkt5RBB3E0qbYVw==",
    "yMV7eeMHRb5uq4oXgxc95A==",
    "PxFfGZ6+Q/GwSrcNbmAJ7Q==",
    "JGdNz/SI7tzToi5IsikWiA==",
    "lCiPk33wjfGI1FwKrXlKkQ==",
    "wWDu/tcX9IDt/Urnwz5S0g==",
    "MSjnTLwp9z6qIJxGklwPPw==",
    "q5nOt4w2gwO7m58pc3Y6LQ==",
    "30+i6bJjzmOWMa0uUPH9LA==",
    "LFRzsMzsPclZz/kcZ0lLBg==",
    "rpzzDEpSO0PMjM0J7Hgsnw==",
    "laBKyyaGPAqEaVxgc3GehQ==",
    "VnKfNI5aOLgq/31nxbPXbw==",
    "amwmBg/6RiDALr7HN5y26w==",
    "UQsYYoPmG6P38wLcUls69A==",
    "/B9V3P3dk6g73AuO2iEgzQ==",
    "NyzRLWbi2qjaOfV3z5+h4Q==",
    "CE27nYPVfdvVfHdKsn/mlg==",
    "mQbnYtyPVxxK89QcYNJy0A==",
    "eKEuOoPWwn56Shi6tWKc8Q==",
    "SQyDTJ3glvWD4q6A7fHwnA==",
    "jPXUiTlc5SPbX0xOO8Z67Q==",
    "PYAvlT76Z2ftKWwN8OQj8Q=="]

        let androidEphIds: Set<Data> = Set(base64EncodedEphIDs.compactMap{ Data(base64Encoded: $0) } )
        let allEphID: Set<Data> = Set(try! DP3TCryptoModule.createEphIDs(secretKey: Data(base64Encoded: base64SecretKey)!))
        XCTAssertEqual(allEphID, androidEphIds)
    }

    func testReset() {
        let store = KeyStoreMock()
        var crypto: DP3TCryptoModule? = try! DP3TCryptoModule(store: store)
        let ephID = try! crypto!.getCurrentEphID()

        crypto!.reset()
        crypto = nil
        crypto = try! DP3TCryptoModule(store: store)

        let newEphID = try! crypto!.getCurrentEphID()

        XCTAssertNotEqual(ephID, newEphID)
    }

    func testTokenToday() {
        let key = "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs="
        let token = "ZN5cLwKOJVAWC7caIHskog=="
        testKeyAndTokenToday(Data(base64Encoded: key)!, Data(base64Encoded: token)!, found: true)
    }

    func testWrongTokenToday() {
        let key = "yJNfwAP8UaF+BZKbUiVwhUghLz60SOqPE0I="
        let token = "lTSYc/ER08HD1/ucwBJOiDLDEYiJruKqTHCiOFavzwA="
        testKeyAndTokenToday(Data(base64Encoded: key)!, Data(base64Encoded: token)!, found: false)
    }

    func testSecretKeyPushlishing() {
        let store1 = KeyStoreMock()
        let crypto1: DP3TCryptoModule = try! DP3TCryptoModule(store: store1)
        let token = try! crypto1.getCurrentEphID()
        _ = try! crypto1.getCurrentSK(day: DayDate(date: Date().addingTimeInterval(1 * .day)))
        _ = try! crypto1.getCurrentSK(day: DayDate(date: Date().addingTimeInterval(2 * .day)))
        _ = try! crypto1.getCurrentSK(day: DayDate(date: Date().addingTimeInterval(3 * .day)))

        let (day, key) = (try! crypto1.getSecretKeyForPublishing(onsetDate: Date()))!

        XCTAssertEqual(day, DayDate())

        let date = Date()

        let contacts: [Contact] = [Contact(identifier: nil, ephID: token, day: DayDate(date: date), associatedKnownCase: nil)]
        let store2 = KeyStoreMock()
        let crypto2: DP3TCryptoModule = try! DP3TCryptoModule(store: store2)

        let matchedContacts = try! crypto2.checkContacts(secretKey: key,
                                                  onsetDate: DayDate(),
                                                  bucketDate: Date().addingTimeInterval(.day),
                                                  getContacts: { (_) -> ([Contact]) in
                                                    contacts
        })

       XCTAssertEqual(matchedContacts, contacts)
    }

    func testSecretKeyPushlishingOnsetAfterContact() {
        let store1 = KeyStoreMock()
        let crypto1: DP3TCryptoModule = try! DP3TCryptoModule(store: store1)
        let token = try! crypto1.getCurrentEphID()
        _ = try! crypto1.getCurrentSK(day: DayDate(date: Date().addingTimeInterval(1 * .day)))
        _ = try! crypto1.getCurrentSK(day: DayDate(date: Date().addingTimeInterval(2 * .day)))
        _ = try! crypto1.getCurrentSK(day: DayDate(date: Date().addingTimeInterval(3 * .day)))

        let key = (try! crypto1.getSecretKeyForPublishing(onsetDate: Date().addingTimeInterval(.day)))!.1


        let date = Date()

        let contacts: [Contact] = [Contact(identifier: nil, ephID: token, day: DayDate(date: date), associatedKnownCase: nil)]

        let store2 = KeyStoreMock()
        let crypto2: DP3TCryptoModule = try! DP3TCryptoModule(store: store2)

        let matchedContacts = try! crypto2.checkContacts(secretKey: key,
                                                   onsetDate: DayDate(),
                                                   bucketDate: Date().addingTimeInterval(.day),
                                                   getContacts: { (_) -> ([Contact]) in
                                                     contacts
         })

        XCTAssertEqual(matchedContacts, [])
    }

    func testKeyAndTokenToday(_ key: Data, _ token: Data, found: Bool) {
        let store = KeyStoreMock()
        let crypto: DP3TCryptoModule = try! DP3TCryptoModule(store: store)

        let date = Date()
        let contacts: [Contact] = [Contact(identifier: nil, ephID: token, day: DayDate(date: date), associatedKnownCase: nil)]

        let matchedContacts = try! crypto.checkContacts(secretKey: key,
                                                  onsetDate: DayDate(date: Date().addingTimeInterval(-1 * .day)),
                                                  bucketDate: Date(),
                                                  getContacts: { (_) -> ([Contact]) in
                                                    contacts
        })

        XCTAssertEqual(!matchedContacts.isEmpty, found)
    }

    func testGenerationEphsIDsMultiDayRegular(){
        let store = KeyStoreMock()
        let crypto: DP3TCryptoModule = try! DP3TCryptoModule(store: store)

        for day in 0..<100 {
            let date = Date().addingTimeInterval(Double(day) * .day)
            let day = DayDate(date: date)
            let secretKey = try! crypto.getCurrentSK(day: day)
            XCTAssertLessThanOrEqual(store.keys.count, CryptoConstants.numberOfDaysToKeepData)
            XCTAssertEqual(day, store.keys.first!.day)
            XCTAssertEqual(secretKey, store.keys.first!.keyData)
            
            let ephID = try! crypto.getCurrentEphID(timestamp: date)
            XCTAssertNotNil(store.ephIDs)
            XCTAssertEqual(store.ephIDs!.ephIDs.count, CryptoConstants.numberOfEpochsPerDay)
            XCTAssertEqual(store.ephIDs!.day, day)
            XCTAssertTrue(store.ephIDs!.ephIDs.contains(ephID))
        }
    }

    func testGenerationEphsIDsMultiDayIrregular(){
        let store = KeyStoreMock()
        let crypto: DP3TCryptoModule = try! DP3TCryptoModule(store: store)

        var currentDay = 0
        for _ in 0..<100 {
            currentDay += Int.random(in: 0...14)
            let date = Date().addingTimeInterval(Double(currentDay) * .day)
            let day = DayDate(date: date)
            let secretKey = try! crypto.getCurrentSK(day: day)
            XCTAssertLessThanOrEqual(store.keys.count, CryptoConstants.numberOfDaysToKeepData)
            XCTAssertEqual(day, store.keys.first!.day)
            XCTAssertEqual(secretKey, store.keys.first!.keyData)

            let ephID = try! crypto.getCurrentEphID(timestamp: date)
            XCTAssertNotNil(store.ephIDs)
            XCTAssertEqual(store.ephIDs!.ephIDs.count, CryptoConstants.numberOfEpochsPerDay)
            XCTAssertEqual(store.ephIDs!.day, day)
            XCTAssertTrue(store.ephIDs!.ephIDs.contains(ephID))
        }
    }

    func testGetSecretKeyMultipleTimes(){
        let store = KeyStoreMock()
        let crypto: DP3TCryptoModule = try! DP3TCryptoModule(store: store)
        for _ in 0..<10 {
            let sec1 = try! crypto.getCurrentSK()
            let sec2 = try! crypto.getCurrentSK()
            XCTAssertEqual(sec1, sec2)
            XCTAssert(store.keys.count == 1)
        }
    }

    func testGetSecretKeyFromPastStored(){
        let store = KeyStoreMock()
        let crypto: DP3TCryptoModule = try! DP3TCryptoModule(store: store)
        let today = DayDate()
        let tomorrow = DayDate(date: Date().addingTimeInterval(.day))
        let secTomorrow = try! crypto.getCurrentSK(day: tomorrow)
        let secToday = try! crypto.getCurrentSK(day: today)
        XCTAssert(store.keys.count == 2)
        XCTAssertNotEqual(secTomorrow, secToday)
    }

    func testGetSecretKeyFromPastNotStored(){
        let store = KeyStoreMock()
        let crypto: DP3TCryptoModule = try! DP3TCryptoModule(store: store)
        let yesterday = DayDate(date: Date().addingTimeInterval(.day * -1))
        XCTAssertThrowsError(try crypto.getCurrentSK(day: yesterday))
    }


    func testEpochDuration(){
        let store = KeyStoreMock()
        let crypto: DP3TCryptoModule = try! DP3TCryptoModule(store: store)
        let now = Date()
        let ephIDNow: EphID = try! crypto.getCurrentEphID(timestamp: now)
        let nextEpoch = now.addingTimeInterval(CryptoConstants.secondsPerEpoch)
        let ephIDNext: EphID = try! crypto.getCurrentEphID(timestamp: nextEpoch)
        XCTAssertNotEqual(ephIDNow, ephIDNext)
    }

    func testPublishingCorrectSecretKey(){
        let store1 = KeyStoreMock()
        let crypto1: DP3TCryptoModule = try! DP3TCryptoModule(store: store1)
        let _ = try! crypto1.getCurrentEphID()
        _ = try! crypto1.getCurrentSK(day: DayDate(date: Date().addingTimeInterval(1 * .day)))
        _ = try! crypto1.getCurrentSK(day: DayDate(date: Date().addingTimeInterval(2 * .day)))
        _ = try! crypto1.getCurrentSK(day: DayDate(date: Date().addingTimeInterval(3 * .day)))

        let (day, _) = (try! crypto1.getSecretKeyForPublishing(onsetDate: Date().addingTimeInterval(-10 * .day)))!

        XCTAssertEqual(day, DayDate())
    }

    static var allTests = [
        ("testTokenToday", testTokenToday),
        ("testWrongTokenToday", testWrongTokenToday),
        ("testSecretKeyPushlishing", testSecretKeyPushlishing),
        ("testSecretKeyPushlishingOnsetAfterContact", testSecretKeyPushlishingOnsetAfterContact),
        ("testStorageEphIDs", testStorageEphIDs),
        ("testReset", testReset),
        ("generateEphIDs", testGenerateEphIDs),
        ("generateEphIDsAndroid", testGenerationEphsIdsWithAndorid),
        ("testGenerationEphsIDsMultiDayRegular", testGenerationEphsIDsMultiDayRegular),
        ("testGenerationEphsIDsMultiDayIrregular", testGenerationEphsIDsMultiDayIrregular),
        ("testGetSecretKeyMultipleTimes", testGetSecretKeyMultipleTimes),
        ("testGetSecretKeyFromPastStored", testGetSecretKeyFromPastStored),
        ("testGetSecretKeyFromPastNotStored", testGetSecretKeyFromPastNotStored),
        ("testEpochDuration", testEpochDuration)
    ]
}
