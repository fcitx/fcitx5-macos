import AlertToast
import Fcitx
import Logging
import SwiftUI
import UniformTypeIdentifiers

let dictDir = pinyinLocalDir.appendingPathComponent("dictionaries")
let dictPath = dictDir.localPath()

private let binDir = libraryDir.appendingPathComponent("bin")

func importDict(_ file: URL) -> Bool {
  return copyFile(file, dictDir.appendingPathComponent(file.lastPathComponent))
}

func importTxtDict(_ file: URL) -> Bool {
  let path = file.localPath()
  FCITX_INFO("Importing \(path)")
  let converter = binDir.appendingPathComponent("libime_pinyindict").localPath()
  let name = file.deletingPathExtension().lastPathComponent
  return exec(
    converter,
    [path, dictDir.appendingPathComponent(name).appendingPathExtension("dict").localPath()])
}

func importScelDict(_ file: URL) -> Bool {
  let path = file.localPath()
  FCITX_INFO("Importing \(path)")
  let converter = binDir.appendingPathComponent("scel2org5").localPath()
  let name = "/tmp/\(file.deletingPathExtension().lastPathComponent).txt"
  if exec(converter, ["-o", name, path]) {
    return importTxtDict(URL(fileURLWithPath: name))
  }
  return false
}

struct Dict: Identifiable, Hashable {
  let id: String
}

class DictVM: ObservableObject {
  @Published var isEnabled: [String: Bool] = [:]
  @Published private(set) var dicts: [Dict] = []

  func refreshDicts() {
    let enabled = getFileNamesWithExtension(dictPath, ".dict")
    let disabled = getFileNamesWithExtension(dictPath, ".dict.disable")
    dicts = (enabled + disabled).sorted().map { Dict(id: $0) }
    isEnabled = [:]
    for d in enabled {
      isEnabled[d] = true
    }
    for d in disabled {
      isEnabled[d] = false
    }
  }
}

struct DictManagerView: View {
  @Environment(\.dismiss) private var dismiss

  @AppStorage("DictManagerSelectedDirectory") var dictManagerSelectedDirectory: String?
  @State private var selectedDicts = Set<String>()
  @ObservedObject private var dictVM = DictVM()
  @State private var failure = 0
  @State private var showFailure = false
  @State private var showCleared = false

  func refreshDicts() -> some View {
    dictVM.refreshDicts()
    return self
  }

  private func reloadDicts() {
    _ = refreshDicts()
    Fcitx.setConfig("fcitx://config/addon/pinyin/dictmanager", "{}")
  }

  var body: some View {
    HStack {
      List(selection: $selectedDicts) {
        ForEach(dictVM.dicts) { dict in
          // Separate so clicking text doesn't toggle checkbox.
          HStack(alignment: .center) {
            Toggle(
              "",
              isOn: Binding(
                get: { dictVM.isEnabled[dict.id]! },
                set: {
                  dictVM.isEnabled[dict.id] = $0
                  let enabledPath = dictDir.appendingPathComponent(dict.id + ".dict")
                  let disabledPath = dictDir.appendingPathComponent(dict.id + ".dict.disable")
                  if $0 {
                    let _ = moveFile(disabledPath, enabledPath)
                  } else {
                    let _ = moveFile(enabledPath, disabledPath)
                  }
                  reloadDicts()
                }
              )
            ).accessibilityIdentifier("\(dict.id)_Checkbox")
            Text(dict.id).accessibilityIdentifier(dict.id)
          }
        }
      }
      VStack {
        SelectFileButton(
          directory: dictDir,
          allowedSuffixes: [".dict", ".scel", ".txt"],
          allowsMultipleSelection: true,
          initialDirectory: URL(
            fileURLWithPath: dictManagerSelectedDirectory
              ?? homeDir.appendingPathComponent("Downloads").localPath()),
          hasFile: false,
          label: { Text("Import dictionaries") },
          onImport: { _, files in
            mkdirP(dictPath)
            var failCount = 0
            for fileName in files {
              let file = dictDir.appendingPathComponent(fileName)
              let ok: Bool
              switch file.pathExtension {
              case "dict": ok = true
              case "scel": ok = importScelDict(file)
              case "txt": ok = importTxtDict(file)
              default: ok = false
              }
              if file.pathExtension == "scel" || file.pathExtension == "txt" {
                let _ = removeFile(file)
              }
              if !ok { failCount += 1 }
            }
            if failCount > 0 {
              failure = failCount
              showFailure = true
            }
            reloadDicts()
          },
          onDirectoryChanged: { dirURL in
            dictManagerSelectedDirectory = dirURL?.localPath()
          },
          accessibilityId: "ImportDicts"
        ) {
          Text("Click or drag .txt/.scel/.dict file here")
        }

        urlButton(
          NSLocalizedString("Sogou Cell Dictionary", comment: ""), "https://pinyin.sogou.com/dict/")

        Button {
          for dict in selectedDicts {
            let suffix = dictVM.isEnabled[dict] == true ? ".dict" : ".dict.disable"
            let _ = removeFile(dictDir.appendingPathComponent(dict + suffix))
          }
          selectedDicts.removeAll()
          reloadDicts()
        } label: {
          Text("Remove dictionaries")
        }.disabled(selectedDicts.isEmpty)
          .accessibilityIdentifier("RemoveDicts")

        Button {
          Fcitx.setConfig("fcitx://config/addon/pinyin/clearuserdict", "{}")
          Fcitx.reload()
          showCleared = true
        } label: {
          Text("Clear user data")
        }

        Button {
          Fcitx.setConfig("fcitx://config/addon/pinyin/clearalldict", "{}")
          Fcitx.reload()
          showCleared = true
        } label: {
          Text("Clear all data")
        }

        Button {
          mkdirP(dictPath)
          NSWorkspace.shared.open(dictDir)
        } label: {
          Text("Open dictionary directory")
        }

        Button {
          dismiss()
        } label: {
          Text("Close")
        }.accessibilityIdentifier("CloseSheet")
      }
    }.padding()
      .frame(minWidth: 300)
      .toast(isPresenting: $showFailure) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: String(
            format: NSLocalizedString("Failed to import %@ dict(s)", comment: ""), String(failure)))
      }
      .toast(isPresenting: $showCleared) {
        AlertToast(
          displayMode: .hud, type: .complete(Color.green),
          title: NSLocalizedString("Cleared", comment: ""))
      }
  }
}
