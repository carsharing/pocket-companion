import PetCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: CompanionModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var confirmingReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                        .submitLabel(.done)
                        .onSubmit { model.rename(to: name) }
                }

                Section {
                    Toggle("Gentle reminders", isOn: Binding(
                        get: { model.notificationsEnabled },
                        set: { enabled in
                            model.notificationsEnabled = enabled
                            if enabled { Task { _ = await ReminderScheduler.requestPermission() } }
                        }
                    ))
                } footer: {
                    Text("A nudge when \(model.state.name) gets hungry, lonely or grubby, or is about to grow. Never at night.")
                }

                Section("Widget") {
                    Label(
                        model.isWidgetSyncAvailable ? "Widget sync is working" : "Widget sync unavailable",
                        systemImage: model.isWidgetSyncAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(model.isWidgetSyncAvailable ? .green : .orange)
                    if !model.isWidgetSyncAvailable {
                        Text("The app couldn't open its shared App Group, so the widget keeps its own separate companion. Re-install with a signing tool that keeps App Groups (see the README).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text("Long-press your home screen, tap +, and search for Companion. The medium size has care buttons.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    ForEach(AdultForm.allCases, id: \.self) { form in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(form.displayName).font(.headline)
                            Text(form.blurb).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Who will they become?")
                } footer: {
                    Text("After 3 days your young fox grows into one of these, depending on how you cared for them.")
                }

                Section {
                    Button("Start over with a new kit", role: .destructive) { confirmingReset = true }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        model.rename(to: name)
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Say goodbye to \(model.state.name) and welcome a new kit?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Start over", role: .destructive) {
                    model.startOver()
                    dismiss()
                }
            }
            .onAppear { name = model.state.name }
        }
    }
}
