//
//  ContentView.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/19.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = SharedStore.listViewModel
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
                            .frame(width: 16, height: 16)
                    }
                    
                    Button(action: AppDelegate.quit) {
                        Image(systemName: "xmark.seal.fill")
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .frame(height: 40)
            
            // MARK: - List Header
            // --- 最终对齐方案 ---
            // 采用与 ProcessRow 完全一致的结构和边距
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 4) {
                    // 空白占位符，宽度与下方图标(22)一致
                    Spacer().frame(width: 22)
                    Text("Application")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Upload")
                    .frame(width: 75, alignment: .leading)
                
                Text("Download")
                    .frame(width: 75, alignment: .leading)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4) // 与下方 listRowInsets 的左右边距保持一致
            .padding(.bottom, 5)

            Divider()

            // MARK: - Processes List
            List {
                ForEach(viewModel.items) { item in
                    ProcessRow(processEntity: item)
                        // 由 listRowInsets 统一控制所有行的边距
                        .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                }
            }
            .listStyle(PlainListStyle())
            .frame(height: 410)
            
        }
        .frame(width: 370) // 按要求调整宽度
        .background(.thinMaterial)
    }
}

struct ProcessRow: View {
    var processEntity: ProcessEntity
    @State private var isHovering = false
  
    var body: some View {
        let appInfo = getAppInfo(pid: processEntity.pid, name: processEntity.name)
        
        // --- 最终对齐方案 ---
        // 移除所有 .padding 修饰符，由 List 的 listRowInsets 控制
        HStack(alignment: .center, spacing: 10) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.blue)
                Text(formatBytes(bytes: processEntity.outBytes))
                    .font(.system(size: 12).monospacedDigit())
            }
            .frame(width: 75, alignment: .leading)

            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.green)
                Text(formatBytes(bytes: processEntity.inBytes))
                    .font(.system(size: 12).monospacedDigit())
            }
            .frame(width: 75, alignment: .leading)
        }
        .background(isHovering ? Color.primary.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            self.isHovering = hovering
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
