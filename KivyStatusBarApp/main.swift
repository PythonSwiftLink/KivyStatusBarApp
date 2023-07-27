//
//  main.swift
//  KivyStatusBarApp
//
//  Created by MusicMaker on 26/07/2023.
//

import Foundation
import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// 2
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
