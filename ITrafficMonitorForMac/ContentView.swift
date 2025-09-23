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
                // ... (此部分无须修改)
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

                    Button(action: {
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
            
            // MARK: - List Header
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 4) {
                    Spacer().frame(width: 22)
                    Text("Application")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // --- 修改 1: 给表头设定一个固定的宽度并左对齐 ---
                Text("Upload")
                    .frame(width: 85, alignment: .leading) // 使用固定宽度
                
                Text("Download")
                    .frame(width: 85, alignment: .leading) // 使用固定宽度
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
            .padding(.bottom, 5)

            Divider()

            // MARK: - Processes List
            List {
                ForEach(viewModel.items) { item in
                    ProcessRow(processEntity: item)
                        .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                }
            }
            .listStyle(PlainListStyle())
            .frame(height: 400)
            
        }
        .frame(width: 380)
        .background(.thinMaterial)
    }
}

struct ProcessRow: View {
    var processEntity: ProcessEntity
    @State private var isHovering = false
  
    var body: some View {
        let appInfo = getAppInfo(pid: processEntity.pid, name: processEntity.name)
        
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
            
            // --- 修改 2: 关键修改，实现整齐的左对齐 ---
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.blue)
                // 让 Text 自动填满 Hstack 中的剩余空间，并将其中的内容左对齐
                Text(formatBytes(bytes: processEntity.outBytes))
                    .font(.system(size: 12).monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 85, alignment: .leading) // 给整列一个固定的宽度

            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.green)
                // 同样地，让 Text 填满空间并左对齐
                Text(formatBytes(bytes: processEntity.inBytes))
                    .font(.system(size: 12).monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 85, alignment: .leading) // 给整列一个固定的宽度
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
    // ... (此部分无须修改)
    static var previews: some View {
        let mockViewModel = ListViewModel()
        let mockProcess = ProcessEntity(pid: 123, name: "ShortApp", inBytes: 12345, outBytes: 67890)
        let anotherProcess = ProcessEntity(pid: 456, name: "Another Very Very Long Example App Name", inBytes: 987, outBytes: 1234567)
        mockViewModel.items = [mockProcess, anotherProcess, mockProcess]
        
        return ContentView(viewModel: mockViewModel)
    }
}
