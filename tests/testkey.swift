func expectShortcut(_ name: String, _ expected: (String, String?), _ actual: (String, String?)) -> Bool {
  if actual.0 == expected.0 && actual.1 == expected.1 {
    return true
  }
  print("\(name): expected \(expected), got \(actual)")
  return false
}

func expectBool(_ name: String, _ expected: Bool, _ actual: Bool) -> Bool {
  if actual == expected {
    return true
  }
  print("\(name): expected \(expected), got \(actual)")
  return false
}

func testFcitxToMac() -> Bool {
  var ok = true
  ok = expectShortcut("0", ("0", nil), fcitxStringToMacShortcut("0")) && ok
  ok = expectShortcut("KP_0", ("🄋", nil), fcitxStringToMacShortcut("KP_0")) && ok
  ok = expectShortcut("Control+A", ("⌃A", nil), fcitxStringToMacShortcut("Control+A")) && ok
  ok = expectShortcut(
    "Control+Shift+A", ("⌃⇧A", nil), fcitxStringToMacShortcut("Control+Shift+A")) && ok
  ok = expectShortcut(
    "Shift+Super+Shift_L", ("⌘⇧ᴸ", nil), fcitxStringToMacShortcut("Shift+Super+Shift_L")) && ok
  ok = expectShortcut(
    "Shift+Super+Super_L", ("⇧⌘ᴸ", nil), fcitxStringToMacShortcut("Shift+Super+Super_L")) && ok
  ok = expectShortcut(
    "Alt+Shift+Shift_R", ("⌥⇧ᴿ", nil), fcitxStringToMacShortcut("Alt+Shift+Shift_R")) && ok
  ok = expectShortcut("F12", ("", "F12"), fcitxStringToMacShortcut("F12")) && ok
  ok = expectShortcut("Shift+F12", ("⇧", "F12"), fcitxStringToMacShortcut("Shift+F12")) && ok
  ok = expectShortcut("Super+Home", ("⌘⤒", nil), fcitxStringToMacShortcut("Super+Home")) && ok
  ok = expectShortcut("Control+<38>", ("⌃A", nil), fcitxStringToMacShortcut("Control+<38>")) && ok
  ok = expectShortcut("Shift+<59>", ("⇧<", nil), fcitxStringToMacShortcut("Shift+<59>")) && ok
  ok = expectShortcut("F1 code", ("", "F1"), fcitxStringToMacShortcut("<67>")) && ok
  ok = expectShortcut("unknown code", ("???", nil), fcitxStringToMacShortcut("<999>")) && ok
  ok = expectBool("code key", true, fcitxStringIsKeycode("Control+<38>")) && ok
  ok = expectBool("symbol key", false, fcitxStringIsKeycode("Control+A")) && ok
  ok = expectBool("unknown code key", true, fcitxStringIsKeycode("<999>")) && ok
  return ok
}

@_cdecl("main")
func main() -> Int {
  let fcitxToMacOk = testFcitxToMac()
  return fcitxToMacOk ? 0 : 1
}
