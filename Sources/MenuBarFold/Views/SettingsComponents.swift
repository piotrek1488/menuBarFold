import SwiftUI

struct SettingsCard<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      content
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(.separator.opacity(0.45), lineWidth: 0.5)
    }
  }
}
