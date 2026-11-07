import AppKit
import CxxFrontend
import InputMethodKit
import Logging

extension InputSessionRegistration {
  public func toICUUID() -> ICUUID {
    var uuid = ICUUID()
    for index in 0..<16 {
      uuid[index] = key.bytes[index]
    }
    return uuid
  }
}

extension InputSessionToken {
  init(_ identity: InputSessionIdentity) {
    let uuid = identity.uuid
    self.init(
      registration: InputSessionRegistration(
        key: InputSessionKey((0..<16).map { uuid[$0] }),
        runtimeEpoch: identity.runtimeEpoch, generation: identity.registrationGeneration),
      activationGeneration: identity.activationGeneration)
  }

  func toIdentity() -> InputSessionIdentity {
    var identity = InputSessionIdentity()
    identity.uuid = registration.toICUUID()
    identity.runtimeEpoch = registration.runtimeEpoch
    identity.registrationGeneration = registration.generation
    identity.activationGeneration = activationGeneration
    return identity
  }
}

@MainActor
private let inputSessions = InputSessionRegistry<IMKInputController>()

private let inputSessionOutputQueue = InputSessionOutputQueue()

@MainActor
private let inputSessionOutputs = InputSessionOutputDispatcher(
  registry: inputSessions, queue: inputSessionOutputQueue
) { controller, operation in
  guard let client = controller.client() else { return }
  deliverClientOutput(client, controller, operation)
}

private func deliverClientOutput(
  _ client: IMKTextInput, _ sourceController: IMKInputController?,
  _ operation: InputSessionOutput.Operation
) {
  switch operation {
  case .commit(let commit):
    commitString(client, commit)
  case .commitAndPreedit(let commit, let preedit, let caret, let dummy):
    commitAndSetPreedit(client, sourceController, commit, preedit, caret, dummy)
  case .close:
    break
  }
}

private func enqueueInputSessionOutput(
  _ identity: InputSessionIdentity, _ operation: InputSessionOutput.Operation
) {
  let output = InputSessionOutput(token: InputSessionToken(identity), operation: operation)
  if inputSessionOutputQueue.enqueue(output) {
    // Share the main queue with the candidate window, preserving the existing
    // requirement that client preedit is updated before the window is shown.
    DispatchQueue.main.async {
      inputSessionOutputs.drain()
    }
  }
}

@MainActor
public func beginInputSessionRuntime() {
  inputSessions.beginRuntime()
}

@MainActor
public func endInputSessionRuntime() {
  inputSessions.endRuntime()
  inputSessionOutputQueue.clear()
}

public func registerInputSession(
  _ uuid: ICUUID, _ controller: IMKInputController
) -> InputSessionRegistration? {
  // IMK's initializer is imported as nonisolated. Check its executor before
  // borrowing the controller inside MainActor; no object crosses a queue.
  dispatchPrecondition(condition: .onQueue(.main))
  nonisolated(unsafe) let mainController = controller
  let key = InputSessionKey((0..<16).map { uuid[$0] })
  return MainActor.assumeIsolated {
    let registration = inputSessions.register(key, controller: mainController)
    if registration == nil {
      FCITX_ERROR("Cannot register input session")
    }
    return registration
  }
}

@MainActor
@discardableResult
public func activateInputSession(
  _ registration: InputSessionRegistration
) -> InputSessionToken? {
  finishInputSessionTransition()
  let previous = inputSessions.activeToken
  guard let token = inputSessions.activate(registration) else { return nil }
  if token != previous {
    bind_input_session(token.toIdentity())
  }
  return token
}

@MainActor
public func deactivateInputSession(_ registration: InputSessionRegistration) {
  inputSessionOutputs.drain()
  inputSessions.deactivate(registration)
}

@MainActor
public func finishInputSessionTransition() {
  // Each synchronous close includes the core's deferred client updates and
  // appends a FIFO marker. Deliver those outputs before retiring the token.
  for token in inputSessions.closingTokens {
    close_input_session(token.toIdentity())
  }
  inputSessionOutputs.drain()
}

@MainActor
public func inputSessionController(_ token: InputSessionToken) -> IMKInputController? {
  return inputSessions.lookup(token)
}

@MainActor
public func unregisterInputSession(_ registration: InputSessionRegistration) -> Bool {
  return inputSessions.unregister(registration)
}

nonisolated(unsafe) private var u16pos = 0
nonisolated(unsafe) private var currentPreedit = ""

private let zeroWidthSpace = "\u{200B}"

