//
//  PantryListView.swift
//  PantrySnap
//
//  Created by Sam Koog on 2/22/26.
//

import SwiftUI

struct PantryListView: View {
    let viewModel: PantryViewModel
    @State private var showAddSheet = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            NavigationStack {
                VStack(spacing: 0) {
                    ZStack {
                        List {
                            ForEach(viewModel.items) { item in
                                PantryRowView(item: item)
                            }
                        }
                        .listStyle(.insetGrouped)
                        .overlay {
                            if viewModel.isLoading && viewModel.items.isEmpty {
                                ProgressView()
                                    .scaleEffect(1.2)
                            }
                        }
                        .overlay {
                            if !viewModel.isLoading && viewModel.items.isEmpty {
                                emptyStateView
                            }
                        }
                        if viewModel.isLoading && !viewModel.items.isEmpty {
                            VStack {
                                ProgressView()
                                    .scaleEffect(1.0)
                                    .padding(.top, 8)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Pantry")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add") {
                            showAddSheet = true
                        }
                        .accessibilityLabel("Add pantry item")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddPantryItemSheet(viewModel: viewModel) {
                    showAddSheet = false
                }
            }
            .task {
                await viewModel.fetchItems()
            }
            .alert("Connection Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearErrorMessage() } }
            )) {
                Button("OK") {
                    viewModel.clearErrorMessage()
                }
            } message: {
                Text(connectionErrorMessage)
            }
        }
    }

    private var connectionErrorMessage: String {
        let hint = "Check if your laptop server is running at \(APIConfig.baseURL)"
        if let msg = viewModel.errorMessage, !msg.isEmpty {
            return "\(msg)\n\n\(hint)"
        }
        return hint
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Your pantry is empty", systemImage: "cabinet")
        } description: {
            Text("Tap 'Snap' to add your first item!")
        }
        .padding()
    }
}

struct PantryRowView: View {
    let item: PantryItem

    private var displayName: String {
        item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unnamed item" : item.name
    }

    private var showPlaceholderIcon: Bool {
        item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            if showPlaceholderIcon {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text("\(item.quantity) \(item.unit)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("Expires \(item.expiry_date)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel("\(displayName), quantity \(item.quantity) \(item.unit), expires \(item.expiry_date)")
    }
}

#Preview {
    PantryListView(viewModel: PantryViewModel())
}
