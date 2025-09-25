//
//  ContentView.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/19.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = SharedStore.listViewModel
    @ObservedObject var globalModel = SharedStore.globalModel
    let appVersion = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header View
            HStack(spacing: 0) {
                Image("Itraffic-logo-text")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 18)
                
                Text("v\(appVersion)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                    .offset(y: 1)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "https://github.com/9ouu/ITraffic-monitor-for-mac")!)
                    }) {
                        Image("github")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 17, height: 17)
                    }

                    // --- 新增的网络图标按钮 ---
                    Button(action: {
                        // 打开活动监视器
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                    }) {
                        Image(systemName: "network")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 17, height: 17)
                    }
                    
                    Button(action: AppDelegate.quit) {
                        Image(systemName: "xmark.seal.fill")
                            .frame(width: 17, height: 17)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .frame(height: 40)
            
            Divider()

            // MARK: - Processes List
            List {
                ForEach(viewModel.items) { item in
                    ProcessRow(viewModel: viewModel, processEntity: item)
                        // 由 listRowInsets 统一控制所有行的边距
                        .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                }
            }
            .listStyle(PlainListStyle())
            .frame(height: 410)
            
        }
        .frame(width: 410) // 按要求调整宽度
        .background(.thinMaterial)
        .onChange(of: globalModel.viewShowing) { isShowing in
            if !isShowing {
                // 当程序关闭时，自动合上所有展开的信息
                viewModel.collapseAllItems()
            }
        }
     }
}

// MARK: - NetworkConnectionCard
struct NetworkConnectionCard: View {
    let processEntity: ProcessEntity
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                    
                    Text("网络连接")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))
            
            Divider()
                .opacity(0.3)
            
            // 网络连接内容
            NetworkConnectionsView(processEntity: processEntity)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

struct ProcessRow: View {
    @ObservedObject var viewModel: ListViewModel
    var processEntity: ProcessEntity
    @State private var isHovering = false
  
    var body: some View {
        let appInfo = getAppInfo(pid: processEntity.pid, name: processEntity.name)
        
        VStack(alignment: .leading, spacing: 4) {
            Button(action: {
                viewModel.toggle(item: processEntity)
            }) {
                HStack(alignment: .center, spacing: 0) {
                    HStack(spacing: 4) {
                        Image(nsImage: appInfo?.icon ?? NSImage())
                            .resizable()
                            .frame(width: 22, height: 22)
                        
                        Text(appInfo?.name ?? processEntity.name)
                            .font(.system(size: 13))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .help(appInfo?.name ?? processEntity.name)
                    }
                    .frame(width: 180, alignment: .leading)
                    
                    Spacer()
                    
                    HStack(spacing: 5) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.blue)
                                .frame(width: 12, height: 12)
                            Text(formatBytes(bytes: processEntity.outBytes))
                                .font(.system(size: 11).monospacedDigit())
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .frame(width: 80, alignment: .leading)

                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.green)
                                .frame(width: 12, height: 12)
                            Text(formatBytes(bytes: processEntity.inBytes))
                                .font(.system(size: 11).monospacedDigit())
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .frame(width: 80, alignment: .leading)
                    }
                }
                .background(isHovering ? Color.primary.opacity(0.1) : Color.clear)
                .cornerRadius(6)
                .onHover { hovering in
                    self.isHovering = hovering
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if processEntity.isExpanded {
                VStack(spacing: 0) {
                    // 顶部间距
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 8)
                    
                    VStack(spacing: 12) {
                        // 应用信息卡片
                        VStack(spacing: 10) {
                            // 包名信息
                            DetailInfoRow(
                                icon: "app.badge",
                                iconColor: .blue,
                                title: "包名",
                                content: processEntity.bundleIdentifier ?? "N/A",
                                isSelectable: true
                            )
                            
                            // PID信息
                            DetailInfoRow(
                                icon: "number.circle",
                                iconColor: .orange,
                                title: "PID",
                                content: "\(processEntity.pid)",
                                isSelectable: true,
                                actionType: .pid,
                                processEntity: processEntity
                            )
                            
                            // 路径信息
                            DetailInfoRow(
                                icon: "folder",
                                iconColor: .green,
                                title: "路径",
                                content: processEntity.executableURL ?? "N/A",
                                isMultiline: true,
                                isSelectable: true,
                                actionType: .path
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                )
                        )
                        
                        // 网络连接卡片
                        NetworkConnectionCard(processEntity: processEntity)
                    }
                    .padding(.horizontal, 12)
                    
                    // 底部间距
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
                .animation(.easeInOut(duration: 0.2), value: processEntity.isExpanded)
            }
        }
    }
}


// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = ListViewModel()
        let mockProcess = ProcessEntity(pid: 123, name: "ShortApp", inBytes: 12345, outBytes: 67890)
        let anotherProcess = ProcessEntity(pid: 456, name: "Another Very Very Long Example App Name", inBytes: 987, outBytes: 1234567)
        mockViewModel.items = [mockProcess, anotherProcess, mockProcess]
        
        return ContentView(viewModel: mockViewModel)
    }
}

// MARK: - NetworkConnectionsView
struct NetworkConnectionsView: View {
    let processEntity: ProcessEntity
    @State private var connections: [NetworkConnection] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("获取连接信息...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            } else if connections.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("无活动连接")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    // 分组显示TCP和UDP连接
                    let tcpConnections = connections.filter { $0.protocolType.contains("TCP") }
                    let udpConnections = connections.filter { $0.protocolType.contains("UDP") }
                    
                    // 显示TCP连接
                    if !tcpConnections.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(tcpConnections.prefix(4)) { connection in
                                NetworkConnectionRow(connection: connection)
                            }
                            
                            if tcpConnections.count > 4 {
                                HStack {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.6))
                                    
                                    Text("还有 \(tcpConnections.count - 4) 个TCP连接")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                                .padding(.leading, 8)
                                .padding(.top, 2)
                            }
                        }
                    }
                    
                    // 显示UDP连接
                    if !udpConnections.isEmpty {
                        if !tcpConnections.isEmpty {
                            Divider()
                                .opacity(0.3)
                                .padding(.vertical, 4)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(udpConnections.prefix(3)) { connection in
                                NetworkConnectionRow(connection: connection)
                            }
                            
                            if udpConnections.count > 3 {
                                HStack {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.6))
                                    
                                    Text("还有 \(udpConnections.count - 3) 个UDP连接")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                                .padding(.leading, 8)
                                .padding(.top, 2)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadNetworkConnections()
        }
    }
    
    private func loadNetworkConnections() {
        isLoading = true
        
        DispatchQueue.global(qos: .background).async {
            let networkConnections = getNetworkConnections(for: processEntity.pid)
            
            DispatchQueue.main.async {
                self.connections = networkConnections
                self.isLoading = false
            }
        }
    }
}

