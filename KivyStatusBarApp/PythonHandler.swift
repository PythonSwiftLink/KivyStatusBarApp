//
//  PythonHandler.swift
//  KivyStatusBarApp
//
//  Created by MusicMaker on 27/07/2023.
//

import Foundation
import Cocoa
import PythonLib
import PythonSwiftCore

fileprivate
func putenv(_ s: String) {
    let _count = s.utf8.count + 1
    let result = UnsafeMutablePointer<Int8>.allocate(capacity: _count)
    s.withCString { (baseAddress) in
        result.initialize(from: baseAddress, count: _count)
    }
    
    putenv(result)
}


private func pySwiftImports() {
    // add PySwiftMpdules to Python's import list
    for _import in PythonSwiftImportList {
        
        if PyImport_AppendInittab(_import.name, _import.module) == -1 {
            PyErr_Print()
            fatalError()
        }
    }
}

class PythonHandler {
    
    static let shared = PythonHandler()
    
    var ret: Int32 = 0
    var status: PyStatus
    var preconfig: PyPreConfig = .init()
    var config: PyConfig = .init()
    var python_home: String
    var app_module_name: String?
    var path: String
    var traceback_str: String?
    var wtmp_str: UnsafeMutablePointer<wchar_t>
    var app_module_str: String?
    var nslog_script: String?
    var app_module: PyPointer?
    var module: PyPointer?
    var module_attr: PyPointer?
    var method_args: PyPointer?
    var result: PyPointer?
    var exc_type: PyPointer?
    var exc_value: PyPointer?
    var exc_traceback: PyPointer?
    var systemExit_code: PyPointer?
    
