import AlertToast
import Fcitx
import SwiftUI

private let en = "en"
private let popularIMs = [
  "keyboard-us", "pinyin", "shuangpin", "wbx", "rime", "mozc", "hallelujah",
]

private func normalizeLanguageCode(_ code: String) -> String {
  if code.isEmpty {
    return ""
  }
  return String(code.split(separator: "_")[0])
}

private func languageCodeMatch(_ code: String, _ languagesOfEnabledIMs: Set<String>) -> Bool {
  guard let languageCode = Locale.current.language.languageCode?.identifier else {
    return true
  }
  if code == en {
    return true
  }
  let normalized = normalizeLanguageCode(code)
  return normalized == languageCode || languagesOfEnabledIMs.contains(normalized)
}

class AvailableIMViewModel: ObservableObject {
  @AppStorage("AddIMOnlyShowCurrentLanguage") var addIMOnlyShowCurrentLanguage: Bool?
  @Published var availableIMs = [String: [InputMethod]]()
  @Published var selectedLanguageCode: String? {
    didSet {
      updateList()
    }
  }
  @Published var alreadyEnabled = Set<String>() {
    didSet {
      updateList()
    }
  }
  @Published var availableIMsForLanguage = [InputMethod]()
  var languagesOfEnabledIMs = Set<String>()

  private func updateList() {
    guard let selectedLanguageCode = selectedLanguageCode,
      let ims = availableIMs[selectedLanguageCode]
    else {
      availableIMsForLanguage = []
      return
    }
    availableIMsForLanguage = ims.filter { !alreadyEnabled.contains($0.name) }.sorted {
      a, b in
      let ia = popularIMs.firstIndex(of: a.name)
      let ib = popularIMs.firstIndex(of: b.name)
      if ia == nil && ib != nil {
        return false
      }
      if ia != nil && ib == nil {
        return true
      }
      if let ia = ia, let ib = ib {
        return ia < ib
      }
      return a.displayName.localizedCompare(b.displayName) == .orderedAscending
    }
  }

  func refresh(_ alreadyEnabled: Set<String>) {
    availableIMs.removeAll()
    languagesOfEnabledIMs.removeAll()
    let array = decodeJSON(String(Fcitx.imGetAvailableIMs()), [InputMethod]())
    for im in array {
      let code = im.languageCode.isEmpty ? "und" : im.languageCode
      availableIMs[code, default: []].append(im)
      if alreadyEnabled.contains(im.name) {
        languagesOfEnabledIMs.update(with: normalizeLanguageCode(code))
      }
    }
    self.alreadyEnabled = alreadyEnabled
  }
}

struct LocalizedLanguageCode: Comparable {
  let code: String
  let localized: String

  init(code: String) {
    self.code = code
    var localized = Locale.current.localizedString(forIdentifier: code) ?? ""
    if localized.isEmpty {
      localized = String(isoName(code))
    }
    if localized.isEmpty {
      localized = String(format: NSLocalizedString("Unknown - %@", comment: ""), code)
    }
    self.localized = localized
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    if lhs.code == en {
      return true
    }
    if rhs.code == en {
      return false
    }
    let curIdent = Locale.current.identifier.prefix(2)
    let le = lhs.code.prefix(2) == curIdent
    let re = rhs.code.prefix(2) == curIdent
    if le && !re {
      return true
    }
    if !le && re {
      return false
    }
    return lhs.localized.localizedCompare(rhs.localized) == .orderedAscending
  }
}

private func languages(viewModel: AvailableIMViewModel) -> [LocalizedLanguageCode] {
  return Array(viewModel.availableIMs.keys)
    .filter {
      !(viewModel.addIMOnlyShowCurrentLanguage ?? false)
        || languageCodeMatch($0, viewModel.languagesOfEnabledIMs)
    }
    .map { LocalizedLanguageCode(code: $0) }
    .sorted()
}

struct AvailableInputMethodView: View {
  @Environment(\.presentationMode) var presentationMode

  @StateObject private var viewModel = AvailableIMViewModel()
  @State private var selection = Set<InputMethod>()
  @State private var enabled = Set<String>()
  @State private var showImportTable = false
  @State private var importTableErrorMsg = ""
  @State private var showImportTableError = false

  @Binding var group: Group?
  let onImport: () -> Void
  let onAdd: (Set<InputMethod>) -> Void

  var body: some View {
    NavigationSplitView {
      List(selection: $viewModel.selectedLanguageCode) {
        ForEach(languages(viewModel: viewModel), id: \.code) { language in
          Text(language.localized)
        }
      }
      Toggle(
        NSLocalizedString("Only show current language", comment: ""),
        isOn: Binding(
          get: { viewModel.addIMOnlyShowCurrentLanguage ?? false },
          set: { viewModel.addIMOnlyShowCurrentLanguage = $0 }
        )
      ).padding([.horizontal, .bottom], 8)
    } detail: {
      VStack {
        if viewModel.selectedLanguageCode != nil {
          List(selection: $selection) {
            ForEach(viewModel.availableIMsForLanguage, id: \.self) { im in
              Text(im.displayName).fontWeight(popularIMs.contains(im.name) ? .bold : .regular)
            }
          }.contextMenu(forSelectionType: InputMethod.self) { _ in
          } primaryAction: { items in
            onAdd(items)
            enabled.formUnion(items.map { $0.name })
            viewModel.refresh(enabled)
          }
        } else {
          Text("Select a language from the left list.").frame(maxHeight: .infinity)
        }

        HStack {
          Button {
            presentationMode.wrappedValue.dismiss()
          } label: {
            Text("Cancel")
          }

          Spacer()

          if viewModel.availableIMs["zh_CN"]?.contains(where: { $0.name == "pinyin" }) == true {
            Button {
              showImportTable = true
            } label: {
              Text("Import customized table")
            }
          }
          Button {
            onAdd(selection)
            presentationMode.wrappedValue.dismiss()
          } label: {
            Text("Add")
          }.buttonStyle(.borderedProminent)
            .disabled(selection.isEmpty)
        }.padding([.horizontal, .bottom])
      }
    }
    .frame(minWidth: 640, minHeight: 480)
    .onAppear {
      enabled = Set(group?.inputMethods.map { $0.name } ?? [])
      viewModel.refresh(enabled)
    }
    .sheet(isPresented: $showImportTable) {
      ImportTableView(
        onAdd: { newIMs in
          onAdd(Set(newIMs.map { InputMethod(name: $0, displayName: $0, languageCode: "") }))
        },
        onError: { msg in
          importTableErrorMsg = msg
          showImportTableError = true
        },
        finalize: {
          onImport()
        })
    }
    .toast(isPresenting: $showImportTableError) {
      AlertToast(
        displayMode: .hud,
        type: .error(Color.red), title: importTableErrorMsg)
    }
  }
}