// MARK: - NetworkConnectionRow
struct NetworkConnectionRow: View {
    let connection: NetworkConnection
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 6) {
            // 协议标识
            Text(connection.protocolType)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(protocolColor(connection.protocolType))
                .cornerRadius(3)
            
            // 连接信息
            if connection.state == "LISTEN" {
                HStack(spacing: 4) {
                    Image(systemName: "ear")
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                    
                    Text("监听 :\(connection.localPort)")
                        .font(.system(size: 10).monospaced())
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    // 连接方向指示器
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                    
                    // 本地地址（简化显示）
                    if connection.localAddress != "*" && connection.localAddress != "0.0.0.0" {
                        Text(":\(connection.localPort)")
                            .font(.system(size: 9).monospaced())
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    
                    // 国旗和远程地址
                    HStack(spacing: 2) {
                        if let flag = connection.countryFlag {
                            Text(flag)
                                .font(.system(size: 11))
                        }
                        
                        Text(formatRemoteAddress(connection.remoteAddress, connection.remotePort))
                            .font(.system(size: 10).monospaced())
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            
            Spacer()
            
            // 状态指示器
            HStack(spacing: 4) {
                // 状态图标
                Image(systemName: stateIcon(connection.state))
                    .font(.system(size: 8))
                    .foregroundColor(connectionStateColor(connection.state))
                
                // 状态文本
                Text(localizedState(connection.state))
                    .font(.system(size: 9))
                    .foregroundColor(connectionStateColor(connection.state))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(connectionStateColor(connection.state).opacity(0.1))
                    .cornerRadius(2)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            self.isHovering = hovering
        }
    }
    
    private func protocolColor(_ protocol: String) -> Color {
        switch `protocol` {
        case "TCP":
            return .blue
        case "UDP":
            return .orange
        case "TCP6":
            return .purple
        case "UDP6":
            return .pink
        default:
            return .gray
        }
    }
    
    private func connectionStateColor(_ state: String) -> Color {
        switch state {
        case "ESTABLISHED":
            return .green
        case "LISTEN":
            return .blue
        case "TIME_WAIT", "CLOSE_WAIT", "FIN_WAIT1", "FIN_WAIT2":
            return .orange
        case "CLOSED", "CLOSING":
            return .red
        case "SYN_SENT", "SYN_RCVD":
            return .yellow
        default:
            return .gray
        }
    }
    
    private func stateIcon(_ state: String) -> String {
        switch state {
        case "ESTABLISHED":
            return "checkmark.circle.fill"
        case "LISTEN":
            return "ear.fill"
        case "TIME_WAIT", "CLOSE_WAIT":
            return "clock.fill"
        case "CLOSED", "CLOSING":
            return "xmark.circle.fill"
        case "SYN_SENT", "SYN_RCVD":
            return "arrow.triangle.2.circlepath"
        default:
            return "questionmark.circle"
        }
    }
    
    private func localizedState(_ state: String) -> String {
        switch state {
        case "ESTABLISHED":
            return "已连接"
        case "LISTEN":
            return "监听"
        case "TIME_WAIT":
            return "等待"
        case "CLOSE_WAIT":
            return "关闭等待"
        case "FIN_WAIT1", "FIN_WAIT2":
            return "结束等待"
        case "CLOSED":
            return "已关闭"
        case "CLOSING":
            return "关闭中"
        case "SYN_SENT":
            return "连接中"
        case "SYN_RCVD":
            return "接收中"
        default:
            return state
        }
    }
    
    private func formatRemoteAddress(_ address: String, _ port: String) -> String {
        if address == "*" {
            return "*"
        }
        
        // 简化显示常见端口
        let commonPorts = [
            "80": "HTTP",
            "443": "HTTPS",
            "53": "DNS",
            "22": "SSH",
            "21": "FTP",
            "25": "SMTP",
            "110": "POP3",
            "143": "IMAP",
            "993": "IMAPS",
            "995": "POP3S"
        ]
        
        if let serviceName = commonPorts[port] {
            return "\(address):\(serviceName)"
        }
        
        return "\(address):\(port)"
    }
}

// MARK: - DetailInfoRow
struct DetailInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let content: String
    var isMultiline: Bool = false
    var isSelectable: Bool = false
    var actionType: ActionType = .none
    var processEntity: ProcessEntity? = nil
    @State private var isHovering = false
    
    enum ActionType {
        case none
        case path
        case pid
    }
    
    var body: some View {
        HStack(alignment: isMultiline ? .top : .center, spacing: 12) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.1))
                )
            
            // 内容
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                if isMultiline {
                    Text(content)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                } else {
                    if isSelectable {
                        Text(content)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    } else {
                        Text(content)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            
            Spacer()
            
            // 功能按钮组
            HStack(spacing: 6) {
                // 复制按钮
                if isSelectable {
                    Button(action: {
                        copyToClipboard(text: content)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .opacity(isHovering ? 1.0 : 0.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("复制")
                }
                
                // 特定功能按钮
                switch actionType {
                case .path:
                    Button(action: {
                        openPath(path: content)
                    }) {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                            .opacity(isHovering ? 1.0 : 0.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("打开路径")
                    
                case .pid:
                    Button(action: {
                        if let entity = processEntity {
                            killProcess(pid: entity.pid)
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            .opacity(isHovering ? 1.0 : 0.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("终止进程")
                    
                case .none:
                    EmptyView()
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovering = hovering
            }
        }
    }
}
