import Cocoa
import Fcitx

/// All config window controllers should subclass this. It sets up
/// application states so that the config windows can receive user
/// input.
class ConfigWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
  var key: String = ""

  override init(window: NSWindow?) {
    super.init(window: window)
    if let window = window {
      window.delegate = self
    }
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override func showWindow(_ sender: Any? = nil) {
    if let window = window {
      // Switch to normal activation policy so that the config windows
      // can receive key events.
      if NSApp.activationPolicy() != .regular {
        NSApp.setActivationPolicy(.regular)
      }

      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender.orderOut(nil)
    // Free memory and reset state.
    FcitxInputController.controllers.removeValue(forKey: key)
    // Switch back.
    if FcitxInputController.controllers.count == 0 {
      NSApp.setActivationPolicy(.prohibited)
    }
    return false
  }

  func attachToolbar(_ window: NSWindow) {
    // Prior to macOS 14.0, NSHostingView doesn't host toolbars, and
    // we have to create a toolbar manually.
    //
    // Cannot use #available check here because it's a runtime check,
    // but the following code should work nevertheless: NSHostingView
    // will replace the toolbar if it works.
    let toolbar = NSToolbar(identifier: "MainToolbar")
    toolbar.delegate = self
    toolbar.displayMode = .iconOnly
    toolbar.showsBaselineSeparator = false
    window.toolbar = toolbar
    window.toolbarStyle = .unified
  }

  func toolbar(
    _ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    if itemIdentifier == .toggleSidebar {
      let item = NSToolbarItem(itemIdentifier: .toggleSidebar)
      item.label = NSLocalizedString("Toggle Sidebar", comment: "label")
      item.paletteLabel = NSLocalizedString("Toggle Sidebar", comment: "label")
      item.toolTip = NSLocalizedString("Toggle the visibility of the sidebar", comment: "tooltip")
      item.target = self
      item.action = #selector(toggleSidebar)
      return item
    }
    return nil
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    return [.toggleSidebar, .flexibleSpace]
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    return [.toggleSidebar, .flexibleSpace]
  }

  @objc func toggleSidebar(_ sender: Any?) {
    // Wow, we don't have to do anything here.
  }

  func setKey(_ key: String) {
    self.key = key
  }

  func refresh() {}
}
