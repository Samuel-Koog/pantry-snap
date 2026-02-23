//
//  APIConfig.swift
//  PantrySnap
//
//  Created by Sam Koog on 2/22/26.
//

import Foundation

/// Base URL for the local FastAPI pantry backend.
/// - **iOS Simulator (same Mac as backend):** keep `127.0.0.1` or use `localhost`.
/// - **Physical iPhone:** replace `127.0.0.1` with your Mac's IP (e.g. `192.168.1.5`). Find it: System Settings → Network → Wi‑Fi → Details.
struct APIConfig {
    static let baseURL = "http://127.0.0.1:8000/pantry/"
}
