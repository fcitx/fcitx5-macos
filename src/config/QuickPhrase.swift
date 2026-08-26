import AlertToast
import Fcitx
import SwiftUI

private let globalQuickphrasePath =
  "/Library/Input Methods/Fcitx5.app/Contents/share/fcitx5/data/quickphrase.d"
private let globalQuickphraseDir = URL(fileURLWithPath: globalQuickphrasePath)
let localQuickphraseDir = localDir.appendingPathComponent("data/quickphrase.d")
let localQuickphrasePath = localQuickphraseDir.localPath()

class QuickPhraseVM: ObservableObject {
  @Published var selectedRows = Set<UUID>()
  @Published var current = "" {
    didSet {
      selectedRows.removeAll()
    }
  }
  @Published private(set) var userFiles: [String] = []
  @Published private(set) var builtinFiles = Set<String>()
  @Published private(set) var disabledFiles = Set<String>()
  @Published private(set) var files: [String] = []
  @Published var quickPhrases: [String: [QuickPhrase]] = [:]

  func refreshFiles() {
    quickPhrases = [:]
    let globalFiles = getFileNamesWithExtension(globalQuickphrasePath, ".mb")
    builtinFiles = Set(globalFiles)
    userFiles = getFileNamesWithExtension(localQuickphrasePath, ".mb")
    disabledFiles = Set(getFileNamesWithExtension(localQuickphrasePath, ".mb.disable"))
    for file in userFiles {
      quickPhrases[file] = stringToQuickPhrases(
        readUTF8(localQuickphraseDir.appendingPathComponent(file + ".mb")) ?? "")
    }
    files = userFiles
    for file in globalFiles {
      if !userFiles.contains(file) {
        files.append(file)
        quickPhrases[file] = stringToQuickPhrases(
          readUTF8(globalQuickphraseDir.appendingPathComponent(file + ".mb")) ?? "")
      }
    }
    if files.isEmpty {
      current = ""
    } else if current.isEmpty || !files.contains(current) {
      current = files[0]
    }
  }

  func isBuiltin(_ file: String) -> Bool {
    builtinFiles.contains(file)
  }

  func isDisabled(_ file: String) -> Bool {
    disabledFiles.contains(file)
  }
}

struct QuickPhrase: Identifiable {
  let id = UUID()
  var keyword: String
  var phrase: String
}

private func parseLine(_ s: String) -> QuickPhrase? {
  let regex = try! NSRegularExpression(pattern: "(\\S+)\\s+(\\S.*)", options: [])
  let matches = regex.matches(
    in: s, options: [], range: NSRange(location: 0, length: s.utf16.count))

  if let match = matches.first {
    let keyword = String(s[Range(match.range(at: 1), in: s)!])
    let phrase = String(s[Range(match.range(at: 2), in: s)!])
    return QuickPhrase(keyword: keyword, phrase: phrase)
  }
  return nil
}

private func stringToQuickPhrases(_ s: String) -> [QuickPhrase] {
  return s.split(separator: "\n").compactMap { line in
    parseLine(String(line))
  }
}

private func quickPhrasesToString(_ quickPhrases: [QuickPhrase]) -> String {
  return quickPhrases.map { quickPhrase in
    "\(quickPhrase.keyword) \(quickPhrase.phrase)"
  }.joined(separator: "\n")
}

struct QuickPhraseView: View {
  @Environment(\.dismiss) var dismiss

  @State private var showNewFile = false
  @State private var newFileName = ""
  @ObservedObject private var quickphraseVM = QuickPhraseVM()
  @State private var showReloaded = false
  @State private var showCreateFailed = false
  @State private var showRemoveFailed = false
  @State private var showSaved = false
  @State private var showSavedFailure = false

  func refreshFiles() -> some View {
    quickphraseVM.refreshFiles()
    return self
  }

  func reloadQuickPhrase() {
    _ = refreshFiles()
    Fcitx.setConfig("fcitx://config/addon/quickphrase/editor", "{}")
  }

  private var isCurrentFileEditable: Bool {
    let file = quickphraseVM.current
    return !file.isEmpty && !quickphraseVM.isBuiltin(file) && !quickphraseVM.isDisabled(file)
  }

  private func setBuiltinQuickPhraseEnabled(_ enabled: Bool) -> Bool {
    let file = quickphraseVM.current
    let disabledURL = localQuickphraseDir.appendingPathComponent(file + ".mb.disable")

    mkdirP(localQuickphrasePath)
    if enabled {
      return removeFile(disabledURL)
    }
    return writeUTF8(disabledURL, "")
  }

