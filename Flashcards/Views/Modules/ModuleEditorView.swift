import SwiftData
import SwiftUI

/// Creates a new module, or edits an existing one.
struct ModuleEditorView: View {
    let module: StudyModule?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var details: String
    @State private var color: ModuleColor

    init(module: StudyModule?) {
        self.module = module
        _name = State(initialValue: module?.name ?? "")
        _details = State(initialValue: module?.details ?? "")
        _color = State(initialValue: module?.moduleColor ?? .blue)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Biology)", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Description (optional)", text: $details, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section("Colour") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 12) {
                        ForEach(ModuleColor.allCases) { option in
                            Button {
                                color = option
                            } label: {
                                Circle()
                                    .fill(option.color.gradient)
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if option == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.rawValue.capitalized)
                            .accessibilityAddTraits(option == color ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(module == nil ? "New Module" : "Edit Module")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(module == nil ? "Create" : "Save") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if let module {
            module.name = trimmedName
            module.details = trimmedDetails
            module.moduleColor = color
        } else {
            modelContext.insert(StudyModule(name: trimmedName, details: trimmedDetails, colorName: color.rawValue))
        }
        CardStore.save(modelContext)
        dismiss()
    }
}
