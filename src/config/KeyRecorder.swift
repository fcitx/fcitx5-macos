import Carbon
import Keycode
import SwiftUI

private let codeMap = [
  // modifier
  kVK_Control: "⌃ᴸ",
  kVK_RightControl: "⌃ᴿ",
  kVK_Option: "⌥ᴸ",
  kVK_RightOption: "⌥ᴿ",
  kVK_Shift: "⇧ᴸ",
  kVK_RightShift: "⇧ᴿ",
  kVK_Command: "⌘ᴸ",
  kVK_RightCommand: "⌘ᴿ",
  // keypad
  kVK_ANSI_Keypad0: "🄋",
  kVK_ANSI_Keypad1: "➀",
  kVK_ANSI_Keypad2: "➁",
  kVK_ANSI_Keypad3: "➂",
  kVK_ANSI_Keypad4: "➃",
  kVK_ANSI_Keypad5: "➄",
  kVK_ANSI_Keypad6: "➅",
  kVK_ANSI_Keypad7: "➆",
  kVK_ANSI_Keypad8: "➇",
  kVK_ANSI_Keypad9: "➈",
  kVK_ANSI_KeypadEquals: "⊜",
  kVK_ANSI_KeypadMinus: "⊖",
  kVK_ANSI_KeypadMultiply: "⊗",
  kVK_ANSI_KeypadPlus: "⊕",
  kVK_ANSI_KeypadDivide: "⊘",
  // special
  kVK_Delete: "⌫",
  kVK_ANSI_KeypadEnter: "⌅",
  kVK_Escape: "⎋",
  kVK_ForwardDelete: "⌦",
  kVK_Return: "⏎",
  kVK_Space: "Space",
  kVK_Tab: "⇥",
  // cursor
  kVK_UpArrow: "▲",
  kVK_DownArrow: "▼",
  kVK_LeftArrow: "◀",
  kVK_RightArrow: "▶",
  kVK_PageUp: "↑",
  kVK_PageDown: "↓",
  kVK_Home: "⤒",
  kVK_End: "⤓",
  // pc keyboard
  kVK_Help: "⎀",
  kVK_F15: "⎉",
  kVK_F13: "⎙",
  kVK_F14: "⇳",
]

// Separate them because in the menu their font size is smaller and we want the same behavior in recorder UI as well.
private let functionCodeMap = [
  kVK_F1: "F1",
  kVK_F2: "F2",
  kVK_F3: "F3",
  kVK_F4: "F4",
  kVK_F5: "F5",
  kVK_F6: "F6",
  kVK_F7: "F7",
  kVK_F8: "F8",
  kVK_F9: "F9",
  kVK_F10: "F10",
  kVK_F11: "F11",
  kVK_F12: "F12",
]

func shortcutRepr(_ key: String, _ modifiers: NSEvent.ModifierFlags, _ code: UInt16) -> (
  String, String?
) {
  var desc = ""
  if modifiers.contains(.control) && code != kVK_Control && code != kVK_RightControl { desc += "⌃" }
  if modifiers.contains(.option) && code != kVK_Option && code != kVK_RightOption { desc += "⌥" }
  if modifiers.contains(.shift) && code != kVK_Shift && code != kVK_RightShift { desc += "⇧" }
  if modifiers.contains(.command) && code != kVK_Command && code != kVK_RightCommand { desc += "⌘" }
  if let normalFont = codeMap[Int(code)] {
    return (desc + normalFont, nil)
  } else if let smallerFont = functionCodeMap[Int(code)] {
    return (desc, smallerFont)
  }
  // Use uppercase to match menu.
  return (desc + key.uppercased(), nil)
}

struct RecordingOverlay: NSViewRepresentable {
  @Binding var recordedShortcut: (String, String?)
  @Binding var recordedFcitxKey: String

  func makeNSView(context: Context) -> NSView {
    let view = KeyCaptureView()
    view.coordinator = context.coordinator
    // Not sure why macOS 15 arm needs this but x86 doesn't.
    DispatchQueue.main.async {
      view.window?.makeFirstResponder(view)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  @MainActor
  class Coordinator: NSObject {
    private var parent: RecordingOverlay
    private var modifiers = NSEvent.ModifierFlags()
    private var code: UInt16 = 0

    init(_ parent: RecordingOverlay) {
      self.parent = parent
    }

    func handleKeyCapture(code: UInt16) {
      self.code = code
      updateParent()
    }

    func handleKeyCapture(modifiers: NSEvent.ModifierFlags, code: UInt16) {
      if modifiers.isDisjoint(with: [.command, .option, .control, .shift]) {
        self.modifiers = NSEvent.ModifierFlags()
        self.code = 0
      } else {
        if modifiers.isSuperset(of: self.modifiers) {
          // Don't change on release
          self.modifiers = modifiers
          self.code = code
        }
        updateParent()
      }
    }

    private func updateParent() {
      // Compute the unicode the key produces from the OSX keycode and
      // modifiers on the fly so a layout switch during recording is always
      // reflected. Special keys have no unicode and are shown via codeMap.
      let unicode = osx_keycode_to_osx_unicode(code, UInt32(modifiers.rawValue))
      parent.recordedShortcut = shortcutRepr(
        UnicodeScalar(unicode).map { String($0) } ?? "", modifiers, code)
      parent.recordedFcitxKey = String(
        osx_key_to_fcitx_string(unicode, UInt32(modifiers.rawValue), code))
    }
  }
}

class KeyCaptureView: NSView {
  weak var coordinator: RecordingOverlay.Coordinator?

  // comment out will focus textfield. What if not textfield?
  override var acceptsFirstResponder: Bool {
    return true
  }

  override func keyDown(with event: NSEvent) {
    // Map the physical keycode through xkbcommon with the current layout so we
    // get the same keysym the IM receives, e.g. comma for Control+Shift+comma.
    // characters and charactersIgnoringModifiers are inconsistent with IMKit
    // and can't be unified anyway.
    coordinator?.handleKeyCapture(code: event.keyCode)
  }

  override func flagsChanged(with event: NSEvent) {
    coordinator?.handleKeyCapture(modifiers: event.modifierFlags, code: event.keyCode)
  }
}
