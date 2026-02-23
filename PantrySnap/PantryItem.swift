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
    let expiry_date: String

    /// Payload for POST /pantry/ (id is assigned by server).
    struct PostPayload: Encodable {
        let name: String
        let quantity: Int
        let unit: String
        let expiry_date: String
    }
}
