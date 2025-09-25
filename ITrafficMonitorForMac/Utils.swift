//
//  Utils.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/23.
//

import Foundation
import Cocoa

func formatBytes(bytes: Int) -> String {
    let kbyte = Float(bytes) / 1024
    if kbyte <= 0 {
        return "0 KB/s"
    }
    if kbyte < 1024 {
        return String(format:"%.1f KB/s", kbyte)
    }
    return String(format:"%.1f MB/s", kbyte / 1024)
}

struct AppInfo {
    var icon: NSImage
    var name: String?
    var updateTime: Int
    var bundleIdentifier: String?
    var executableURL: String?
}

struct ProcessInfoResult {
    var bundleIdentifier: String?
    var executablePath: String?
    var processName: String?
}

var APP_INFO_CACHE = [String : AppInfo]()
var CACHE_TTL = 3600

// 清理缓存的函数
func clearAppInfoCache() {
    APP_INFO_CACHE.removeAll()
    print("App info cache cleared")
}

func getAppInfo(pid: Int, name: String) -> AppInfo? {
    let timestamp = Int(NSDate().timeIntervalSince1970)
    
    let cacheKey = "\(name)\(pid)"
    let appInfoInCache = APP_INFO_CACHE[cacheKey]
    let updateTimeInCache = appInfoInCache?.updateTime ?? 0
    if appInfoInCache != nil && (timestamp - updateTimeInCache) < CACHE_TTL {
        return appInfoInCache!
    }
    
    // 首先尝试使用 NSRunningApplication
    let appIns = NSRunningApplication(processIdentifier: pid_t(pid))
    var bundleIdentifier = appIns?.bundleIdentifier
    var executableURL = appIns?.executableURL?.path
    var appName = appIns?.localizedName ?? name
    let icon = resize(image: (appIns?.icon ?? NSImage(named: "blank"))!, w: 16, h: 16)
    
    // 如果 NSRunningApplication 无法获取到信息，使用备用方法
    if bundleIdentifier == nil || executableURL == nil {
        let processInfo = getProcessInfoUsingPS(pid: pid)
        if bundleIdentifier == nil {
            bundleIdentifier = processInfo.bundleIdentifier
        }
        if executableURL == nil {
            executableURL = processInfo.executablePath
        }
        if appName == name && processInfo.processName != nil {
            appName = processInfo.processName!
        }
    }
    
    let result = AppInfo(icon: icon, name: appName, updateTime: timestamp, bundleIdentifier: bundleIdentifier, executableURL: executableURL)
    APP_INFO_CACHE[cacheKey] = result
    return result
}

func getProcessInfoUsingPS(pid: Int) -> ProcessInfoResult {
    var result = ProcessInfoResult()
    
    // 使用 ps 命令获取进程的完整路径
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/ps")
    task.arguments = ["-p", "\(pid)", "-o", "comm="]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    
    do {
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if !output.isEmpty {
                result.executablePath = output
                result.processName = URL(fileURLWithPath: output).lastPathComponent
                
                // 尝试从路径推断 bundle identifier
                if output.contains(".app/") {
                    result.bundleIdentifier = extractBundleIdentifierFromPath(path: output)
                } else {
                    // 为系统进程生成合理的 bundle identifier
                    result.bundleIdentifier = generateSystemProcessBundleId(path: output, processName: result.processName!)
                }
            }
        }
    } catch {
        print("Failed to get process info using ps: \(error)")
    }
    
    // 如果 ps 命令没有获取到路径，尝试使用 lsof 命令
    if result.executablePath == nil {
        result.executablePath = getExecutablePathUsingLsof(pid: pid)
        if let path = result.executablePath {
            result.processName = URL(fileURLWithPath: path).lastPathComponent
            if path.contains(".app/") {
                result.bundleIdentifier = extractBundleIdentifierFromPath(path: path)
            } else {
                result.bundleIdentifier = generateSystemProcessBundleId(path: path, processName: result.processName!)
            }
        }
    }
    
    return result
}

