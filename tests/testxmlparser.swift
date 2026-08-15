import Foundation

@_cdecl("main")
func main() -> Int {
  if CommandLine.argc != 2 {
    print("Usage: \(CommandLine.arguments[0]) <.plist file>")
    return 1
  }
  let url = URL(fileURLWithPath: CommandLine.arguments[1])
  let expected = [(shortcut: "msd", phrase: "马上到！"), (shortcut: "omw", phrase: "On my way!")]
  let actual = parseCustomPhraseXML(url)
  var failed = false
  if actual.count != expected.count {
    print("count: expected \(expected.count), got \(actual.count)")
    failed = true
  }
  for i in 0..<min(actual.count, expected.count) {
    if actual[i].shortcut != expected[i].shortcut {
      print("shortcut[\(i)]: expected \(expected[i].shortcut), got \(actual[i].shortcut)")
      failed = true
    }
    if actual[i].phrase != expected[i].phrase {
      print("phrase[\(i)]: expected \(expected[i].phrase), got \(actual[i].phrase)")
      failed = true
    }
  }
  return failed ? 1 : 0
}
