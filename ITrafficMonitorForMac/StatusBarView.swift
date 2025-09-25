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
        // 使用 HStack 确保箭头和文字都有足够的空间
        HStack(spacing: 0) {
            // 使用VStack进行垂直布局，并设置所有子视图向左对齐 (.leading)
            VStack(alignment: .leading, spacing: 1) {
                
                // 上传（出站）行
                HStack(spacing: 3) {
                    Image("arrow.up")
                        .resizable()
                        .frame(width: 6.5, height: 6.5)
                        .aspectRatio(contentMode: .fit)
                    Text(formatBytes(bytes:statusDataModel.totalOutBytes))
                        .font(.system(size: 9).monospacedDigit())
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: true, vertical: false)
                        .lineLimit(1)
                }
                
                // 下载（入站）行
                HStack(spacing: 3) {
                    Image("arrow.down")
                        .resizable()
                        .frame(width: 6.5, height: 6.5)
                        .aspectRatio(contentMode: .fit)
                    Text(formatBytes(bytes:statusDataModel.totalInBytes))
                        .font(.system(size: 9).monospacedDigit())
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: true, vertical: false)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 3)
        }
    }
}

struct StatusBarView_Previews: PreviewProvider {
    static var previews: some View {
        StatusBarView()
            .environment(\.sizeCategory, .small)
    }
}
