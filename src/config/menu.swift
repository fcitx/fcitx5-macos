import Cocoa
import Fcitx

// Don't call it synchronously in SwiftUI as it will make IM temporarily unavailable in focused client.
@MainActor
func restartProcess() {
  // Sheets prevent Fcitx5 from normal termination.
  for window in NSApp.windows {
    for sheet in window.sheets {
      window.endSheet(sheet)
    }
  }
  NSApp.terminate(nil)
}

extension FcitxInputController {
  @MainActor static var controllers = [String: ConfigWindowController]()

  @MainActor
  func openWindow(_ key: String, _ type: ConfigWindowController.Type) {
    var controller = FcitxInputController.controllers[key]
    if controller == nil {
      controller = type.init()
      controller?.setKey(key)
      FcitxInputController.controllers[key] = controller
    }
    controller?.showWindow(nil)
  }

  // Called when plugins are installed, so that the input methods and addons can be updated.
  @MainActor
  static func refreshAll() {
    for controller in controllers.values {
      controller.refresh()
    }
  }

  @MainActor
  static func closeWindow(_ key: String) {
    FcitxInputController.controllers[key]?.window?.performClose(nil)
  }

  @MainActor
  @objc func plugin(_: Any? = nil) {
    openWindow("plugin", PluginManager.self)
  }

  @MainActor
  @objc func restart(_: Any? = nil) {
    restartProcess()
  }

  @MainActor
  @objc func about(_: Any? = nil) {
    openWindow("about", FcitxAboutController.self)
  }

  @MainActor
  @objc func globalConfig(_: Any? = nil) {
    openWindow("global", GlobalConfigController.self)
  }

  @MainActor
  @objc func inputMethod(_: Any? = nil) {
    openWindow("im", InputMethodConfigController.self)
  }

  @MainActor
  @objc func themeEditor(_: Any? = nil) {
    openWindow("theme", ThemeEditorController.self)
  }

  @MainActor
  @objc func advanced(_: Any? = nil) {
    openWindow("advanced", AdvancedController.self)
  }
}
