import SwiftUI

/// Sliders for every facial parameter. Saving adds the face to the library.
struct EditorView: View {
    let studio: Studio
    let library: ExpressionLibrary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var labelWidth = 128.0
    @State private var group = FaceParameter.Group.mouth
    @State private var naming = false
    @State private var isSaving = false
    @State private var name = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Part of the face", selection: $group) {
                    ForEach(FaceParameter.Group.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(group.parameters, id: \.self) { parameter in row(parameter) }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New expression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        studio.cancelEditing()
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        name = ""
                        naming = true
                    }
                    .disabled(isSaving)
                }
            }
        }
        .tint(.ink)
        .interactiveDismissDisabled()
        .alert("Name this expression", isPresented: $naming) {
            TextField("Name", text: $name)
            Button("Cancel", role: .cancel) {}
            Button("Save") { Task { await save() } }
        }
        .alert("That didn't save", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") {}
        } message: { Text(error ?? "") }
    }

    private func row(_ parameter: FaceParameter) -> some View {
        // At the largest sizes the label gets its own line.
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 14))
        return layout {
            Text(parameter.label)
                .font(.subheadline)
                .frame(width: typeSize.isAccessibilitySize ? nil : labelWidth, alignment: .leading)
            Slider(value: .init(get: { studio.parameters[parameter] }, set: { studio.set(parameter, to: $0) }), in: parameter.range)
                .accessibilityLabel(parameter.label)
        }
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parameters = studio.parameters
        let thumbnails = await studio.rig.thumbnails(of: parameters)
        do {
            let saved = try library.save(name: trimmed.isEmpty ? "Untitled" : trimmed, parameters: parameters, thumbnails: thumbnails)
            studio.select(saved)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
