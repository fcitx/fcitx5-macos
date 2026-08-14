import Cocoa
import Keycode

public func keyToUnicode(_ key: String) -> UInt32 {
  if key.isEmpty {
    return 0
  }
  let usv = key.unicodeScalars
  return usv[usv.startIndex].value
}

func macKeyToFcitxString(_ key: String, _ modifiers: NSEvent.ModifierFlags, _ code: UInt16)
  -> String
{
  let unicode = keyToUnicode(key)
  return String(osx_key_to_fcitx_string(unicode, UInt32(modifiers.rawValue), code))
}

/// Resolve the unicode point to send to fcitx for a keyDown event.
///
/// For Shift+comma, charactersIgnoringModifiers is comma, characters is less.
/// For Control+Shift+comma, both are comma.
/// This behavior is different with what key recorder gets.
/// We need less for Shift+comma, so we have to use characters for non-alphabet with non-Control/Alt/Command cases,
/// For Control+Shift+A, characters is \u{01}, and more ridiculous results for ^[, ^\, ^], and ^-.
/// For Alt+(Shift+) non-whitespace key, characters is non-ASCII thus can't match any configured hotkey in fcitx.
/// So we use charactersIgnoringModifiers, which doesn't change the committing special char behavior if rejected by fcitx.
/// In conclusion, for cases other than non-alphabet with non-Control/Alt/Command, we use charactersIgnoringModifiers.
public func keyEventUnicode(
  characters: String?, charactersIgnoringModifiers: String?, mods: NSEvent.ModifierFlags
) -> UInt32 {
  guard let characters, let charactersIgnoringModifiers else {
    return 0
  }
  // charactersIgnoringModifiers could be a, comma, 1, and ；(PinyinKeyboard), but never A, less, or exclaim.
  var unicode = keyToUnicode(charactersIgnoringModifiers)
  if unicode >= 97 && unicode <= 122 {
    // Send capital keysym when shift is pressed (issue#101)
    // This is for Squirrel compatibility:
    // Squirrel recognizes Control+Shift+F and Control+Shift+0
    // but not Control+Shift+f and Control+Shift+parenright
    // Also need to consider CapsLock for good_old_caps_lock (issue#404)
    if mods.contains(.capsLock) != mods.contains(.shift) {
      unicode -= 32
    }
  } else if mods.isDisjoint(with: [.control, .option, .command]) {
    unicode = keyToUnicode(characters)
  }
  return unicode
}

func fcitxStringToMacShortcut(_ s: String) -> (String, String?) {
  let key = String(fcitx_string_to_osx_keysym(s))
  let modifiers = NSEvent.ModifierFlags(rawValue: UInt(fcitx_string_to_osx_modifiers(s)))
  let code = fcitx_string_to_osx_keycode(s)
  if key.isEmpty && code == 0 {
    return (s, nil)
  }
  return shortcutRepr(key, modifiers, code)
}
