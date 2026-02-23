//
//  PantryViewModel.swift
//  PantrySnap
//
//  Created by Sam Koog on 2/22/26.
//

import Foundation

@Observable
final class PantryViewModel {
    private(set) var items: [PantryItem] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// DateFormatter for expiry_date: "yyyy-MM-dd" to match Python date.fromisoformat().
    private static let expiryDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    /// Fetches all pantry items from GET /pantry/.
    func fetchItems() async {
        await MainActor.run { isLoading = true; errorMessage = nil }

        guard let url = URL(string: APIConfig.baseURL) else {
            await MainActor.run { errorMessage = "Invalid base URL"; isLoading = false }
            return
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                await MainActor.run { errorMessage = "Invalid response"; isLoading = false }
                return
            }
            guard (200 ..< 300).contains(http.statusCode) else {
                await MainActor.run { errorMessage = "Server error: \(http.statusCode)"; isLoading = false }
                return
            }
            let decoded = try decoder.decode([PantryItem].self, from: data)
            await MainActor.run { items = decoded; isLoading = false }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
        }
    }

    /// Adds a new item via POST /pantry/. On 201 Created, refreshes the local list.
    /// - Parameter expiryDate: Converted to "yyyy-MM-dd" (YYYY-MM-DD) string for the API.
    func addItem(name: String, quantity: Int, unit: String, expiryDate: Date) async {
        await MainActor.run { errorMessage = nil }

        guard let url = URL(string: APIConfig.baseURL) else {
            await MainActor.run { errorMessage = "Invalid base URL" }
            return
        }

        let expiryDateString = Self.expiryDateFormatter.string(from: expiryDate)
        let payload = PantryItem.PostPayload(
            name: name,
            quantity: quantity,
            unit: unit,
            expiry_date: expiryDateString
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try encoder.encode(payload)
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                await MainActor.run { errorMessage = "Invalid response" }
                return
            }
            if http.statusCode == 201 {
                await fetchItems()
            } else {
                await MainActor.run { errorMessage = "Add failed: \(http.statusCode)" }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    /// Call when the user dismisses an error alert so the message is cleared.
    func clearErrorMessage() {
        Task { @MainActor in
            errorMessage = nil
        }
    }
}
