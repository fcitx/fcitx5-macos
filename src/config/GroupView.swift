import SwiftUI

struct GroupView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    GroupBox {
      BasicConfigView(config: data, value: value, onUpdate: { value = $0 })
    }
  }
}