private let passwordOnlyApps: Set<String> = [
  "com.apple.loginwindow",
  // Below are apps that only have password fields but don't call EnableSecureEventInput.
  "com.apple.wifi.WiFiAgent",  // join wifi from wifi menu
  "com.apple.wifi-settings-extension",  // join wifi from System Settings
  "com.apple.LocalAuthenticationRemoteService",  // Software Update
]

// Given issues when no preedit is so widespread regardless of UI framework,
// any app that is added here must be fully tested with Esc, Backspace, Arrow and normal keys.
// Union password-only apps so that fcitx clipboard can be used (though you may have to type instead of click to commit).
private let appsWithoutDummyPreedit: Set<String> = passwordOnlyApps.union([
  // <200b>
  "org.vim.MacVim",
  // When writing a new email and caret is at the beginning of To or Cc, Mail calls commitComposition
  // if the preedit is any kind of white space.
  "com.apple.mail",
  // Space (both commit and preedit) is not allowed immediately after ordered list (1.), which is the
  // dummy preedit we use for the SwiftUI TextField workaround. While we can change that normal space
  // to full-width space, it seems DingTalk doesn't need dummy preedit at all.
  "com.alibaba.DingTalkMac",
])

public func isPasswordOnly(app: String) -> Bool {
  return passwordOnlyApps.contains(app)
}

private func isJetBrains(_ app: String) -> Bool {
  return app == "com.google.android.studio" || app.starts(with: "com.jetbrains.")
}

nonisolated(unsafe) private var controller: IMKInputController? = nil
nonisolated(unsafe) private var currentLayout: String? = nil

public func setController(_ ctrl: Any) {
  guard let ctrl = ctrl as? IMKInputController, controller != ctrl else {
    return
  }
  controller = ctrl
  currentLayout = nil
}

@MainActor
private var statusItemCallback: ((Int32?, String?) -> Void)? = nil

@MainActor
public func setStatusItemCallback(_ callback: @escaping (Int32?, String?) -> Void) {
  statusItemCallback = callback
}

public func setStatusItemText(_ text: String) {
  Task { @MainActor in
    statusItemCallback?(nil, text)
  }
}

public func setStatusItemMode(_ mode: Int32) {
  Task { @MainActor in
    statusItemCallback?(mode, nil)
  }
}

private func commitString(_ client: IMKTextInput, _ string: String) {
  // Clear before insertText so a reentrant preedit update is not erased when
  // it returns. Prediction's dummy-preedit calculation also needs this reset.
  currentPreedit = ""
  client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
}

private func setPreedit(
  _ client: IMKTextInput, _ sourceController: IMKInputController?,
  _ preedit: String, _ caretPosUtf8: Int
) {
  currentPreedit = preedit
  // The caretPos argument is specified in UTF-8 bytes.
  // Convert it to UTF-16.
  var u8pos = 0
  u16pos = 0
  for ch in preedit {
    if u8pos == caretPosUtf8 {
      break
    }
    u8pos += ch.utf8.count
    u16pos += ch.utf16.count  // Usually 1 but can be more, e.g. emoji.
  }
  // Make underline as thin as macOS pinyin.
  let attrs =
    sourceController?.mark(forStyle: kTSMHiliteConvertedText, at: NSMakeRange(NSNotFound, 0))
    as? [NSAttributedString.Key: Any]
  client.setMarkedText(
    NSMutableAttributedString(string: preedit, attributes: attrs),
    selectionRange: NSRange(location: u16pos, length: 0),
    replacementRange: NSRange(location: NSNotFound, length: 0)
  )
}

public func commitAndSetPreeditSync(
  _ client: IMKTextInput, _ commit: String, _ preedit: String, _ caretPos: Int,
  _ dummyPreedit: Bool
) {
  applySynchronousInput(
    client, controller,
    .commitAndPreedit(commit: commit, preedit: preedit, caret: caretPos, dummy: dummyPreedit),
    at: inputSessionOutputBoundary())
}

public func commitAndSetPreeditSync(
  _ client: IMKTextInput, _ commit: String, _ preedit: String, _ caretPos: Int,
  _ dummyPreedit: Bool, outputBoundary: UInt64, sourceController: IMKInputController
) {
  applySynchronousInput(
    client, sourceController,
    .commitAndPreedit(commit: commit, preedit: preedit, caret: caretPos, dummy: dummyPreedit),
    at: outputBoundary)
}