func getExecutablePathUsingLsof(pid: Int) -> String? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
    task.arguments = ["-p", "\(pid)", "-Fn"]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    
    do {
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                if line.hasPrefix("n") && line.contains("/") {
                    let path = String(line.dropFirst())
                    if FileManager.default.isExecutableFile(atPath: path) {
                        return path
                    }
                }
            }
        }
    } catch {
        print("Failed to get executable path using lsof: \(error)")
    }
    
    return nil
}

func extractBundleIdentifierFromPath(path: String) -> String? {
    // 从 .app 路径中提取 bundle identifier
    // 处理嵌套的 .app 路径，找到最后一个 .app
    let appRanges = path.ranges(of: ".app")
    guard !appRanges.isEmpty else { return nil }
    
    // 使用最后一个 .app 路径（最内层的应用）
    let lastAppRange = appRanges.last!
    let appPath = String(path[..<lastAppRange.upperBound])
    let appName = URL(fileURLWithPath: appPath).lastPathComponent
    let bundleName = appName.replacingOccurrences(of: ".app", with: "")
    
    // 尝试读取 Info.plist 文件获取真正的 bundle identifier
    let infoPlistPath = appPath + "/Contents/Info.plist"
    if let plistData = FileManager.default.contents(atPath: infoPlistPath),
       let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
       let bundleId = plist["CFBundleIdentifier"] as? String {
        return bundleId
    }
    
    // 如果无法读取 Info.plist，返回基于应用名称的推测
    return "com.unknown.\(bundleName.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: ""))"
}

func generateSystemProcessBundleId(path: String, processName: String) -> String {
    // 为系统进程生成合理的 bundle identifier
    if path.hasPrefix("/System/") {
        return "com.apple.system.\(processName.lowercased())"
    } else if path.hasPrefix("/usr/sbin/") || path.hasPrefix("/usr/bin/") {
        return "com.apple.system.\(processName.lowercased())"
    } else if path.hasPrefix("/Library/") {
        return "com.system.library.\(processName.lowercased())"
    } else if path.contains("/Frameworks/") {
        // 尝试从框架路径中提取更有意义的信息
        if let frameworkRange = path.range(of: ".framework") {
            let frameworkPath = String(path[..<frameworkRange.upperBound])
            let frameworkName = URL(fileURLWithPath: frameworkPath).lastPathComponent.replacingOccurrences(of: ".framework", with: "")
            return "com.framework.\(frameworkName.lowercased()).\(processName.lowercased())"
        }
        return "com.framework.\(processName.lowercased())"
    } else if path.hasPrefix("/private/") {
        return "com.system.private.\(processName.lowercased())"
    } else {
        return "com.process.\(processName.lowercased())"
    }
}

