import SwiftUI

struct LibraryView: View {
    let library: ExpressionLibrary
    let studio: Studio
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: Expression?
    @State private var deleting: Expression?
    @State private var newName = ""
    @State private var error: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14), count: typeSize.isAccessibilitySize ? 2 : 3)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(library.families.filter { $0 != .mine }, id: \.self) { family in
                        Text(family.label).font(.headline).padding(.top, family == .happy ? 0 : 14)
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(library.expressions(in: family)) { expression in
                                cell(expression)
                            }
                        }
                    }
                    Text("My expressions").font(.headline).padding(.top, 14)
                    if library.custom.isEmpty {
                        Text("Tap + on the main screen to shape a face and save it here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(library.custom) { expression in
                                cell(expression).contextMenu {
                                    Button("Rename", systemImage: "pencil") {
                                        newName = expression.name
                                        renaming = expression
                                    }
                                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = expression }
                                }
                            }
                        }
                        Text("Touch and hold one of yours to rename or delete it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .background(.white)
            .navigationTitle("Expressions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(.ink)
        .alert("Rename expression", isPresented: .init(get: { renaming != nil }, set: { if !$0 { renaming = nil } }), presenting: renaming) { expression in
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    attempt {
                        try library.rename(expression, to: name)
                        studio.renamed(expression, to: name)
                    }
                }
            }
        }
        .confirmationDialog("Delete \(deleting?.name ?? "")?", isPresented: .init(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible, presenting: deleting) { expression in
            Button("Delete", role: .destructive) {
                attempt {
                    try library.delete(expression)
                    if studio.selected?.id == expression.id { studio.select(nil) }
                }
            }
        }
        .alert("That didn't save", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") {}
        } message: { Text(error ?? "") }
    }

    private func cell(_ expression: Expression) -> some View {
        Button {
            studio.select(expression)
            dismiss()
        } label: {
            VStack(spacing: 2) {
                ExpressionThumbnail(library: library, expression: expression, isColor: studio.isColor,
                                    isSelected: studio.selected?.id == expression.id)
                if !library.isCustom(expression) {
                    Text(expression.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func attempt(_ work: () throws -> Void) {
        do { try work() } catch { self.error = error.localizedDescription }
    }
}
