import AlertToast
import Fcitx
import SwiftUI

let pinyinPath = pinyinLocalDir.localPath()

let customphrase = pinyinLocalDir.appendingPathComponent("customphrase")
let nativeCustomPhrase = cacheDir.appendingPathComponent("customphrase.plist")

struct CustomPhrase: Identifiable, Codable {
  let id = UUID()  // To support uninterrupted in-place edit, id can't be hash of content.
  var keyword: String
  var phrase: String
  var order: Int
  var enabled: Bool

  enum CodingKeys: String, CodingKey {
    case keyword, phrase, order, enabled
  }
}

class CustomPhraseVM: ObservableObject {
  @Published var customPhrases = [CustomPhrase]()

  func refreshItems() {
    customPhrases = decodeJSON(String(customphrase_get(customphrase.localPath())), [CustomPhrase]())
  }
}

struct CustomPhraseView: View {
  @Environment(\.dismiss) private var dismiss

  @State private var selectedRows = Set<UUID>()
  private let pageSize = 10
  @State private var currentPage = 0
  @ObservedObject private var customphraseVM = CustomPhraseVM()
  @State private var showReloaded = false
  @State private var importedPhrases = 0
  @State private var showImportedPhrases = false
  @State private var showSaved = false
  // Test: cd ~/.local/share/fcitx5; sudo chown root pinyin
  @State private var showSavedFailure = false
  @State private var showCreateFailed = false

  func refreshItems() {
    selectedRows = []
    currentPage = 0
    customphraseVM.refreshItems()
  }

  func reloadCustomPhrase() {
    refreshItems()
    Fcitx.setConfig("fcitx://config/addon/pinyin/customphrase", "{}")
  }

  private var totalPages: Int {
    max(1, (customphraseVM.customPhrases.count + pageSize - 1) / pageSize)
  }

  private var currentPageItems: Range<Int> {
    let start = currentPage * pageSize
    let end = min(start + pageSize, customphraseVM.customPhrases.count)
    guard start < end else { return 0..<0 }
    return start..<end
  }

  private var currentPageSlice: Binding<[CustomPhrase]> {
    let range = currentPageItems
    return Binding(
      get: { Array(self.customphraseVM.customPhrases[range]) },
      set: { newValue in
        for (i, item) in zip(range, newValue) {
          self.customphraseVM.customPhrases[i] = item
        }
      }
    )
  }

  private func save() -> Bool {
    mkdirP(pinyinPath)
    guard let json = encodeJSON(customphraseVM.customPhrases.filter { !$0.keyword.isEmpty }),
      customphrase_set(customphrase.localPath(), json)
    else { return false }
    reloadCustomPhrase()
    return true
  }

