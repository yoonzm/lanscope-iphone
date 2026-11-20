import XCTest
@testable import LanScopeCore

final class ScanTargetTests: XCTestCase {
    func testPublicAndLocalTargets() throws {
        let target = try ScanTarget(" 8.8.8.8 ")
        XCTAssertEqual(target.addresses, ["8.8.8.8"])
        XCTAssertEqual(target.label, "8.8.8.8/32")
        XCTAssertFalse(target.isLocal)
        XCTAssertNil(target.domain)
        XCTAssertEqual(try ScanTarget("8.8.8.9/31").addresses, ["8.8.8.8", "8.8.8.9"])
        XCTAssertEqual(try ScanTarget("172.32.0.1/24").addresses.count, 254)
        XCTAssertTrue(try ScanTarget("192.168.1.1").isLocal)
        XCTAssertTrue(try ScanTarget("169.254.1.0/24").isLocal)
        XCTAssertThrowsError(try ScanTarget("8.8.0.0/16"))
    }

    func testDomainNormalization() throws {
        let target = try ScanTarget(" EXAMPLE.COM. ")
        XCTAssertEqual(target.label, "example.com")
        XCTAssertEqual(target.domain, "example.com")
        XCTAssertTrue(target.addresses.isEmpty)
        XCTAssertFalse(target.isLocal)
        XCTAssertNoThrow(try ScanTarget("xn--fiqs8s.example"))
    }

    func testRejectsMalformedTargets() {
        for input in ["", "https://example.com", "example.com/path", "example.com:443",
                      "a..com", "-a.com", "a-.com", "a_b.com", "localhost", "999.1.1.1",
                      "::1", "example.com\r\nHost: other.com", String(repeating: "a", count: 64) + ".com"] {
            XCTAssertThrowsError(try ScanTarget(input), input)
        }
    }

    func testResolvedAddressPolicy() {
        for ip in ["0.0.0.0", "127.0.0.1", "224.0.0.1", "255.255.255.255"] {
            XCTAssertFalse(IPv4Range.isScannable(IPv4Range.number(ip)!))
        }
        for ip in ["8.8.8.8", "192.168.1.1", "169.254.1.1"] {
            XCTAssertTrue(IPv4Range.isScannable(IPv4Range.number(ip)!))
        }
    }
}
