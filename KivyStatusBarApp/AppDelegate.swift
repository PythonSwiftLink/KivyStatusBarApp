//
//  AppDelegate.swift
//  KivyStatusBarApp
//
//  Created by MusicMaker on 26/07/2023.
//

import Cocoa
import PythonLib
import PythonSwiftCore
import AppKit
import ServiceManagement
//@main


class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var loginCheck: NSMenuItem?

    func applicationWillFinishLaunching(_ notification: Notification) {
        _ = PythonHandler.shared
    }
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        print("applicationDidFinishLaunching")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "1.circle", accessibilityDescription: "1")
        }
        setupMenus()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func setupMenus() {
        // 1
        let menu = NSMenu()
        
        // 2
        let one = NSMenuItem(title: "One", action: #selector(didTapOne) , keyEquivalent: "1")
        menu.addItem(one)
        
        let login_check = NSMenuItem(title: "Run at Login", action: #selector(onLogin) , keyEquivalent: "2")
        login_check.state = .off
        statusItem.menu = menu
        menu.addItem(login_check)
        loginCheck = login_check
        
    }
    
    @objc func didTapOne() {
        PyRun_SimpleString("print(\"hello world\")")
    }

    @objc func onLogin() {
        guard let loginCheck = loginCheck else { return }
        switch loginCheck.state {
        case .on:
            loginCheck.state = .off
            if #available(macOS 13, *) {
                try? SMAppService.mainApp.unregister()
            } else {
                SMLoginItemSetEnabled("com.PythonSwiftLink.kivytest.KivyStatusBarApp" as CFString, false)
            }
            
            
        case .off:
            loginCheck.state = .on
            if #available(macOS 13, *) {
                try? SMAppService.mainApp.register()
            } else {
                SMLoginItemSetEnabled("com.PythonSwiftLink.kivytest.KivyStatusBarApp" as CFString, true)
            }
        default: return
            
        }
        
    }
}

