import Cocoa
import Fcitx
import FcitxConfigUI

extension FcitxInputController {
  @MainActor
  @objc func plugin(_: Any? = nil) {
    ConfigWindowController.openWindow("plugin", PluginManager.self)
  }

  @MainActor
  @objc func restart(_: Any? = nil) {
    restartProcess()
  }

  @MainActor
  @objc func about(_: Any? = nil) {
    ConfigWindowController.openWindow("about", FcitxAboutController.self)
  }

  @MainActor
  @objc func globalConfig(_: Any? = nil) {
    ConfigWindowController.openWindow("global", GlobalConfigController.self)
  }

  @MainActor
  @objc func inputMethod(_: Any? = nil) {
    ConfigWindowController.openWindow("im", InputMethodConfigController.self)
  }

  @MainActor
  @objc func themeEditor(_: Any? = nil) {
    ConfigWindowController.openWindow("theme", ThemeEditorController.self)
  }

  @MainActor
  @objc func advanced(_: Any? = nil) {
    ConfigWindowController.openWindow("advanced", AdvancedController.self)
  }
}