private func applySynchronousInput(
  _ client: IMKTextInput, _ sourceController: IMKInputController?,
  _ operation: InputSessionOutput.Operation, at boundary: UInt64
) {
  dispatchPrecondition(condition: .onQueue(.main))
  // IMK callbacks are imported nonisolated. These references are borrowed only
  // for this synchronous MainActor call, never queued across threads.
  nonisolated(unsafe) let mainClient = client
  nonisolated(unsafe) let mainController = sourceController
  MainActor.assumeIsolated {
    inputSessionOutputs.applySynchronous(at: boundary, operation: operation) { step in
      deliverClientOutput(mainClient, mainController, step)
    }
  }
}

@MainActor
public func discardSynchronousInput(_ boundary: UInt64) {
  inputSessionOutputs.applySynchronous(at: boundary, operation: nil) { _ in
    preconditionFailure("Discarded synchronous response must not be delivered")
  }
}

private func commitAndSetPreedit(
  _ client: IMKTextInput, _ sourceController: IMKInputController?,
  _ commit: String, _ preedit: String, _ caretPos: Int, _ dummyPreedit: Bool
) {
  if !commit.isEmpty {
    commitString(client, commit)
  }
  let app = client.bundleIdentifier() ?? ""
  // Without client preedit, Backspace bypasses IM in Terminal, every key is both
  // processed by IM and passed to client in iTerm, JetBrains and VSCode terminal,
  // Backspace is double-processed in Chrome address bar/VSCode editor/Bruno URL input,
  // ArrowDown is swallowed in Spotlight, so we force a dummy client preedit here.
  // Some apps also need it to get accurate caret position to place candidate window.
  // This is fine even when there is selected text. In Word, not using dummy preedit to
  // replace selected text will let Esc bypass IM. When using Shift+click to select, if
  // interval is too little, IM switch happens, but dummyPreedit is false in that case.
  if preedit.isEmpty && dummyPreedit {
    if appsWithoutDummyPreedit.contains(app) {
      return
    }
    let length = client.length()
    let selectedRange = client.selectedRange()
    // We prefer ZWS to avoid text layout shift after caret, e.g. VSCode.
    // For SwiftUI TextField, there is a bug that if caret is at the end of text, zero-width space preedit
    // spreads from the start to the end, making the whole text underlined. Fortunately, SwiftUI's length
    // and selectedRange are reliable, so we use a normal space in this case.
    // JetBrains-based IDEs displays zero-width space as "ZWSP" so we'd rather use a normal space.
    if (length > 0 && length - currentPreedit.count == NSMaxRange(selectedRange))
      || isJetBrains(app)
    {
      setPreedit(client, sourceController, " ", 0)
    } else {
      setPreedit(client, sourceController, zeroWidthSpace, 0)
    }
  } else {
    setPreedit(client, sourceController, preedit, caretPos)
  }
}

public func commitAndSetPreeditAsync(
  _ identity: InputSessionIdentity, _ commit: String, _ preedit: String,
  _ caretPos: Int, _ dummyPreedit: Bool
) {
  enqueueInputSessionOutput(
    identity,
    .commitAndPreedit(commit: commit, preedit: preedit, caret: caretPos, dummy: dummyPreedit))
}

public func commitAsync(_ identity: InputSessionIdentity, _ commit: String) {
  enqueueInputSessionOutput(identity, .commit(commit))
}

public func closeInputSessionAsync(_ identity: InputSessionIdentity) {
  enqueueInputSessionOutput(identity, .close)
}

// Ordered C++ adapters mark this position before leaving the core thread.
public func inputSessionOutputBoundary() -> UInt64 {
  return inputSessionOutputQueue.enqueueBoundary()
}

// UTF-16 units of surrounding text read on each side of the cursor. This runs
// on every key, and reading the whole document gets slow in a client with a
// long buffer, such as a terminal with a long scrollback (reproducible on Terminal
// by `seq 1 1000000`). Engines only look at text near the cursor.
private let surroundingTextWindow = 1024

