import Carbon

let arguments = CommandLine.arguments

if arguments.count < 2 {
  exit(1)
}

let im = arguments[1]

let conditions = NSMutableDictionary()
conditions.setValue(im, forKey: kTISPropertyInputSourceID as String)
if let array = TISCreateInputSourceList(conditions, true)?.takeRetainedValue()
  as? [TISInputSource]
{
  for inputSource in array {
    let status = TISSelectInputSource(inputSource)
    guard status == noErr else {
      fputs("Failed to select input source \(im) (OSStatus \(status))\n", stderr)
      exit(1)
    }
    exit(0)
  }
}

fputs("Input source not found: \(im)\n", stderr)
exit(1)
