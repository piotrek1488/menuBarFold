import SwiftUI

struct OverviewSettingsView: View {
  @Bindable var model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        header

        if !model.isAccessibilityGranted {
          permissionCard
        }

        statusCard
        setupCard

        if let lastError = model.lastError {
          errorCard(lastError)
        }
      }
      .padding(28)
      .frame(maxWidth: 680, alignment: .leading)
    }
    .background(.background)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(L10n.string("overview.title", language: model.language))
        .font(.largeTitle.bold())
      Text(L10n.string("overview.subtitle", language: model.language))
        .font(.body)
        .foregroundStyle(.secondary)
    }
  }

  private var permissionCard: some View {
    SettingsCard {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: "hand.raised.fill")
          .font(.title2)
          .foregroundStyle(.orange)
          .frame(width: 30)

        VStack(alignment: .leading, spacing: 8) {
          Text(L10n.string("permission.title", language: model.language))
            .font(.headline)
          Text(L10n.string("permission.explanation", language: model.language))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          HStack {
            Button(L10n.string("permission.request", language: model.language)) {
              model.requestAccessibility()
            }
            .buttonStyle(.borderedProminent)

            Button(L10n.string("permission.openSettings", language: model.language)) {
              model.openAccessibilitySettings()
            }
          }
        }
      }
    }
  }

  private var statusCard: some View {
    SettingsCard {
      HStack(spacing: 18) {
        ZStack {
          Circle()
            .fill(statusColor.opacity(0.14))
          Image(systemName: statusSymbol)
            .font(.system(size: 25, weight: .semibold))
            .foregroundStyle(statusColor)
        }
        .frame(width: 54, height: 54)

        VStack(alignment: .leading, spacing: 4) {
          Text(statusTitle)
            .font(.title3.weight(.semibold))
          Text(statusDescription)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 12)

        Button(primaryButtonTitle) {
          model.toggle()
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.status == .scanning)
      }

      Divider()
        .padding(.vertical, 4)

      HStack(spacing: 24) {
        StatisticView(
          value: model.hiddenAppCount,
          label: L10n.string("overview.hiddenApps", language: model.language)
        )
        StatisticView(
          value: model.alwaysHiddenAppCount,
          label: L10n.string("overview.alwaysHiddenApps", language: model.language)
        )
        Spacer()
      }
    }
  }

  private var setupCard: some View {
    SettingsCard {
      VStack(alignment: .leading, spacing: 14) {
        Text(L10n.string("setup.title", language: model.language))
          .font(.headline)

        SetupStep(
          number: 1,
          title: L10n.string("setup.step1.title", language: model.language),
          detail: L10n.string("setup.step1.detail", language: model.language),
          completed: model.isAccessibilityGranted
        )
        SetupStep(
          number: 2,
          title: L10n.string("setup.step2.title", language: model.language),
          detail: L10n.string("setup.step2.detail", language: model.language),
          completed: model.hasCompletedOnboarding
        )
        SetupStep(
          number: 3,
          title: L10n.string("setup.step3.title", language: model.language),
          detail: L10n.string("setup.step3.detail", language: model.language),
          completed: model.status == .collapsed
        )

        HStack {
          Button(L10n.string("setup.arrange", language: model.language)) {
            model.beginArranging()
          }
          .disabled(!model.isAccessibilityGranted)

          if !model.hasCompletedOnboarding {
            Button(L10n.string("setup.finish", language: model.language)) {
              model.finishOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.isAccessibilityGranted)
          }
        }
      }
    }
  }

  private func errorCard(_ error: String) -> some View {
    SettingsCard {
      Label {
        Text(error)
          .fixedSize(horizontal: false, vertical: true)
      } icon: {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
      }
    }
  }

  private var statusTitle: String {
    let key: String
    switch model.status {
    case .expanded: key = "status.expanded"
    case .arranging: key = "status.arranging"
    case .scanning: key = "status.scanning"
    case .collapsed: key = "status.collapsed"
    case .pausedForCapture: key = "status.pausedForCapture"
    case .needsAccessibility: key = "status.needsAccessibility"
    case .unavailable: key = "status.unavailable"
    }
    return L10n.string(key, language: model.language)
  }

  private var statusDescription: String {
    let key: String
    switch model.status {
    case .expanded: key = "status.expanded.detail"
    case .arranging: key = "status.arranging.detail"
    case .scanning: key = "status.scanning.detail"
    case .collapsed: key = "status.collapsed.detail"
    case .pausedForCapture: key = "status.pausedForCapture.detail"
    case .needsAccessibility: key = "status.needsAccessibility.detail"
    case .unavailable: key = "status.unavailable.detail"
    }
    return L10n.string(key, language: model.language)
  }

  private var statusSymbol: String {
    switch model.status {
    case .collapsed: "rectangle.compress.vertical"
    case .pausedForCapture: "shield.lefthalf.filled"
    case .scanning: "sparkle.magnifyingglass"
    case .needsAccessibility: "hand.raised.fill"
    case .unavailable: "exclamationmark.triangle.fill"
    case .expanded, .arranging: "rectangle.expand.vertical"
    }
  }

  private var statusColor: Color {
    switch model.status {
    case .collapsed: .accentColor
    case .pausedForCapture, .needsAccessibility: .orange
    case .unavailable: .red
    case .scanning: .secondary
    case .expanded, .arranging: .green
    }
  }

  private var primaryButtonTitle: String {
    model.status.isCollapsedIntent
      ? L10n.string("action.expand", language: model.language)
      : L10n.string("action.collapse", language: model.language)
  }
}

private struct StatisticView: View {
  let value: Int
  let label: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value, format: .number)
        .font(.title2.monospacedDigit().weight(.semibold))
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

private struct SetupStep: View {
  let number: Int
  let title: String
  let detail: String
  let completed: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack {
        Circle()
          .fill(completed ? Color.green : Color.secondary.opacity(0.15))
        if completed {
          Image(systemName: "checkmark")
            .font(.caption.bold())
            .foregroundStyle(.white)
        } else {
          Text(number, format: .number)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
        }
      }
      .frame(width: 24, height: 24)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .fontWeight(.medium)
        Text(detail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
