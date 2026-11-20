import Foundation

struct IPv4Range {
    let addresses: [String]
    let canonicalCIDR: String

    enum ValidationError: LocalizedError {
        case invalid, tooLarge, unsupported
        var errorDescription: String? {
            switch self {
            case .invalid: return AppLocalization.string("请输入有效 IPv4 CIDR，例如 192.168.1.0/24。")
            case .tooLarge: return AppLocalization.string("单次最多 1024 个地址，请使用 /22 或更小的范围。")
            case .unsupported: return AppLocalization.string("不支持未指定、回环、组播或保留 IPv4 地址。")
            }
        }
    }

    init(_ input: String) throws {
        let parts = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, let ip = Self.number(String(parts[0])),
              let prefix = Int(parts[1]), (0...32).contains(prefix) else {
            throw ValidationError.invalid
        }
        guard prefix >= 22 else { throw ValidationError.tooLarge }
        let mask = prefix == 32 ? UInt32.max : UInt32.max << (32 - prefix)
        let start = ip & mask
        let end = start | ~mask
        guard Self.isScannable(start), Self.isScannable(end) else { throw ValidationError.unsupported }
        canonicalCIDR = "\(Self.string(start))/\(prefix)"
        // /31 point-to-point and /32 host routes do not exclude endpoints.
        let first = prefix < 31 ? start + 1 : start
        let last = prefix < 31 ? end - 1 : end
        addresses = (first...last).map(Self.string)
    }

    // Discover the actual subnet independently of the scan-size/local-address policy.
    static func subnetCIDR(address: String, netmask: String) -> String? {
        guard let ip = number(address), let mask = number(netmask) else { return nil }
        let inverted = ~mask
        guard inverted & (inverted &+ 1) == 0 else { return nil }
        return "\(string(ip & mask))/\(mask.nonzeroBitCount)"
    }

    static func number(_ text: String) -> UInt32? {
        let octets = text.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return nil }
        var result: UInt32 = 0
        for octet in octets {
            guard !octet.isEmpty, octet.utf8.allSatisfy({ (48...57).contains($0) }),
                  let value = UInt32(octet), value <= 255 else { return nil }
            result = (result << 8) | value
        }
        return result
    }

    static func string(_ value: UInt32) -> String {
        [24, 16, 8, 0].map { String((value >> $0) & 255) }.joined(separator: ".")
    }

    static func isLocal(_ ip: UInt32) -> Bool {
        ip >> 24 == 10 || ip >> 20 == 0xAC1 ||
        ip >> 16 == 0xC0A8 || ip >> 16 == 0xA9FE
    }
}


extension IPv4Range {
    static func isScannable(_ ip: UInt32) -> Bool {
        ip >> 24 != 0 && ip >> 24 != 127 && ip >> 24 < 224
    }
}

// A domain is resolved once per scan; TCP and Web probes use that fixed address list.
struct ScanTarget {
    let label: String
    let addresses: [String]
    let domain: String?
    let isLocal: Bool

    enum ValidationError: LocalizedError {
        case invalidDomain
        var errorDescription: String? {
            AppLocalization.string("请输入 IPv4、CIDR 或域名（例如 example.com），不要包含协议、端口或路径。")
        }
    }

    init(_ input: String) throws {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("/") || IPv4Range.number(text) != nil {
            let range = try IPv4Range(text.contains("/") ? text : "\(text)/32")
            label = range.canonicalCIDR
            addresses = range.addresses
            domain = nil
            isLocal = addresses.allSatisfy { IPv4Range.isLocal(IPv4Range.number($0)!) }
            return
        }
        var name = text.lowercased()
        if name.hasSuffix(".") { name.removeLast() }
        let labels = name.split(separator: ".", omittingEmptySubsequences: false)
        guard name.utf8.count <= 253, labels.count >= 2,
              labels.last!.utf8.contains(where: { (97...122).contains($0) }),
              labels.allSatisfy({ label in
                  !label.isEmpty && label.utf8.count <= 63 && label.first != "-" && label.last != "-" &&
                  label.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }
              }) else { throw ValidationError.invalidDomain }
        label = name
        addresses = []
        domain = name
        isLocal = false
    }
}
