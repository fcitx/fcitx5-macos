import Foundation

@_cdecl("main")
func main() -> Int {
  // targetTag can be nil, version or latest. When latestAvailable is false, targetTag can't be latest.
  // So it's a combination of 2*2*5 = 20 cases.
  var failed = false

  // Release to Release
  // latest >> stable = current
  let cases: [(String, Bool, Bool, Bool, String?, String?)] = [
    // Release to Release
    // latest >> stable = current
    ("release->release latest>>stable=current", false, false, false, nil, nil),
    // latest >> stable > current
    ("release->release latest>>stable>current", false, false, false, "1", "1"),
    // latest = current
    ("release->release latest=current", false, false, true, nil, nil),
    // stable > current
    ("release->release stable>current", false, false, true, "1", "1"),
    // latest > current >= stable
    ("release->release latest>current>=stable", false, false, true, "latest", "latest"),

    // Release to Debug
    // latest = current
    ("release->debug latest=current", false, true, true, nil, "latest"),
    // stable > current
    ("release->debug stable>current", false, true, true, "1", "latest"),
    // latest > current >= stable
    ("release->debug latest>current>=stable", false, true, true, "latest", "latest"),

    // Debug to Release
    // latest >> stable > current
    ("debug->release latest>>stable>current", true, false, false, "1", "1"),
    // latest = current
    ("debug->release latest=current", true, false, true, nil, "latest"),
    // stable > current
    ("debug->release stable>current", true, false, true, "1", "1"),
    // latest > current >= stable
    ("debug->release latest>current>=stable", true, false, true, "latest", "latest"),

    // Debug to Debug
    // stable > current
    ("debug->debug stable>current", true, true, true, "1", "latest"),
    // latest > current >= stable
    ("debug->debug latest>current>=stable", true, true, true, "latest", "latest"),
  ]
  for (name, currentDebug, targetDebug, latestAvailable, targetTag, expected) in cases {
    let actual = getTag(
      currentDebug: currentDebug, targetDebug: targetDebug, latestAvailable: latestAvailable,
      targetTag: targetTag)
    if actual != expected {
      print("\(name): expected \(expected as Any), got \(actual as Any)")
      failed = true
    }
  }

  // Release to Debug: Switch button not clickable, result ignored.
  let _ = getTag(currentDebug: false, targetDebug: true, latestAvailable: false, targetTag: nil)
  let _ = getTag(currentDebug: false, targetDebug: true, latestAvailable: false, targetTag: "1")
  // Debug to Release: We don't provide debug stable.
  let _ = getTag(currentDebug: true, targetDebug: false, latestAvailable: false, targetTag: nil)
  // Debug to Debug: We don't provide debug stable; Update button not clickable.
  let _ = getTag(currentDebug: true, targetDebug: true, latestAvailable: false, targetTag: nil)
  let _ = getTag(currentDebug: true, targetDebug: true, latestAvailable: false, targetTag: "1")
  let _ = getTag(currentDebug: true, targetDebug: true, latestAvailable: true, targetTag: nil)

  return failed ? 1 : 0
}