  var body: some View {
    HStack {
      VStack {
        Picker("", selection: $quickphraseVM.current) {
          ForEach(quickphraseVM.files, id: \.self) { file in
            Text(file)
          }
        }
        List(selection: $quickphraseVM.selectedRows) {
          HStack {
            Text("Keyword").frame(
              minWidth: minKeywordColumnWidth, maxWidth: .infinity, alignment: .leading)
            Text("Phrase").frame(
              minWidth: minPhraseColumnWidth, maxWidth: .infinity, alignment: .leading)
          }
          .font(.headline)

          ForEach(
            Binding(
              get: { quickphraseVM.quickPhrases[quickphraseVM.current] ?? [] },
              set: { quickphraseVM.quickPhrases[quickphraseVM.current] = $0 }
            )
          ) { $quickPhrase in
            // Disallow editing built-in files, but still use TextField for disabled status so that there is visual difference for enabled/disabled.
            HStack {
              if quickphraseVM.isBuiltin(quickphraseVM.current)
                && !quickphraseVM.isDisabled(quickphraseVM.current)
              {
                Text(quickPhrase.keyword).frame(
                  minWidth: minKeywordColumnWidth, maxWidth: .infinity, alignment: .leading)
                Text(quickPhrase.phrase).frame(
                  minWidth: minPhraseColumnWidth, maxWidth: .infinity, alignment: .leading)
              } else {
                TextField("Keyword", text: $quickPhrase.keyword).frame(
                  minWidth: minKeywordColumnWidth, maxWidth: .infinity, alignment: .leading)
                TextField("Phrase", text: $quickPhrase.phrase).frame(
                  minWidth: minPhraseColumnWidth, maxWidth: .infinity, alignment: .leading)
              }
            }
          }
        }.disabled(quickphraseVM.isDisabled(quickphraseVM.current))
      }
      VStack {
        Button {
          reloadQuickPhrase()
          showReloaded = true
        } label: {
          Text("Reload")
        }

        Button {
          showNewFile = true
        } label: {
          Text("New file")
        }

        Button {
          let newItem = QuickPhrase(keyword: "", phrase: "")
          quickphraseVM.quickPhrases[quickphraseVM.current]?.append(newItem)
          quickphraseVM.selectedRows = [newItem.id]
        } label: {
          Text("Add item")
        }.disabled(!isCurrentFileEditable)
          .accessibilityIdentifier("AddItem")

        Button {
          quickphraseVM.quickPhrases[quickphraseVM.current]?.removeAll {
            quickphraseVM.selectedRows.contains($0.id)
          }
          quickphraseVM.selectedRows.removeAll()
        } label: {
          Text("Remove items")
        }.disabled(quickphraseVM.selectedRows.isEmpty || !isCurrentFileEditable)
          .accessibilityIdentifier("RemoveItems")

        Button {
          mkdirP(localQuickphrasePath)
          if writeUTF8(
            localQuickphraseDir.appendingPathComponent(quickphraseVM.current + ".mb"),
            quickPhrasesToString(quickphraseVM.quickPhrases[quickphraseVM.current] ?? []) + "\n")
          {
            showSaved = true
            reloadQuickPhrase()
          } else {
            showSavedFailure = true
          }
        } label: {
          Text("Save")
        }.disabled(!isCurrentFileEditable)
          .accessibilityIdentifier("Save")
          .buttonStyle(.borderedProminent)

        Button {
          let localURL = localQuickphraseDir.appendingPathComponent(quickphraseVM.current + ".mb")
          var ret: Bool
          if quickphraseVM.isBuiltin(quickphraseVM.current) {
            ret = setBuiltinQuickPhraseEnabled(
              quickphraseVM.isDisabled(quickphraseVM.current))
          } else {
            ret = removeFile(localURL)
          }
          if ret {
            reloadQuickPhrase()
          } else {
            showRemoveFailed = true
          }
        } label: {
          if quickphraseVM.isBuiltin(quickphraseVM.current) {
            if quickphraseVM.isDisabled(quickphraseVM.current) {
              Text("Enable")
            } else {
              Text("Disable")
            }
          } else {
            Text("Remove")
          }
        }.disabled(quickphraseVM.current.isEmpty)
          .accessibilityIdentifier("ToggleOrRemove")

        Button {
          mkdirP(localQuickphrasePath)
          let localURL = localQuickphraseDir.appendingPathComponent(quickphraseVM.current + ".mb")
          if !localURL.exists() {
            if !copyFile(
              globalQuickphraseDir.appendingPathComponent(quickphraseVM.current + ".mb"),
              localURL)
            {
              showCreateFailed = true
              return
            }
          }
          openInEditor(url: localURL)
        } label: {
          Text("Open in editor")
        }.disabled(!isCurrentFileEditable)
          .accessibilityIdentifier("OpenInEditor")

        Button {
          mkdirP(localQuickphrasePath)
          NSWorkspace.shared.open(localQuickphraseDir)
        } label: {
          Text("Open directory")
        }

        Button {
          dismiss()
        } label: {
          Text("Close")
        }.accessibilityIdentifier("CloseSheet")
      }
      .sheet(isPresented: $showNewFile) {
        VStack {
          HStack {
            Text("Name")
            TextField("", text: $newFileName)
          }
          HStack {
            Button {
              showNewFile = false
            } label: {
              Text("Cancel")
            }
            Button {
              mkdirP(localQuickphrasePath)
              let localURL = localQuickphraseDir.appendingPathComponent(newFileName + ".mb")
              if !writeUTF8(localURL, "") {
                showCreateFailed = true
                return
              }
              showNewFile = false
              _ = refreshFiles()
              quickphraseVM.current = newFileName
              newFileName = ""
            } label: {
              Text("Create")
            }.buttonStyle(.borderedProminent)
              .disabled(newFileName.isEmpty || quickphraseVM.userFiles.contains(newFileName))
          }
        }.padding()
          .frame(minWidth: 200)
      }
    }.padding()
      .frame(minWidth: 500, minHeight: 300)
      .toast(isPresenting: $showReloaded) {
        AlertToast(
          displayMode: .hud, type: .complete(Color.green),
          title: NSLocalizedString("Reloaded", comment: ""))
      }
      .toast(isPresenting: $showSaved) {
        AlertToast(
          displayMode: .hud, type: .complete(Color.green),
          title: NSLocalizedString("Saved", comment: ""))
      }
      .toast(isPresenting: $showSavedFailure) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Failed to save", comment: ""))
      }
      .toast(isPresenting: $showCreateFailed) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Failed to create", comment: ""))
      }
      .toast(isPresenting: $showRemoveFailed) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Failed to remove", comment: ""))
      }
  }
}
