import AppKit

struct Case {
  // characters and charactersIgnoringModifiers must come from real NSEvent received by input method, not key recorder GUI.
  let mods: NSEvent.ModifierFlags
  let characters: String?
  let charactersIgnoringModifiers: String?
  let expected: String

  init(
    _ mods: NSEvent.ModifierFlags, _ characters: String?, _ charactersIgnoringModifiers: String?,
    _ expected: String
  ) {
    self.mods = mods
    self.characters = characters
    self.charactersIgnoringModifiers = charactersIgnoringModifiers
    self.expected = expected
  }
}

let cases: [(String, Case)] = [
  // Simple alphabet.
  ("a", Case([], "a", "a", "a")),
  ("Shift+A", Case(.shift, "A", "a", "A")),
  ("CapsLock+A", Case(.capsLock, "A", "a", "A")),
  ("Shift+CapsLock+A", Case(.shift.union(.capsLock), "A", "a", "a")),

  // Control alphabet.
  ("Control+A", Case(.control, "\u{01}", "a", "a")),
  // Squirrel compatibility.
  ("Control+Shift+A", Case(.control.union(.shift), "\u{01}", "a", "A")),

  // Alt alphabet
  ("Alt+B", Case(.option, "∫", "b", "b")),
  ("Alt+Shift+B", Case(.option.union(.shift), "ı", "b", "B")),

  // Simple non-alphabet.
  ("comma", Case([], ",", ",", ",")),
  ("less (Shift+comma)", Case(.shift, "<", ",", "<")),
  ("CapsLock+comma", Case(.capsLock, ",", ",", ",")),
  ("CapsLock+less (CapsLock+Shift+comma)", Case(.shift.union(.capsLock), "<", ",", "<")),

  // Control non-alphabet.
  ("Control+bracketleft", Case(.control, "\u{1B}", "[", "[")),
  ("Control+Shift+bracketleft", Case(.control.union(.shift), "\u{1B}", "[", "[")),

  // Alt non-alphabet.
  ("Alt+comma", Case(.option, "≤", ",", ",")),
  ("Alt+Shift+comma", Case(.option.union(.shift), "¯", ",", ",")),

  // Pinyin Keyboard (pass through and let osx_unicode_to_fcitx_keysym handle).
  ("；", Case([], "；", "；", "；")),
  ("： (Shift+；)", Case(.shift, "：", "；", "：")),
  ("Control+；", Case(.control, ";", "；", "；")),
  ("Control+Shift+；", Case(.control.union(.shift), ";", "；", "；")),
  ("Alt+；", Case(.option, "…", "；", "；")),
  ("Alt+Shift+；", Case(.option.union(.shift), "Ú", "；", "；")),
  ("Cmd+；", Case(.command, ";", "；", "；")),
  ("Cmd+Shift+；", Case(.command.union(.shift), ":", "；", "；")),
  ("Control+Alt+；", Case(.control.union(.option), ";", "；", "；")),
  ("Control+Alt+Shift+；", Case(.control.union(.option).union(.shift), ";", "；", "；")),
  ("Alt+Cmd+；", Case(.option.union(.command), "…", "；", "；")),
  ("Alt+Cmd+Shift+，", Case(.option.union(.command).union(.shift), "Ú", "；", "；")),
  ("Control+Cmd+；", Case(.control.union(.command), ";", "；", "；")),
  ("Control+Cmd+Shift+；", Case(.command.union(.command).union(.shift), ";", "；", "；")),
  ("Control+Option+Cmd+Shift+；", Case(.control.union(.option).union(.command).union(.shift), ";", "；", "；")),

  // Type safety.
  ("nil characters", Case([], nil, "a", "")),
  ("nil charactersIgnoringModifiers", Case([], "a", nil, "")),
]

@_cdecl("main")
func main() -> Int {
  var failed = false
  for (name, c) in cases {
    let actual = keyEventUnicode(
      characters: c.characters, charactersIgnoringModifiers: c.charactersIgnoringModifiers, mods: c.mods)
    let expected = keyToUnicode(c.expected)
    if actual != expected {
      failed = true
      print("\(name): expected \(expected), got \(actual)")
    }
  }
  return failed ? 1 : 0
}
