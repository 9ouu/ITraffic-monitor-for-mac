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
        .frame(width: 385) // 按要求调整宽度
        .background(.thinMaterial)
        .onChange(of: globalModel.viewShowing) { isShowing in
            if !isShowing {
                // 当程序关闭时，自动合上所有展开的信息
                viewModel.collapseAllItems()
            }
        }
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
            .contextMenu {
                Button(action: {
                    killProcess(pid: processEntity.pid)
                }) {
                    HStack {
                        Image(systemName: "x.circle.fill")
                        Text("Kill 程序")
                    }
                }
                
                Button(action: {
                    openPath(path: processEntity.executableURL)
                }) {
                    HStack {
                        Image(systemName: "waveform.path.ecg.magnifyingglass")
                        Text("打开路径")
                    }
                }
                
                Button(action: {
                    copyToClipboard(text: processEntity.executableURL ?? "N/A")
                }) {
                    HStack {
                        Image(systemName: "document.on.document")
                        Text("复制路径")
                    }
                }
                
                Button(action: {
                    copyToClipboard(text: processEntity.bundleIdentifier ?? "N/A")
                }) {
                    HStack {
                        Image(systemName: "document.on.document.fill")
                        Text("复制包名")
                    }
                }
            }
            
            if processEntity.isExpanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 6)
                    
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            // 包名行
                            HStack(spacing: 0) {
                                Text("包名:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .trailing)
                                
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 5)
                                
                                Text(processEntity.bundleIdentifier ?? "N/A")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // PID行
                            HStack(spacing: 0) {
                                Text("PID:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .trailing)
                                
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 5)
                                
                                Text("\(processEntity.pid)".replacingOccurrences(of: ",", with: ""))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // Path行
                            HStack(alignment: .top, spacing: 0) {
                                Text("Path:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .trailing)
                                
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 5)
                                
                                Text(processEntity.executableURL ?? "N/A")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(10)
                                    .truncationMode(.middle)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 12)
                    }
                    
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 6)
                }
                .background(Color.primary.opacity(0.05))
                .cornerRadius(6)
                .transition(.opacity)
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