func getNetworkConnections(for pid: Int) -> [NetworkConnection] {
    var connections: [NetworkConnection] = []
    
    // 使用 lsof 获取所有网络连接，然后过滤指定 PID
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/sh")
    task.arguments = ["-c", "lsof -i -P -n | grep '\(pid)' | grep -E '(TCP|UDP)'"]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    
    do {
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            let lines = output.components(separatedBy: .newlines)
            
            for line in lines {
                if line.isEmpty { continue }
                
                // 解析每一行
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count >= 8 {
                    // 查找协议类型（TCP或UDP）
                    var protocolType = "TCP"
                    for component in components {
                        if component == "TCP" {
                            protocolType = "TCP"
                            break
                        } else if component == "UDP" {
                            protocolType = "UDP"
                            break
                        }
                    }
                    
                    // 找到连接信息（最后一个包含IP的部分）
                    for i in (0..<components.count).reversed() {
                        let component = components[i]
                        
                        if component.contains("->") {
                            // 已建立的连接
                            let parts = component.components(separatedBy: "->")
                            if parts.count == 2 {
                                let localPart = parseAddressPort(parts[0])
                                let remotePart = parseAddressPort(parts[1])
                                
                                // 获取远程IP的国家信息
                                let countryInfo = getCountryInfo(for: remotePart.address)
                                
                                connections.append(NetworkConnection(
                                    localAddress: localPart.address,
                                    localPort: localPart.port,
                                    remoteAddress: remotePart.address,
                                    remotePort: remotePart.port,
                                    protocolType: protocolType,
                                    state: "ESTABLISHED",
                                    countryCode: countryInfo.countryCode,
                                    countryFlag: countryInfo.flag
                                ))
                                break
                            }
                        } else if component.contains("(LISTEN)") {
                             // 跳过监听端口，不显示
                             break
                        } else if component.contains(":") && component.contains(".") {
                            // 可能是IP:端口格式
                            let parts = component.components(separatedBy: ":")
                            if parts.count == 2 && parts[0].contains(".") {
                                let localPart = parseAddressPort(component)
                                
                                connections.append(NetworkConnection(
                                    localAddress: localPart.address,
                                    localPort: localPart.port,
                                    remoteAddress: "*",
                                    remotePort: "*",
                                    protocolType: protocolType,
                                    state: "UNKNOWN",
                                    countryCode: nil,
                                    countryFlag: nil
                                ))
                                break
                            }
                        }
                    }
                }
            }
        }
    } catch {
        print("Failed to get network connections: \(error)")
    }
    
    return connections
}

func getCountryInfo(for ipAddress: String) -> (countryCode: String?, flag: String?) {
    // 简单的IP地址国家判断逻辑
    // 实际项目中可以使用更精确的GeoIP数据库
    
    if ipAddress == "*" || ipAddress.hasPrefix("127.") || ipAddress.hasPrefix("192.168.") || ipAddress.hasPrefix("10.") {
        return (nil, nil) // 本地地址
    }
    
    // 基于IP地址段的简单判断
    let components = ipAddress.components(separatedBy: ".")
    guard components.count == 4, let firstOctet = Int(components[0]) else {
        return ("UN", "🏳️") // 未知
    }
    
    switch firstOctet {
    case 1...2, 27, 39, 42, 49, 58, 59, 60, 61, 101, 103, 106, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125:
        return ("CN", "🇨🇳") // 中国
    case 8, 15, 34, 35, 50, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 96, 97, 98, 99, 100, 104, 107, 108, 173, 174, 184, 192, 198, 199, 204, 205, 206, 207, 208, 209, 216:
        return ("US", "🇺🇸") // 美国
    case 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 31, 32, 33, 37, 46, 51, 52, 53, 54, 55, 56, 57, 62, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95:
        return ("EU", "🇪🇺") // 欧洲
    case 126, 133, 150, 153, 163, 180, 182, 183, 202, 203, 210, 211, 218, 219, 220, 221, 222, 223:
        return ("JP", "🇯🇵") // 日本
    case 168, 175, 210:
        return ("KR", "🇰🇷") // 韩国
    case 14, 43, 45, 102, 129, 130, 131, 132, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 152, 171:
        return ("SG", "🇸🇬") // 新加坡
    default:
        return ("UN", "🌍") // 其他
    }
}

func countryCodeToFlag(_ countryCode: String) -> String {
    switch countryCode {
    case "CN": return "🇨🇳"
    case "US": return "🇺🇸"
    case "JP": return "🇯🇵"
    case "KR": return "🇰🇷"
    case "SG": return "🇸🇬"
    case "EU": return "🇪🇺"
    case "GB": return "🇬🇧"
    case "DE": return "🇩🇪"
    case "FR": return "🇫🇷"
    case "CA": return "🇨🇦"
    case "AU": return "🇦🇺"
    case "RU": return "🇷🇺"
    case "IN": return "🇮🇳"
    case "BR": return "🇧🇷"
    default: return "🌍"
    }
}

