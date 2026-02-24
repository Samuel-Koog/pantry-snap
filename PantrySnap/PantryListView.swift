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
    @State private var searchText = ""
    @State private var itemToEdit: PantryItem?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            NavigationStack {
                ZStack {
                    List {
                        Section {
                            searchBarRow
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                        .listRowSeparator(.hidden)

                        Section {
                            if viewModel.isLoading && viewModel.items.isEmpty {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 32)
                                    .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                                    .listRowSeparator(.hidden)
                            } else if !viewModel.isLoading && viewModel.items.isEmpty {
                                emptyStateView(searchQuery: searchText)
                                    .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
                                    .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                                    .listRowSeparator(.hidden)
                            } else {
                                ForEach(viewModel.items) { item in
                                    PantryRowView(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            itemToEdit = item
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    if viewModel.isLoading && !viewModel.items.isEmpty {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.0)
                                .padding(.top, 8)
                            Spacer()
                        }
                    }
                }
                .navigationTitle("Pantry")
                .onChange(of: searchText) { _, newValue in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(for: .seconds(0.3))
                        guard !Task.isCancelled else { return }
                        await viewModel.fetchItems(query: newValue.isEmpty ? nil : newValue)
                    }
                }
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
                AddPantryItemSheet(viewModel: viewModel, initialName: nil) {
                    showAddSheet = false
                }
            }
            .sheet(item: $itemToEdit) { item in
                EditPantryItemSheet(item: item, viewModel: viewModel) {
                    itemToEdit = nil
                }
            }
            .task {
                await viewModel.fetchItems(query: nil)
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

    private var searchBarRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search pantry", text: $searchText)
                .textFieldStyle(.plain)
                .submitLabel(.search)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Search pantry")
        .accessibilityHint("Filters the list by item name")
    }

    private var connectionErrorMessage: String {
        let hint = "Check if your laptop server is running at \(APIConfig.baseURL)"
        if let msg = viewModel.errorMessage, !msg.isEmpty {
            return "\(msg)\n\n\(hint)"
        }
        return hint
    }

    @ViewBuilder
    private func emptyStateView(searchQuery: String) -> some View {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            ContentUnavailableView {
                Label("Your pantry is empty", systemImage: "cabinet")
            } description: {
                Text("Tap 'Snap' to add your first item!")
            }
            .padding()
        } else {
            ContentUnavailableView {
                Label("No results found for \"\(query)\"", systemImage: "magnifyingglass")
            } description: {
                Text("Try a different search term.")
            }
            .padding()
        }
    }
}

struct PantryRowView: View {
    let item: PantryItem

    private static let expiryDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    private var displayName: String {
        item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unnamed item" : item.name
    }

    private var showPlaceholderIcon: Bool {
        item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Days from today until earliest expiry. Negative = already expired.
    private var daysUntilExpiry: Int? {
        guard let earliest = item.earliestExpiry,
              let expiry = Self.expiryDateFormatter.date(from: earliest) else { return nil }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExpiry = calendar.startOfDay(for: expiry)
        return calendar.dateComponents([.day], from: startOfToday, to: startOfExpiry).day
    }

    /// Red: expired or within 48 hours. Orange: within 7 days. Otherwise secondary.
    private var expiryUrgency: ExpiryUrgency {
        guard let days = daysUntilExpiry else { return .normal }
        if days < 0 || days <= 2 { return .urgent }
        if days <= 7 { return .soon }
        return .normal
    }

    private var expiryTextColor: Color {
        switch expiryUrgency {
        case .urgent: return .red
        case .soon: return .orange
        case .normal: return Color(uiColor: .secondaryLabel)
        }
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
                    Text(expirySummary)
                        .font(.subheadline)
                        .foregroundStyle(expiryTextColor)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel("\(displayName), quantity \(item.quantity) \(item.unit), expires \(item.earliestExpiry ?? "unknown"). Tap to edit.")
        .accessibilityHint(expiryUrgency.accessibilityHint)
    }

    private var expirySummary: String {
        let dates = item.expiryDates
        if dates.isEmpty { return "No expiry" }
        if dates.count == 1 { return "Expires \(dates[0])" }
        return "Expires \(dates[0]) (+\(dates.count - 1) more)"
    }
}

private enum ExpiryUrgency {
    case urgent  // expired or within 48 hours
    case soon    // within 7 days
    case normal

    var accessibilityHint: String {
        switch self {
        case .urgent: return "Expired or expiring very soon"
        case .soon: return "Expiring within a week"
        case .normal: return ""
        }
    }
}

#Preview {
    PantryListView(viewModel: PantryViewModel())
}
