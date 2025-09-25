//
//  ProcessEntity.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/23.
//
import Cocoa
import Foundation

struct NetworkConnection: Identifiable {
    var id = UUID()
    var localAddress: String
    var localPort: String
    var remoteAddress: String
    var remotePort: String
    var protocolType: String // TCP, UDP
    var state: String // ESTABLISHED, LISTEN, etc.
    var countryCode: String? // 国家代码，如 "CN", "US"
    var countryFlag: String? // 国旗 emoji
}

struct ProcessEntity: Identifiable {
    var id = UUID()
    
    public var pid: Int;
    public var name: String;
    public var inBytes: Int;
    public var outBytes: Int;
    public var icon: NSImage?;
    public var bundleIdentifier: String?;
    public var executableURL: String?;
    public var networkConnections: [NetworkConnection] = []
    public var isExpanded: Bool = false
    
    public init(pid: Int, name: String, inBytes: Int, outBytes: Int) {
        self.pid = pid
        self.name = name
        self.inBytes = inBytes
        self.outBytes = outBytes
        self.icon = nil
        self.bundleIdentifier = nil
        self.executableURL = nil
    }
}
