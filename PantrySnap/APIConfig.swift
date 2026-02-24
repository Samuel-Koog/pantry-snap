//
//  APIConfig.swift
//  PantrySnap
//
//  Created by Sam Koog on 2/22/26.
//

import Foundation

/// Base URL for the local FastAPI pantry backend.
/// - **iOS Simulator:** keep `127.0.0.1` (backend runs on same Mac).
/// - **Physical iPhone:** replace `127.0.0.1` with your Mac's IP (e.g. `192.168.1.5`).
///   Find Mac IP: System Settings → Network → Wi‑Fi → Details, or Terminal: `ipconfig getifaddr en0`
struct APIConfig {
    static let baseURL = "http://192.168.5.23:8000/pantry/"
}

