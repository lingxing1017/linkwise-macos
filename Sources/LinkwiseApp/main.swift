import AppKit

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
AppMainMenu.install(on: application)
application.setActivationPolicy(.accessory)
application.run()
