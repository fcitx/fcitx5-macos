import AppKit

func grayScale(gray: CGFloat, alpha: CGFloat) -> NSColor {
  let components: [CGFloat] = [gray, alpha]
  return NSColor(cgColor: CGColor(colorSpace: CGColorSpaceCreateDeviceGray(), components: components)!)!
}

@_cdecl("main")
@MainActor
func main() -> Int {
  var failed = false

  let sRGBColor = NSColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
  let sRGBString = nsColorToString(sRGBColor)
  if sRGBColor.cgColor.components?.count != 4 {
    print("sRGB components count: expected 4, got \(sRGBColor.cgColor.components?.count as Any)")
    failed = true
  }
  if sRGBString != "#1A334D66" {
    print("sRGB: expected #1A334D66, got \(sRGBString ?? "nil")")
    failed = true
  }

  let grayColor = grayScale(gray: 0.5, alpha: 1.0)
  let grayString = nsColorToString(grayColor)
  if grayColor.cgColor.components?.count != 2 {
    print("grayScale components count: expected 2, got \(grayColor.cgColor.components?.count as Any)")
    failed = true
  }
  if grayString != "#808080FF" {
    print("grayScale: expected #808080FF, got \(grayString ?? "nil")")
    failed = true
  }

  let accentColor = getAccentColor("com.apple.Notes")
  if accentColor != "#FCB827FF" {
    print("getAccentColor(com.apple.Notes): expected #FCB827FF, got \(accentColor)")
    failed = true
  }

  return failed ? 1 : 0
}
