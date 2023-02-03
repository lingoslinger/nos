//
//  NosTests.swift
//  NosTests
//
//  Created by Matthew Lorentz on 1/31/23.
//

import XCTest
import CoreData
import secp256k1
import secp256k1_bindings
@testable import Nos

final class NosTests: XCTestCase {
    
    let pubKey = "npub1xfesa80u4duhetursrgfde2gm8he3ua0xqq9gtujwx53483mqqqsg0cyaj"
    let pubKeyHex = "32730e9dfcab797caf8380d096e548d9ef98f3af3000542f9271a91a9e3b0001"
    let privateKeyHex = "69222a82c30ea0ad472745b170a560f017cb3bcc38f927a8b27e3bab3d8f0f19"
    let privateKeyNSec = "nsec1dy3z4qkrp6s263e8gkchpftq7qtukw7v8ruj029j0ca6k0v0puvs2e22yy"

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testParseSampleData() throws {
        // Arrange
        let sampleData = try Data(contentsOf: Bundle.current.url(forResource: "sample_data", withExtension: "json")!)
        let sampleEventID = "afc8a1cf67bddd12595c801bdc8c73ec1e8dfe94920f6c5ae5575c433722840e"
        
        // Act
        let events = try Event.parse(jsonData: sampleData, in: PersistenceController(inMemory: true))
        let sampleEvent = try XCTUnwrap(events.first(where: { $0.identifier == sampleEventID }))
        
        // Assert
        XCTAssertEqual(events.count, 142)
        XCTAssertEqual(sampleEvent.signature, "31c710803d3b77cb2c61697c8e2a980a53ec66e980990ca34cc24f9018bf85bfd2b0669c1404f364de776a9d9ed31a5d6d32f5662ac77f2dc6b89c7762132d63")
        XCTAssertEqual(sampleEvent.kind, 1)
        XCTAssertEqual(sampleEvent.tags?.count, 0)
        XCTAssertEqual(sampleEvent.author?.hex, "d0a1ffb8761b974cec4a3be8cbcb2e96a7090dcf465ffeac839aa4ca20c9a59e")
        XCTAssertEqual(sampleEvent.content, "Spent today on our company retreat talking a lot about Nostr. The team seems very keen to build something in this space. It’s exciting to be opening our minds to so many possibilities after being deep in the Scuttlebutt world for so long.")
        XCTAssertEqual(sampleEvent.createdAt?.timeIntervalSince1970, 1674624689)
    }
    
    func testTagJSONRepresentation() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let testContext = persistenceController.container.viewContext
        let tag = Tag(entity: NSEntityDescription.entity(forEntityName: "Tag", in: testContext)!, insertInto: testContext)
        tag.identifier = "x"
        tag.metadata = ["blah", "blah", "foo"] as NSObject
        
        XCTAssertEqual(tag.jsonRepresentation, ["x", "blah", "blah", "foo"])
    }
    
    func testSerializedEventForSigning() throws {
        // Arrange
        let persistenceController = PersistenceController(inMemory: true)
        let testContext = persistenceController.container.viewContext
        let event = try createTestEvent(in: testContext)
        let expectedString = """
        [0,"32730e9dfcab797caf8380d096e548d9ef98f3af3000542f9271a91a9e3b0001",1675264762,1,[["p","d0a1ffb8761b974cec4a3be8cbcb2e96a7090dcf465ffeac839aa4ca20c9a59e"]],"Testing nos #[0]"]
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Act
        let actualString = String(data: try JSONSerialization.data(withJSONObject: event.serializedEventForSigning), encoding: .utf8)
        
        // Assert
        XCTAssertEqual(actualString, expectedString)
    }
    
    func testIdentifierCalcuation() throws {
        // Arrange
        let persistenceController = PersistenceController(inMemory: true)
        let testContext = persistenceController.container.viewContext
        let event = try createTestEvent(in: testContext)
        
        // Act
        XCTAssertEqual(try event.calculateIdentifier(), "931b425e55559541451ddb99bd228bd1e0190af6ed21603b6b98544b42ee3317")
        
    }
    
    func testSigning() throws {
        // Arrange
        let expectedEvent =
        """
        {
          "kind": 1,
          "content": "Testing nos #[0]",
          "tags": [
            [
              "p",
              "d0a1ffb8761b974cec4a3be8cbcb2e96a7090dcf465ffeac839aa4ca20c9a59e"
            ]
          ],
          "created_at": 1675264762,
          "pubkey": "32730e9dfcab797caf8380d096e548d9ef98f3af3000542f9271a91a9e3b0001",
          "id": "931b425e55559541451ddb99bd228bd1e0190af6ed21603b6b98544b42ee3317",
          "sig": "79862bd81b316411c23467632239750c97f3aa974593c01bd61d2ca85eedbcfd9a18886b0dad1c17b2e8ceb231db37add136fc23120b45aa5403d6fd2d693e9b"
        }
        """
        
        let persistenceController = PersistenceController(inMemory: true)
        let testContext = persistenceController.container.viewContext
        let event = try createTestEvent(in: testContext)
        
        // Act
        try event.sign(withKey: privateKeyHex)
        
        // Assert
        XCTAssertEqual(event.identifier, "931b425e55559541451ddb99bd228bd1e0190af6ed21603b6b98544b42ee3317")
        XCTExpectFailure("I think the signature is non-deterministic. Update this test after we write code to verify signatures.")
        XCTAssertEqual(event.signature, "79862bd81b316411c23467632239750c97f3aa974593c01bd61d2ca85eedbcfd9a18886b0dad1c17b2e8ceb231db37add136fc23120b45aa5403d6fd2d693e9b")
    }

    // MARK: - Helpers
    
    private func createTestEvent(in context: NSManagedObjectContext) throws -> Event {
        let event = Event(entity: NSEntityDescription.entity(forEntityName: "Event", in: context)!, insertInto: context)
        event.createdAt = Date(timeIntervalSince1970: TimeInterval(1675264762))
        event.content = "Testing nos #[0]"
        event.kind = 1
        
        let author = PubKey(entity: NSEntityDescription.entity(forEntityName: "PubKey", in: context)!, insertInto: context)
        author.hex = pubKeyHex
        event.author = author
        
        let tag = Tag(entity: NSEntityDescription.entity(forEntityName: "Tag", in: context)!, insertInto: context)
        tag.identifier = "p"
        tag.metadata = ["d0a1ffb8761b974cec4a3be8cbcb2e96a7090dcf465ffeac839aa4ca20c9a59e"] as NSObject
        event.tags = NSOrderedSet(array: [tag])
        return event
    }
}
