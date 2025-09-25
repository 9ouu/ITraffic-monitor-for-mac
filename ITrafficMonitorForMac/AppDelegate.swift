//
//  AppDelegate.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/19.
//

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    static var popover: NSPopover!
    var statusBarItem: NSStatusItem!
    var contentView: ContentView!
    @ObservedObject var globalModel = SharedStore.globalModel
    
    static func quit() {
        NSApplication.shared.terminate(self)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.contentView = ContentView()
        let statusBarView = AnyView(StatusBarView())
        let network = Network()
        
        // Create the popover
        AppDelegate.popover = NSPopover()
        AppDelegate.popover.contentSize = NSSize(width: 300, height: 420)
        AppDelegate.popover.behavior = .transient
//        popover.contentViewController = NSHostingController(rootView: contentView.withGlobalEnvironmentObjects())
        
//        NSApp.activate(ignoringOtherApps: true)
        
        AppDelegate.popover.behavior = .transient
        AppDelegate.popover.animates = false
        // Create the status item
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))

        if let button = self.statusBarItem.button {
            button.action = #selector(togglePopover(_:))
            let view = NSHostingView(rootView: statusBarView)
            // 将宽度从 60 减少到 55
            view.setFrameSize(NSSize(width: 55, height: NSStatusBar.system.thickness))
            button.subviews.forEach { $0.removeFromSuperview() }
            button.addSubview(view)
            // 将状态栏项目长度从 60 减少到 55
            self.statusBarItem.length = 55
        }
        
        network.startListenNetwork()
        
        // 启动缓存清理定时器
        startCacheCleanupTimer()
    }

    
    @objc func togglePopover(_ sender: AnyObject?) {
        print("click")
        self.globalModel.viewShowing = true
        NSApp.activate(ignoringOtherApps: true)
        
        if let button = self.statusBarItem.button {
            if AppDelegate.popover.isShown {
                AppDelegate.popover.performClose(sender)
            } else {
                if globalModel.controllerHaveBeenReleased == true {
                    print("new controller")
                    AppDelegate.popover.contentViewController = NSHostingController(rootView: self.contentView.withGlobalEnvironmentObjects())
                    AppDelegate.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY) // to avoid the child windows could not be create in the first time
                }
                
                if let parentWindow = NSApp.windows.first,
                   let popoverVCWindow = AppDelegate.popover.contentViewController?.view.window,
                   let childWindows = parentWindow.childWindows {
                    if !childWindows.contains(popoverVCWindow) {
                        parentWindow.addChildWindow(popoverVCWindow, ordered: .above)
                    }
                } else {
                    print("Failed to add child window")
                }

                
                AppDelegate.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                AppDelegate.popover.contentViewController?.view.viewDidMoveToWindow()
                AppDelegate.popover.contentViewController?.view.window?.becomeKey()
                AppDelegate.popover.contentViewController?.view.window?.makeKey()
                
                globalModel.controllerHaveBeenReleased = false
            }
        }
    }
    
    func applicationWillResignActive(_ aNotification: Notification)
    {
        print("lost focus")
        self.globalModel.viewShowing = false
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        print("applicationWillTerminate")
        
        // 停止缓存清理定时器
        stopCacheCleanupTimer()
    }

}
