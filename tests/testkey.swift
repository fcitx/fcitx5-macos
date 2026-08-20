func expectShortcut(_ name: String, _ expected: (String, String?), _ actual: (String, String?)) -> Bool {
  if actual.0 == expected.0 && actual.1 == expected.1 {
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
  return ok
}

@_cdecl("main")
func main() -> Int {
  let fcitxToMacOk = testFcitxToMac()
  return fcitxToMacOk ? 0 : 1
}
