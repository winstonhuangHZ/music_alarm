import AppKit
import Darwin

// Programmatic AppKit entry point (this toolchain's SwiftUI module has no
// @main / App / WindowGroup, so we host SwiftUI views inside a plain window).
let application = NSApplication.shared
let singleInstanceGuard = SingleInstanceGuard()
if !singleInstanceGuard.acquire() {
    SingleInstanceGuard.activateExistingInstance()
    exit(0)
}
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.regular)
application.run()