func parseSimpleConnection(from line: String, isListening: Bool) -> NetworkConnection? {
    // 查找TCP或UDP
    let protocolType = line.contains("TCP") ? "TCP" : "UDP"
    
    if isListening {
        // 解析监听端口：查找 (LISTEN) 前的地址
        if let listenRange = line.range(of: "(LISTEN)") {
            let beforeListen = String(line[..<listenRange.lowerBound])
            if let range = beforeListen.range(of: #"\d+\.\d+\.\d+\.\d+:\d+"#, options: .regularExpression, range: nil, locale: nil) {
                let addressPort = String(beforeListen[range])
                let parts = parseAddressPort(addressPort)
                
                return NetworkConnection(
                    localAddress: parts.address,
                    localPort: parts.port,
                    remoteAddress: "*",
                    remotePort: "*",
                    protocolType: protocolType,
                    state: "LISTEN"
                )
            }
        }
    } else {
        // 解析连接：查找 -> 模式
        if let arrowRange = line.range(of: "->") {
            let beforeArrow = String(line[..<arrowRange.lowerBound])
            let afterArrow = String(line[arrowRange.upperBound...])
            
            // 提取本地地址（从右往左找最后一个IP:端口）
            let localMatches = beforeArrow.matches(of: #/\d+\.\d+\.\d+\.\d+:\d+/#)
            if let lastLocalMatch = localMatches.last {
                let localAddress = String(lastLocalMatch.output)
                let localParts = parseAddressPort(localAddress)
                
                // 提取远程地址（从左往右找第一个IP:端口）
                if let remoteMatch = afterArrow.firstMatch(of: #/\d+\.\d+\.\d+\.\d+:\d+/#) {
                    let remoteAddress = String(remoteMatch.output)
                    let remoteParts = parseAddressPort(remoteAddress)
                    
                    // 提取状态
                    var state = "ESTABLISHED"
                    if let stateMatch = afterArrow.firstMatch(of: #/\([A-Z_]+\)/#) {
                        let stateStr = String(stateMatch.output)
                        state = stateStr.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
                    }
                    
                    return NetworkConnection(
                        localAddress: localParts.address,
                        localPort: localParts.port,
                        remoteAddress: remoteParts.address,
                        remotePort: remoteParts.port,
                        protocolType: protocolType,
                        state: state
                    )
                }
            }
        }
    }
    
    return nil
}

func parseNetstatConnection(from line: String, pid: Int) -> NetworkConnection? {
    // 合并所有空白字符分割的组件
    let allComponents = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    
    guard allComponents.count >= 10 else { return nil }
    
    let protocolType = allComponents[0].uppercased()
    guard protocolType == "TCP4" || protocolType == "TCP6" || protocolType == "UDP4" || protocolType == "UDP6" else { return nil }
    
    let localAddress = allComponents[3]
    let remoteAddress = allComponents[4]
    let state = allComponents[5]
    
    // 解析本地地址和端口
    let localPart = parseAddressPort(localAddress)
    let remotePart = parseAddressPort(remoteAddress)
    
    // 简化协议类型
    let simpleProtocol = protocolType.hasPrefix("TCP") ? "TCP" : "UDP"
    
    return NetworkConnection(
        localAddress: localPart.address,
        localPort: localPart.port,
        remoteAddress: remotePart.address,
        remotePort: remotePart.port,
        protocolType: simpleProtocol,
        state: state
    )
}

func parseNetworkConnection(from line: String) -> NetworkConnection? {
    let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    
    guard components.count >= 8 else { 
        return nil 
    }
    
    // 查找协议类型（TCP 或 UDP）
    var protocolIndex = -1
    var protocolType = ""
    for (index, component) in components.enumerated() {
        if component.uppercased() == "TCP" || component.uppercased() == "UDP" {
            protocolIndex = index
            protocolType = component.uppercased()
            break
        }
    }
    
    guard protocolIndex >= 0 && protocolIndex + 1 < components.count else { return nil }
    
    let connectionInfo = components[protocolIndex + 1]
    
    if connectionInfo.contains("->") {
        // 已建立的连接
        let parts = connectionInfo.components(separatedBy: "->")
        guard parts.count == 2 else { return nil }
        
        let localPart = parseAddressPort(parts[0])
        
        // 处理远程部分，可能包含状态信息
        var remotePart = parts[1]
        var state = "ESTABLISHED"
        
        // 检查是否有状态信息（在括号中）
        if let stateStart = remotePart.lastIndex(of: "("),
           let stateEnd = remotePart.lastIndex(of: ")") {
            let stateRange = remotePart.index(after: stateStart)..<stateEnd
            state = String(remotePart[stateRange])
            remotePart = String(remotePart[..<stateStart]).trimmingCharacters(in: .whitespaces)
        }
        
        let remoteAddressPort = parseAddressPort(remotePart)
        
        return NetworkConnection(
            localAddress: localPart.address,
            localPort: localPart.port,
            remoteAddress: remoteAddressPort.address,
            remotePort: remoteAddressPort.port,
            protocolType: protocolType,
            state: state
        )
    } else if connectionInfo.contains("LISTEN") || line.contains("LISTEN") {
        // 监听端口
        let localPart = parseAddressPort(connectionInfo.replacingOccurrences(of: " (LISTEN)", with: ""))
        
        return NetworkConnection(
            localAddress: localPart.address,
            localPort: localPart.port,
            remoteAddress: "*",
            remotePort: "*",
            protocolType: protocolType,
            state: "LISTEN"
        )
    }
    
    return nil
}

func parseAddressPort(_ addressPort: String) -> (address: String, port: String) {
    if let lastColonIndex = addressPort.lastIndex(of: ":") {
        let address = String(addressPort[..<lastColonIndex])
        let port = String(addressPort[addressPort.index(after: lastColonIndex)...])
        
        // 处理 IPv6 地址
        if address.hasPrefix("[") && address.hasSuffix("]") {
            return (String(address.dropFirst().dropLast()), port)
        }
        
        return (address.isEmpty ? "*" : address, port)
    }
    
    return (addressPort, "*")
}

func resize(image: NSImage, w: Int, h: Int) -> NSImage {
    let destSize = NSMakeSize(CGFloat(w), CGFloat(h))
    let newImage = NSImage(size: destSize)
    newImage.lockFocus()
    image.draw(in: NSMakeRect(0, 0, destSize.width, destSize.height), from: NSMakeRect(0, 0, image.size.width, image.size.height), operation: .colorBurn, fraction: CGFloat(1))
    newImage.unlockFocus()
    newImage.size = destSize
    return newImage
}

// MARK: - 右键菜单功能

func killProcess(pid: Int) {
    let task = Process()
    task.launchPath = "/bin/kill"
    task.arguments = ["-9", "\(pid)"]
    
    do {
        try task.run()
        task.waitUntilExit()
        print("Successfully killed process with PID: \(pid)")
    } catch {
        print("Failed to kill process with PID: \(pid), error: \(error)")
    }
}

func copyToClipboard(text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    print("Copied to clipboard: \(text)")
}

func openPath(path: String?) {
    guard let path = path, path != "N/A", !path.isEmpty else {
        print("Invalid path: \(path ?? "nil")")
        return
    }
    
    let url = URL(fileURLWithPath: path)
    let parentURL = url.deletingLastPathComponent()
    
    // 检查路径是否存在
    if FileManager.default.fileExists(atPath: parentURL.path) {
        NSWorkspace.shared.open(parentURL)
        print("Opened path: \(parentURL.path)")
    } else {
        print("Path does not exist: \(parentURL.path)")
    }
}
