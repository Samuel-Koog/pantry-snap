//
//  AddPantryItemSheet.swift
//  PantrySnap
//
//  Created by Sam Koog on 2/22/26.
//

import SwiftUI

struct AddPantryItemSheet: View {
    let viewModel: PantryViewModel
    var initialName: String? = nil
    var onDismiss: () -> Void

    @State private var name = ""
    @State private var quantity = 1
    @State private var unit = "units"
    @State private var expiryDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var isSubmitting = false

    private let unitOptions = ["units", "pcs", "g", "kg", "lbs", "ml", "L", "oz", "lb", "box", "bag"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Item name")
                    Stepper(value: $quantity, in: 1 ... 999) {
                        Text("Quantity: \(quantity)")
                            .accessibilityLabel("Quantity \(quantity)")
                    }
                    Picker("Unit", selection: $unit) {
                        ForEach(unitOptions, id: \.self) { u in
                            Text(u).tag(u)
                        }
                    }
                    .accessibilityLabel("Unit")
                    .accessibilityHint("e.g. units, kg, lbs")
                }
                Section("Expiry") {
                    DatePicker("Expiry date", selection: $expiryDate, displayedComponents: .date)
                        .accessibilityLabel("Expiry date")
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        submit()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .onAppear {
                if let n = initialName, !n.isEmpty {
                    name = n
                }
            }
            .overlay {
                if isSubmitting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                }
            }
            .alert("Save Failed", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearErrorMessage() } }
            )) {
                Button("OK") {
                    viewModel.clearErrorMessage()
                }
            } message: {
                Text(addItemErrorMessage)
            }
        }
    }

    private var addItemErrorMessage: String {
        let hint = "Check if your laptop server is running at \(APIConfig.baseURL)"
        if let msg = viewModel.errorMessage, !msg.isEmpty {
            return "\(msg)\n\n\(hint)"
        }
        return hint
    }

    private func submit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isSubmitting = true
        Task {
            await viewModel.addItem(name: trimmedName, quantity: quantity, unit: unit, expiryDate: expiryDate)
            await MainActor.run {
                isSubmitting = false
                if viewModel.errorMessage == nil {
                    onDismiss()
                }
            }
        }
    }
}

#Preview {
    AddPantryItemSheet(viewModel: PantryViewModel(), initialName: nil) {}
}
