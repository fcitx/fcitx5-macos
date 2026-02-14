import SwiftUI

struct UnknownView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    Text("Unsupported option type \(data["Type"] as? String ?? "")")
  }
}
