import Foundation
import Darwin

enum ReverseDNS {
    // Blocking PTR lookup through the system resolver; many routers answer with DHCP host names.
    static func lookup(_ ip: String) -> String? {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        guard inet_pton(AF_INET, ip, &address.sin_addr) == 1 else { return nil }
        var buffer = [CChar](repeating: 0, count: 1025)
        let status = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getnameinfo($0, socklen_t(MemoryLayout<sockaddr_in>.size),
                            &buffer, socklen_t(buffer.count), nil, 0, NI_NAMEREQD)
            }
        }
        guard status == 0 else { return nil }
        return DeviceIdentity.cleanHostname(String(cString: buffer), ip: ip)
    }
}


enum ForwardDNS {
    // Run on a worker queue: getaddrinfo may block beyond the scan's own deadline.
    static func addresses(for domain: String) -> [String] {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(domain, nil, &hints, &result) == 0, let first = result else { return [] }
        defer { freeaddrinfo(first) }
        var addresses = Set<String>()
        var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let item = cursor {
            if let pointer = item.pointee.ai_addr, item.pointee.ai_family == AF_INET {
                let address = pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                let number = UInt32(bigEndian: address.sin_addr.s_addr)
                if IPv4Range.isScannable(number) { addresses.insert(IPv4Range.string(number)) }
            }
            cursor = item.pointee.ai_next
        }
        return addresses.sorted { IPv4Range.number($0)! < IPv4Range.number($1)! }
    }
}
