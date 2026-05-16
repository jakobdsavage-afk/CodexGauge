import SwiftUI

struct LeaderboardSettingsView: View {
    @EnvironmentObject private var preferences: UserPreferences
    @Environment(\.dismiss) private var dismiss

    let person: LeaderboardPerson?
    let localCodexBurnedPercent: Double?
    let onSave: (LeaderboardPerson) -> Void

    @State private var displayName: String
    @State private var githubProfile: String
    @State private var usageMode: LeaderboardCodexUsageMode
    @State private var manualBurnedPercent: String

    init(person: LeaderboardPerson?, localCodexBurnedPercent: Double?, onSave: @escaping (LeaderboardPerson) -> Void) {
        self.person = person
        self.localCodexBurnedPercent = localCodexBurnedPercent
        self.onSave = onSave
        _displayName = State(initialValue: person?.displayName ?? "")
        _githubProfile = State(initialValue: person?.githubProfile ?? "")
        _usageMode = State(initialValue: Self.initialUsageMode(for: person))
        _manualBurnedPercent = State(initialValue: person?.manualWeeklyCodexBurnedPercent.map { String(Int($0.rounded())) } ?? "")
    }

    var body: some View {
        let palette = NotebookTheme.palette(for: preferences.theme)

        VStack(alignment: .leading, spacing: 14) {
            Text(person == nil ? "Add Builder" : "Edit Builder")
                .notebookFont(size: 26, weight: .bold, handwritten: preferences.useHandwrittenFont)
                .foregroundStyle(palette.brightInk)

            VStack(alignment: .leading, spacing: 10) {
                labeledField("Display name", text: $displayName, palette: palette)
                labeledField("GitHub username or URL", text: $githubProfile, palette: palette)

                Text("Codex fuel")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.dimInk)

                HStack(spacing: 8) {
                    ForEach(LeaderboardCodexUsageMode.allCases) { mode in
                        Button {
                            usageMode = mode
                        } label: {
                            Text(mode.title)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SketchSegmentButtonStyle(
                            palette: palette,
                            isSelected: usageMode == mode
                        ))
                    }
                }

                if usageMode == .manual {
                    labeledField("Weekly Codex burned %", text: $manualBurnedPercent, palette: palette)

                    if manualBurnedValue == nil && !manualBurnedPercent.isEmpty {
                        Text("Add a number from 0 to 100 so this builder can get a score.")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.dimInk)
                    }
                } else {
                    Text(localCodexBurnedPercent.map { "Automatic: this Mac is at \(Int($0.rounded()))% weekly Codex burned." }
                        ?? "Automatic: this will fill in as soon as Codex usage is available on this Mac.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.ink.opacity(0.72))
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .buttonStyle(SketchPlainTextButtonStyle(palette: palette))
        }
        .padding(22)
        .frame(width: 360)
        .background(palette.paper.opacity(0.98))
    }

    private func labeledField(_ label: String, text: Binding<String>, palette: NotebookPalette) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(palette.dimInk)

            TextField(label, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.brightInk)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(palette.paperGroove.opacity(0.8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(palette.ink.opacity(0.32), lineWidth: 1)
                        }
                }
        }
    }

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !LeaderboardPerson.normalizedGitHubUsername(from: githubProfile).isEmpty
            && (usageMode == .localGauge || manualBurnedValue != nil)
    }

    private func save() {
        let updated = LeaderboardPerson(
            id: person?.id ?? UUID(),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            githubProfile: githubProfile.trimmingCharacters(in: .whitespacesAndNewlines),
            codexUsageMode: usageMode,
            manualWeeklyCodexBurnedPercent: usageMode == .manual ? manualBurnedValue : nil
        )
        onSave(updated)
        dismiss()
    }

    private var manualBurnedValue: Double? {
        guard let value = Double(manualBurnedPercent.trimmingCharacters(in: .whitespacesAndNewlines)),
              (0...100).contains(value)
        else {
            return nil
        }

        return value
    }

    private static func initialUsageMode(for person: LeaderboardPerson?) -> LeaderboardCodexUsageMode {
        guard let person else {
            return .localGauge
        }

        if person.codexUsageMode == .manual && person.manualWeeklyCodexBurnedPercent == nil {
            return .localGauge
        }

        return person.codexUsageMode
    }
}

struct SketchPlainTextButtonStyle: ButtonStyle {
    let palette: NotebookPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(palette.brightInk.opacity(configuration.isPressed ? 0.62 : 0.95))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(palette.ink.opacity(configuration.isPressed ? 0.56 : 0.30), lineWidth: 1)
            }
    }
}

struct SketchSegmentButtonStyle: ButtonStyle {
    let palette: NotebookPalette
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(isSelected ? palette.paperGroove : palette.brightInk.opacity(0.86))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? palette.brightInk.opacity(configuration.isPressed ? 0.70 : 0.92) : palette.paperGroove.opacity(0.86))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(palette.ink.opacity(isSelected ? 0.72 : 0.28), lineWidth: isSelected ? 1.15 : 0.8)
                    }
            }
            .contentShape(Rectangle())
    }
}
