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
