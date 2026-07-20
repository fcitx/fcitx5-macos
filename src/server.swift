import Cocoa
import Fcitx
import FcitxConfigUI
import InputMethodKit
import SwiftFrontend
import SwiftNotify

class NSManualApplication: NSApplication {
  private let appDelegate = AppDelegate()

  override init() {
    super.init()
    self.delegate = appDelegate
  }

  required init?(coder: NSCoder) {
    fatalError("Unreachable path")
  }
}

// Redirect stderr to /tmp/Fcitx5.log as it's not captured anyway.
private func redirectStderr() {
  let file = fopen("/tmp/Fcitx5.log", "w")
  if let file = file {
    dup2(fileno(file), STDERR_FILENO)
    fclose(file)
  }
}

private func signalHandler(signal: Int32) {
  // The signal can be raised on any thread. So we must make sure it's
  // routed back to the main thread.
  DispatchQueue.main.async {
    if signal == SIGTERM {
      restartProcess()
    }
  }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  nonisolated(unsafe) static var server: IMKServer!
  nonisolated(unsafe) static var notificationDelegate: NotificationDelegate!
  nonisolated(unsafe) static var statusItem: NSStatusItem?
  nonisolated(unsafe) static var statusItemText: String = "🐧"
  nonisolated(unsafe) static var statusItemMode: Int32 = 0
  nonisolated(unsafe) static var cachedStatusItemPosition: Any?

  private static let statusItemAutosaveName: NSStatusItem.AutosaveName = "fcitx5"
  private static let statusItemPositionKey =
    "NSStatusItem Preferred Position \(statusItemAutosaveName)"
  private static let inputSourceChangedNotification = Notification.Name(
    rawValue: kTISNotifySelectedKeyboardInputSourceChanged as String)
  private var positionObserver: NSObjectProtocol?

  func applicationDidFinishLaunching(_ notification: Notification) {
    redirectStderr()

    // Once process started, WKWebView doesn't accept new font files. Record and prompt user restart if needed.
    initUserFontFamiliesOnStart()

    signal(SIGTERM, signalHandler)

    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(inputSourceChanged),
      name: AppDelegate.inputSourceChangedNotification,
      object: nil)

    // Preserve status item position when macOS clears it after isVisible = false.
    positionObserver = NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self = self else { return }
      let key = AppDelegate.statusItemPositionKey
      if UserDefaults.standard.object(forKey: key) == nil,
        let position = AppDelegate.cachedStatusItemPosition
      {
        UserDefaults.standard.set(position, forKey: key)
      }
    }

    setStatusItemCallback { mode, text in
      if let mode = mode {
        AppDelegate.statusItemMode = mode
      }
      if let text = text {
        AppDelegate.statusItemText = prefixForStatusItem(text)
      }
      self.refreshStatusItemVisibility()
    }

    AppDelegate.server = IMKServer(
      name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String,
      bundleIdentifier: Bundle.main.bundleIdentifier)

    // Initialize notifications.
    AppDelegate.notificationDelegate = NotificationDelegate()
    AppDelegate.notificationDelegate.requestAuthorization()

    let locale = getLocale()
    start_fcitx_thread(locale)
  }

  func applicationWillTerminate(_ notification: Notification) {
    DistributedNotificationCenter.default().removeObserver(self)
    if let observer = positionObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    stop_fcitx_thread()
  }

  private func isFcitxSelectedInputSource() -> Bool {
    guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
      let property = TISGetInputSourceProperty(inputSource, kTISPropertyBundleID)
    else {
      return false
    }
    let bundleId = Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
    return bundleId == Bundle.main.bundleIdentifier
  }

  @MainActor
  private func hideStatusItem() {
    guard let statusItem = AppDelegate.statusItem, statusItem.isVisible else { return }
    AppDelegate.cachedStatusItemPosition = UserDefaults.standard.object(
      forKey: AppDelegate.statusItemPositionKey)
    statusItem.isVisible = false
  }

  @MainActor
  private func showStatusItem() {
    let statusItem = ensureStatusItem()
    guard !statusItem.isVisible else { return }
    if let position = AppDelegate.cachedStatusItemPosition {
      UserDefaults.standard.set(position, forKey: AppDelegate.statusItemPositionKey)
    }
    statusItem.isVisible = true
  }

  @MainActor
  private func ensureStatusItem() -> NSStatusItem {
    if let statusItem = AppDelegate.statusItem {
      return statusItem
    }
    // NSStatusItem.variableLength causes layout shift of icons on the left when switching between en and 拼.
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.autosaveName = AppDelegate.statusItemAutosaveName
    AppDelegate.statusItem = statusItem
    return statusItem
  }

  @MainActor
  private func makeStatusItemMenu() -> NSMenu {
    let menu = NSMenu()

    let toggle = NSMenuItem(
      title: NSLocalizedString("Toggle input method", comment: ""),
      action: #selector(self.toggle), keyEquivalent: "")
    toggle.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
    menu.addItem(toggle)

    menu.addItem(NSMenuItem.separator())

    let hide = NSMenuItem(
      title: NSLocalizedString("Hide", comment: ""),
      action: #selector(self.hide), keyEquivalent: "")
    hide.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: nil)
    menu.addItem(hide)

    return menu
  }

  @MainActor
  private func refreshStatusItemVisibility() {
    guard AppDelegate.statusItemMode != 0, isFcitxSelectedInputSource() else {
      hideStatusItem()
      return
    }

    showStatusItem()
    let statusItem = AppDelegate.statusItem!
    statusItem.menu = nil

    if let button = statusItem.button {
      button.title = AppDelegate.statusItemText
      button.target = self
      button.action = nil
      if AppDelegate.statusItemMode == 1 {  // Toggle input method
        button.action = #selector(self.toggle)
      } else {  // Menu
        statusItem.menu = makeStatusItemMenu()
      }
    }
  }

  @MainActor
  @objc private func inputSourceChanged(_ notification: Notification) {
    refreshStatusItemVisibility()
  }

  @objc func toggle() {
    toggleInputMethod()
  }

  @MainActor
  @objc func hide() {
    Fcitx.setConfig("fcitx://config/addon/macosfrontend", "{\"StatusBar\": \"Hidden\"}")
    ConfigWindowController.refreshAll()  // Refresh Advanced.
    sendNotification(
      "status-item-hidden", "", NSLocalizedString("Status bar is hidden", comment: ""),
      NSLocalizedString("You may re-enable it in Advanced → macOS Frontend.", comment: ""), [], 8000
    )
  }
}