public func getSurroundingText(_ location: Int, _ length: Int) -> (String, UInt32, UInt32) {
  guard let client = controller?.client(), location != NSNotFound else {
    return ("", 0, 0)
  }
  let totalLength = client.length()
  // currentPreedit is inserted at location - u16pos
  let preeditStart = max(0, location - u16pos)
  let preeditEnd = preeditStart + currentPreedit.utf16.count
  let windowStart = max(0, preeditStart - surroundingTextWindow)
  let afterLength = min(max(0, totalLength - preeditEnd), surroundingTextWindow)
  let afterIsCut = preeditEnd + afterLength < totalLength

  var actual = NSRange(location: 0, length: 0)
  var beforeStr =
    client.string(
      from: NSRange(location: windowStart, length: preeditStart - windowStart),
      actualRange: &actual) ?? ""
  if windowStart > 0 {  // The first char may be partial grapheme so simply drop it.
    beforeStr = String(beforeStr.dropFirst())
  }
  var afterStr =
    client.string(from: NSRange(location: preeditEnd, length: afterLength), actualRange: &actual)
    ?? ""
  if afterIsCut {
    afterStr = String(afterStr.dropLast())
  }
  let fullText = beforeStr + afterStr

  // fcitx5 expects Unicode code point count for anchor and cursor in surrounding text.
  let anchor = UInt32(beforeStr.unicodeScalars.count)
  if currentPreedit.isEmpty && length > 0 {
    // The selection starts where the text after the cursor starts. Cut it at
    // the same place, so the cursor stays within the text.
    let selectionStr = (afterStr as NSString).substring(
      with: NSRange(location: 0, length: min(length, afterStr.utf16.count)))
    return (fullText, anchor + UInt32(selectionStr.unicodeScalars.count), anchor)
  }
  return (fullText, anchor, anchor)
}

// It's called from C++ within dispatch_async(dispatch_get_main_queue())
// so we can mark corresponding variables as nonisolated(unsafe).
public func getCaretCoordinates(_ followCaret: Bool) -> [Double] {
  guard let client = controller?.client() else {
    return []
  }
  var rect = NSRect(x: 0, y: 0, width: 0, height: 0)
  // n characters have n+1 caret positions, but character index only accepts 0 to n-1,
  // and passing n results in (0,0). So if caret is in the end, go back and add some width.
  // For dummy preedit, index is 0. For no preedit at all, don't apply it.
  let shouldGoBack = followCaret && currentPreedit.count > 0 && u16pos == currentPreedit.utf16.count
  let lastCharacter = currentPreedit.last.map(String.init) ?? ""
  let index = followCaret ? (shouldGoBack ? u16pos - lastCharacter.utf16.count : u16pos) : 0
  let attributes = client.attributes(forCharacterIndex: index, lineHeightRectangle: &rect)
  if rect.width == 0 && rect.height == 0 {
    return []
  }
  var x = Double(NSMinX(rect))
  let y = Double(NSMinY(rect))
  let height = Double(rect.height)
  if shouldGoBack {
    let lineHeight = Double(max(abs(rect.width), abs(rect.height)))
    let reportedFont = attributes?[NSAttributedString.Key.font] as? NSFont
    let font: NSFont
    // Terminal reports correct font with size (Menlo-Regular 14.00 pt), but others just give Helvetica 12.00 pt.
    // If line height is 1-1.5x font size, we treat font size as exact, otherwise font size = line height / 1.2 .
    if let reportedFont, reportedFont.pointSize <= lineHeight,
      lineHeight <= reportedFont.pointSize * 1.5
    {
      font = reportedFont
    } else {
      font = NSFont.systemFont(ofSize: lineHeight / 1.2)
    }
    x += (lastCharacter as NSString).size(withAttributes: [.font: font]).width
  }
  return [x, y, height]
}

// Called from C++ within dispatch_async(dispatch_get_main_queue())
public func getSelection() -> String {
  guard let client = controller?.client() else {
    return ""
  }
  let range = client.selectedRange()
  if range.location == NSNotFound {
    return ""
  }
  var actualRange = NSRange(location: 0, length: 0)
  return client.string(from: range, actualRange: &actualRange) ?? ""
}

// Call it on
// 1. Open a new App: FcitxInputController.init
// 2. Switch App: FcitxInputController.activateServer
// 3. Switch group: condition covered by 4
// (below are HACK for VSCode terminal and Neovide Chinese punctuation)
// 4. Switch input method: InputContextInputMethodActivated
// 5. Update punctuation option: UserInterfaceComponent::StatusArea
public func overrideKeyboardLayout() {
  let layout = String(get_current_group_layout())
  let appleLayout = layout == "PinyinKeyboard" ? "PinyinKeyboard" : layoutMap[layout] ?? "ABC"
  guard let client = controller?.client(), currentLayout != appleLayout else {
    return
  }
  FCITX_DEBUG("Override keyboard layout to \(appleLayout)")
  currentLayout = appleLayout
  client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.\(appleLayout)")
}
