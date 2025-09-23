//
//  StatusBarView.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/23.
//

import SwiftUI

struct StatusBarView: View {
    @ObservedObject var statusDataModel = SharedStore.statusDataModel
    
    var body: some View {
        // 使用 HStack 和 Spacer 将内容推向左侧
        HStack {
            // 使用VStack进行垂直布局，并设置所有子视图向左对齐 (.leading)
            VStack(alignment: .leading, spacing: 1) {
                
                // 上传（出站）行
                HStack(spacing: 4) { // 使用HStack水平排列箭头和文字
                    Image("arrow.up")
                        .resizable()
                        .frame(width: 6.5, height: 6.5) // 箭头大小设置为6.5
                    Text(formatBytes(bytes:statusDataModel.totalOutBytes))
                        .font(.system(size: 9))
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: true, vertical: false) // 新增：防止文字在水平方向被截断
                }
                
                // 下载（入站）行
                HStack(spacing: 4) {
                    Image("arrow.down")
                        .resizable()
                        .frame(width: 6.5, height: 6.5) // 箭头大小设置为6.5
                    Text(formatBytes(bytes:statusDataModel.totalInBytes))
                        .font(.system(size: 9))
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: true, vertical: false) // 新增：防止文字在水平方向被截断
                }
            }
            .padding(.leading, 2) // 给整个视图添加一点左边距，避免贴边
        }
    }
}

struct StatusBarView_Previews: PreviewProvider {
    static var previews: some View {
        StatusBarView()
            .environment(\.sizeCategory, .small)
    }
}