    init() {
        guard let resourcePath = Bundle.main.resourcePath else { fatalError() }
        PyPreConfig_InitIsolatedConfig(&preconfig)
        PyConfig_InitIsolatedConfig(&config)
        //PythonHandler(argc: argc, argv: argv)
        preconfig.utf8_mode = 1
        // Don't buffer stdio. We want output to appears in the log immediately
        config.buffered_stdio = 0
        // Don't write bytecode; we can't modify the app bundle
        // after it has been signed.
        config.write_bytecode = 0
        // Isolated apps need to set the full PYTHONPATH manually.
        config.module_search_paths_set = 1
        
        putenv("KIVY_NO_ARGS=1")
        
        
        NSLog("Pre-initializing Python runtime...")
        status = Py_PreInitialize(&preconfig)
        if ((PyStatus_Exception(status)) != 0) {
            crash_dialog("Unable to pre-initialize Python interpreter: \(String(cString: status.err_msg))")
            PyConfig_Clear(&config)
            Py_ExitStatusException(status)
        }
        python_home = "\(resourcePath)/support/python-stdlib"
        
        NSLog("PythonHome: \(python_home)" )
        wtmp_str = Py_DecodeLocale(python_home, nil)
        var config_home = config.home
        status = PyConfig_SetString(&config, &config_home, wtmp_str)
        if ((PyStatus_Exception(status)) != 0) {
            crash_dialog( "Unable to set PYTHONHOME: \(String(cString: status.err_msg))")
            PyConfig_Clear(&config)
            Py_ExitStatusException(status)
        }
        PyMem_RawFree(wtmp_str)
        
        
        app_module_str = nil//.init(cString: getenv("BRIEFCASE_MAIN_MODULE"))
        if let app_module_str = app_module_str {
            app_module_name = app_module_str
            NSLog("app_module_name: \(app_module_name ?? "nil")")
        } else {
            app_module_name = Bundle.main.object(forInfoDictionaryKey: "MainModule") as? String//[[NSBundle mainBundle] objectForInfoDictionaryKey:@"MainModule"];
            if (app_module_name == nil) {
                NSLog("Unable to identify app module name.")
            }
            app_module_str = app_module_name
        }
        var run_module = config.run_module
        status = PyConfig_SetBytesString(&config, &run_module, app_module_str)
        if ((PyStatus_Exception(status)) != 0) {
            crash_dialog("Unable to set app module name: \(String(cString: status.err_msg))")
            PyConfig_Clear(&config)
            Py_ExitStatusException(status)
        }
        
        // Read the site config
        status = PyConfig_Read(&config)
        if ((PyStatus_Exception(status)) != 0) {
            crash_dialog("Unable to read site config: \(String(cString: status.err_msg))")
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }
        
        // Set the full module path. This includes the stdlib, site-packages, and app code.
        NSLog("PYTHONPATH:")
        
        // The .zip form of the stdlib
        path = "\(resourcePath)/support/python310.zip"
        NSLog("- \(path)")
        wtmp_str = Py_DecodeLocale(path, nil)
        status = PyWideStringList_Append(&config.module_search_paths, wtmp_str);
        if ((PyStatus_Exception(status)) != 0) {
            crash_dialog("Unable to set .zip form of stdlib path: \(String(cString: status.err_msg))")
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }
        PyMem_RawFree(wtmp_str);
        
        // The unpacked form of the stdlib
        path = "\(resourcePath)/support/python-stdlib"
        NSLog("- \(path)")
        wtmp_str = Py_DecodeLocale(path, nil)
        status = PyWideStringList_Append(&config.module_search_paths, wtmp_str);
        if ((PyStatus_Exception(status)) != 0) {
            crash_dialog("Unable to set unpacked form of stdlib path: \(String(cString: status.err_msg))")
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }
        PyMem_RawFree(wtmp_str);
        
        
        // Add the stdlib binary modules path
        path = "\(resourcePath)/support/python-stdlib/lib-dynload"
        NSLog("- \(path)")
        wtmp_str = Py_DecodeLocale(path, nil)
        status = PyWideStringList_Append(&config.module_search_paths, wtmp_str);
        if ((PyStatus_Exception(status)) != 0) {
            crash_dialog("Unable to set stdlib binary module path: \(String(cString: status.err_msg))")
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }
        PyMem_RawFree(wtmp_str);
        
        // Add the app_packages path
        path = "\(resourcePath)/app_packages"
        NSLog("- \(path)")
        wtmp_str = Py_DecodeLocale(path, nil)
        status = PyWideStringList_Append(&config.module_search_paths, wtmp_str);
        if ((PyStatus_Exception(status)) != 0) {
            crash_dialog("Unable to set app packages path: \(String(cString: status.err_msg))")
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }
        PyMem_RawFree(wtmp_str);
        
        // Add the app path
        path = "\(resourcePath)/app"
        NSLog("- \(path)")
        wtmp_str = Py_DecodeLocale(path, nil)
        status = PyWideStringList_Append(&config.module_search_paths, wtmp_str);
        if ((PyStatus_Exception(status)) != 0) {
            crash_dialog("Unable to set app path: \(String(cString: status.err_msg))")
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }
        PyMem_RawFree(wtmp_str);
        
        //        NSLog("Configure argc/argv...")
        //        status = PyConfig_SetBytesArgv(&config, argc, argv);
        //        if ((PyStatus_Exception(status)) != 0) {
        //            crash_dialog("Unable to configured argc/argv: \(String(cString: status.err_msg))")
        //            PyConfig_Clear(&config);
        //            Py_ExitStatusException(status);
        //        }
        
        pySwiftImports()
        
        NSLog("Initializing Python runtime...")
        status = Py_InitializeFromConfig(&config);
        if ((PyStatus_Exception(status)) != 0) {
            crash_dialog("Unable to initialize Python interpreter: \(String(cString: status.err_msg))")
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }
    }
    
}

func crash_dialog(_ details: String) {
    // Write the error to the log
    NSLog(details)
    
    if ((getenv("BRIEFCASE_MAIN_MODULE")) != nil) {
        return
    }
    
    // Obtain the app instance (starting it if necessary) so that we can show an error dialog
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    
    // Create a stack trace dialog
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "Application has crashed"
    alert.informativeText = "An unexpected error occurred. Please see the traceback below for more information."
    
    // A multiline text widget in a scroll view to contain the stack trace
    let scroll_panel = NSScrollView(frame: .init(x: 0, y: 0, width: 600, height: 300))
    scroll_panel.hasVerticalScroller = true
    scroll_panel.hasHorizontalRuler = false
    scroll_panel.autohidesScrollers = false
    scroll_panel.borderType = .bezelBorder
    
    let crash_text = NSTextView()
    crash_text.isEditable = false
    crash_text.isSelectable = true
    crash_text.string = details
    crash_text.isVerticallyResizable = true
    crash_text.isHorizontallyResizable = true
    crash_text.font = .init(name: "Menlo", size: 12)
    scroll_panel.documentView = crash_text
    alert.accessoryView = scroll_panel
    
    // Show the crash dialog
    alert.runModal()
}
