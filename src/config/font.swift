import Cocoa
import CoreText

let userFontDir = homeDir.appendingPathComponent("Library/Fonts")

func fontFamilies(from url: URL) -> Set<String> {
  guard
    let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor]
  else {
    return []
  }
  var families = Set<String>()
  for descriptor in descriptors {
    if let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String
    {
      families.insert(family)
    }
  }
  return families
}

func enumerateUserFontFamilies() -> Set<String> {
  var families = Set<String>()
  if let contents = try? FileManager.default.contentsOfDirectory(
    at: userFontDir, includingPropertiesForKeys: [.isDirectoryKey]
  ) {
    for url in contents {
      var isDir: ObjCBool = false
      if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
        families.formUnion(fontFamilies(from: url))
      }
    }
  }
  return families
}

@MainActor var userFontFamiliesOnStart = Set<String>()

@MainActor func initUserFontFamiliesOnStart() {
  Task.detached {
    let families = enumerateUserFontFamilies()
    await MainActor.run {
      userFontFamiliesOnStart = families
    }
  }
}
