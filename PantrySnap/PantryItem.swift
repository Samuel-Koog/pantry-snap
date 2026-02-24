//
//  PantryItem.swift
//  PantrySnap
//
//  Created by Sam Koog on 2/22/26.
//

import Foundation

/// Pantry item model matching the FastAPI backend JSON.
struct PantryItem: Identifiable, Codable {
    let id: Int
    let name: String
    let quantity: Int
    let unit: String
    /// Backend sends expiry_dates (array). Decode from expiry_dates or legacy expiry_date.
    private let expiry_dates: [String]?
    private let expiry_date: String?

    /// All expiry dates for this item (multiple when consolidated). Sorted.
    var expiryDates: [String] {
        if let d = expiry_dates, !d.isEmpty { return d.sorted() }
        if let d = expiry_date, !d.isEmpty { return [d] }
        return []
    }

    /// Earliest expiry date for sorting and urgency.
    var earliestExpiry: String? { expiryDates.first }

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit
        case expiry_dates
        case expiry_date
    }

    init(id: Int, name: String, quantity: Int, unit: String, expiry_dates: [String]? = nil, expiry_date: String? = nil) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.expiry_dates = expiry_dates
        self.expiry_date = expiry_date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        quantity = try c.decode(Int.self, forKey: .quantity)
        unit = try c.decode(String.self, forKey: .unit)
        expiry_dates = try c.decodeIfPresent([String].self, forKey: .expiry_dates)
        expiry_date = try c.decodeIfPresent(String.self, forKey: .expiry_date)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(quantity, forKey: .quantity)
        try c.encode(unit, forKey: .unit)
        try c.encode(expiryDates, forKey: .expiry_dates)
    }

    /// Payload for POST /pantry/ (id is assigned by server; duplicates merge by name).
    struct PostPayload: Encodable {
        let name: String
        let quantity: Int
        let unit: String
        let expiry_date: String
    }

    /// Payload for PUT /pantry/:id/
    struct UpdatePayload: Encodable {
        let name: String
        let quantity: Int
        let unit: String
        let expiry_dates: [String]
    }
}