  var body: some View {
    HStack {
      VStack {
        List(selection: $selectedRows) {
          HStack {
            Text("").frame(width: checkboxColumnWidth)
            Text("Keyword").frame(
              minWidth: minKeywordColumnWidth, maxWidth: .infinity, alignment: .leading)
            Text("Phrase").frame(
              minWidth: minPhraseColumnWidth, maxWidth: .infinity, alignment: .leading)
            Text("Order").frame(
              minWidth: minKeywordColumnWidth, maxWidth: .infinity, alignment: .leading)
          }
          .font(.headline)
          ForEach(currentPageSlice) { $customPhrase in
            HStack(alignment: .center) {
              Toggle("", isOn: $customPhrase.enabled).frame(width: checkboxColumnWidth)
                .accessibilityIdentifier("Checkbox")
              TextField("Keyword", text: $customPhrase.keyword).frame(
                minWidth: minKeywordColumnWidth, maxWidth: .infinity, alignment: .leading
              )
              .accessibilityIdentifier("Keyword")
              TextField("Phrase", text: $customPhrase.phrase).frame(
                minWidth: minPhraseColumnWidth, maxWidth: .infinity, alignment: .leading
              )
              .accessibilityIdentifier("Phrase")
              TextField("Order", value: $customPhrase.order, formatter: numberFormatter)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("Order")
            }
          }
        }
        HStack {
          Button {
            currentPage = max(0, currentPage - 1)
          } label: {
            Image(systemName: "chevron.left")
          }.disabled(currentPage == 0)
          TextField(
            "",
            value: Binding(
              get: { currentPage + 1 },
              set: { currentPage = max(0, min(totalPages - 1, $0 - 1)) }
            ), formatter: numberFormatter
          )
          .frame(width: 50)
          .multilineTextAlignment(.center)
          .accessibilityIdentifier("Page")
          Text("/ \(totalPages)")
            .accessibilityIdentifier("TotalPages")
          Button {
            currentPage = min(totalPages - 1, currentPage + 1)
          } label: {
            Image(systemName: "chevron.right")
          }.disabled(currentPage >= totalPages - 1)
        }
      }

      VStack {
        Button {
          reloadCustomPhrase()
          showReloaded = true
        } label: {
          Text("Reload")
        }.accessibilityIdentifier("Reload")

        Button {
          mkdirP(cacheDir.localPath())
          if exec(
            "/bin/zsh",
            ["-c", "/usr/bin/defaults export -g - > \(quote(nativeCustomPhrase.localPath()))"])
          {
            let phrasesMap = customphraseVM.customPhrases.reduce(into: [String: [CustomPhrase]]()) {
              result, customPhrase in
              result[customPhrase.keyword, default: []].append(customPhrase)
            }
            importedPhrases = 0
            for (shortcut, phrase) in parseCustomPhraseXML(nativeCustomPhrase) {
              if let array = phrasesMap[shortcut], array.contains(where: { $0.phrase == phrase }) {
                continue
              }
              let newItem = CustomPhrase(keyword: shortcut, phrase: phrase, order: 1, enabled: true)
              customphraseVM.customPhrases.append(newItem)
              importedPhrases += 1
            }
            if save() {
              showImportedPhrases = true
              _ = removeFile(nativeCustomPhrase)
            } else {
              showSavedFailure = true
            }
          }
        } label: {
          Text("Import native custom phrases")
        }

        Button {
          let newItem = CustomPhrase(keyword: "", phrase: "", order: 1, enabled: true)
          customphraseVM.customPhrases.append(newItem)
          currentPage = totalPages - 1
          selectedRows = [newItem.id]
        } label: {
          Text("Add item")
        }.accessibilityIdentifier("AddItem")

        Button {
          customphraseVM.customPhrases.removeAll {
            selectedRows.contains($0.id)
          }
          selectedRows.removeAll()
          if currentPage >= totalPages {
            currentPage = totalPages - 1
          }
        } label: {
          Text("Remove items")
        }.disabled(selectedRows.isEmpty)
          .accessibilityIdentifier("RemoveItems")

        Button {
          if save() {
            showSaved = true
          } else {
            showSavedFailure = true
          }
        } label: {
          Text("Save")
        }.buttonStyle(.borderedProminent)
          .accessibilityIdentifier("Save")

        Button {
          mkdirP(pinyinPath)
          if !customphrase.exists() {
            if !writeUTF8(customphrase, "") {
              showCreateFailed = true
              return
            }
          }
          openInEditor(url: customphrase)
        } label: {
          Text("Open in editor")
        }

        Button {
          dismiss()
        } label: {
          Text("Close")
        }.accessibilityIdentifier("CloseSheet")
      }
    }.padding()
      .frame(minWidth: 600, minHeight: 400)
      .toast(isPresenting: $showReloaded) {
        AlertToast(
          displayMode: .hud, type: .complete(Color.green),
          title: NSLocalizedString("Reloaded", comment: ""))
      }
      .toast(isPresenting: $showImportedPhrases) {
        AlertToast(
          displayMode: .hud, type: .complete(Color.green),
          title: importedPhrases == 0
            ? NSLocalizedString("All phrases are imported", comment: "")
            : String(
              format: NSLocalizedString("Imported %@ phrase(s)", comment: ""),
              String(importedPhrases)))
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
      .onAppear {
        refreshItems()
      }
  }
}
