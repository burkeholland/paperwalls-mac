import Foundation
import PaperwallsCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    private let presets: [(String, TimeInterval)] = [
        ("15 minutes", 900),
        ("Hourly", 3_600),
        ("Daily", 86_400),
        ("Weekly", 604_800)
    ]

    var body: some View {
        Form {
            Section("Rotation") {
                Toggle("Enable automatic rotation", isOn: Binding(
                    get: { model.rotationConfiguration.isEnabled },
                    set: {
                        model.rotationConfiguration.isEnabled = $0
                        model.saveRotationConfiguration()
                    }
                ))

                Picker("Scope", selection: Binding(
                    get: { scopeSelection },
                    set: { newValue in
                        model.rotationConfiguration.scope = scope(from: newValue)
                        model.saveRotationConfiguration()
                    }
                )) {
                    Text("All wallpapers").tag("all")
                    ForEach(model.themes) { theme in
                        Text(theme.label).tag("theme:\(theme.key)")
                    }
                }

                Picker("Preset", selection: Binding(
                    get: { model.rotationConfiguration.intervalSeconds },
                    set: {
                        model.rotationConfiguration.intervalSeconds = $0
                        model.saveRotationConfiguration()
                    }
                )) {
                    ForEach(presets, id: \.1) { label, seconds in
                        Text(label).tag(seconds)
                    }
                }

                HStack {
                    Text("Custom interval")
                    TextField("Seconds", value: Binding(
                        get: { model.rotationConfiguration.intervalSeconds },
                        set: {
                            model.rotationConfiguration.intervalSeconds = $0
                            model.saveRotationConfiguration()
                        }
                    ), format: .number)
                    .frame(width: 120)
                    Text("seconds")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Cache") {
                LabeledContent("Downloaded wallpapers", value: ByteCountFormatter.string(fromByteCount: Int64(model.cacheSizeBytes), countStyle: .file))

                Button("Clear Wallpaper Cache") {
                    Task { await model.clearCache() }
                }
            }

            Section("Catalog") {
                Button("Refresh Now") {
                    Task { await model.refreshCatalog() }
                }

                if let status = model.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private var scopeSelection: String {
        switch model.rotationConfiguration.scope {
        case .all:
            return "all"
        case .theme(let key):
            return "theme:\(key)"
        }
    }

    private func scope(from selection: String) -> RotationScope {
        if selection.hasPrefix("theme:") {
            return .theme(String(selection.dropFirst("theme:".count)))
        }

        return .all
    }
}

