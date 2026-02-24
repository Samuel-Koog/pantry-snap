//
//  EditPantryItemSheet.swift
//  PantrySnap
//
//  Created by Sam Koog on 2/22/26.
//

import SwiftUI

struct EditPantryItemSheet: View {
    let item: PantryItem
    let viewModel: PantryViewModel
    var onDismiss: () -> Void

    @State private var name: String = ""
    @State private var quantity: Int = 1
    @State private var unit: String = "units"
    @State private var expiryDates: [String] = []
    @State private var isSubmitting = false
    @State private var showAddExpiry = false
    @State private var newExpiryDate = Date()

    private let unitOptions = ["units", "pcs", "g", "kg", "lbs", "ml", "L", "oz", "lb", "box", "bag"]
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    Stepper(value: $quantity, in: 1 ... 999) {
                        Text("Quantity: \(quantity)")
                    }
                    Picker("Unit", selection: $unit) {
                        ForEach(unitOptions, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Expiry dates") {
                    ForEach(expiryDates, id: \.self) { dateStr in
                        HStack {
                            Text(dateStr)
                            Spacer()
                            Button(role: .destructive) {
                                expiryDates.removeAll { $0 == dateStr }
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                    Button {
                        newExpiryDate = Date()
                        showAddExpiry = true
                    } label: {
                        Label("Add expiry date", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { submit() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || expiryDates.isEmpty || isSubmitting)
                }
            }
            .onAppear {
                name = item.name
                quantity = item.quantity
                unit = item.unit
                expiryDates = item.expiryDates
            }
            .interactiveDismissDisabled(isSubmitting)
            .overlay {
                if isSubmitting {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView().scaleEffect(1.2).tint(.white)
                }
            }
            .alert("Save Failed", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearErrorMessage() } }
            )) {
                Button("OK") { viewModel.clearErrorMessage() }
            } message: {
                Text("\(viewModel.errorMessage ?? "")\n\nCheck if your laptop server is running at \(APIConfig.baseURL)")
            }
            .sheet(isPresented: $showAddExpiry) {
                addExpirySheet
            }
        }
    }

    private var addExpirySheet: some View {
        NavigationStack {
            DatePicker("Expiry date", selection: $newExpiryDate, displayedComponents: .date)
                .padding()
            .navigationTitle("Add expiry date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddExpiry = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let str = Self.dateFormatter.string(from: newExpiryDate)
                        if !expiryDates.contains(str) {
                            expiryDates.append(str)
                            expiryDates.sort()
                        }
                        showAddExpiry = false
                    }
                }
            }
        }
    }

    private func submit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !expiryDates.isEmpty else { return }
        isSubmitting = true
        Task {
            await viewModel.updateItem(id: item.id, name: trimmedName, quantity: quantity, unit: unit, expiryDates: expiryDates)
            await MainActor.run {
                isSubmitting = false
                if viewModel.errorMessage == nil { onDismiss() }
            }
        }
    }
}
