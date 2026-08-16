func testPrefixForStatusItem() -> Bool {
  let cases: [(String, String)] = [
    ("", "🐧"),
    ("A", "A"),
    ("拼", "拼"),
    ("en", "en"),
    ("双拼", "双"),
    ("Bamboo", "Ba"),
  ]
  var failed = false
  for (input, expected) in cases {
    let actual = prefixForStatusItem(input)
    if actual != expected {
      print("prefixForStatusItem(\(input)): expected \(expected), got \(actual)")
      failed = true
    }
  }
  return !failed
}

@_cdecl("main")
func main() -> Int {
  return testPrefixForStatusItem() ? 0 : 1
}
