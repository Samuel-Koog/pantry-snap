//
//  CameraManager.swift
//  PantrySnap
//
//  Created by Sam Koog on 2/22/26.
//

import AVFoundation
import Foundation

@Observable
final class CameraManager {
    private let sessionQueue = DispatchQueue(label: "com.pantrysnap.capture.session", qos: .userInitiated)
    private(set) var captureSession: AVCaptureSession?

    /// True when the camera feed is available and running.
    private(set) var isAvailable: Bool = false

    /// True when the session has been started (startSession was called).
    private(set) var isRunning: Bool = false

    /// Non-nil when the camera is unavailable (e.g. Simulator, denied, or error).
    private(set) var errorMessage: String?

    init() {
        captureSession = AVCaptureSession()
    }

    // MARK: - Authorization

    /// Current authorization status for camera access.
    static func authorizationStatus(for mediaType: AVMediaType = .video) -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: mediaType)
    }

    /// Request camera access. Calls completion on an arbitrary queue with granted (true/false).
    static func requestAccess(for mediaType: AVMediaType = .video, completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: mediaType, completionHandler: completion)
    }

    /// Ensures we have authorization, then configures the session on a background thread.
    func configureSession() {
        sessionQueue.async { [weak self] in
            self?.configureSessionOnQueue()
        }
    }

    private func configureSessionOnQueue() {
        guard let session = captureSession else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
            setUnavailableOnMain("Camera Unavailable")
            return
        }

        switch Self.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            Self.requestAccess { [weak self] granted in
                if granted {
                    self?.sessionQueue.async { self?.configureSessionOnQueue() }
                } else {
                    self?.setUnavailableOnMain("Camera access denied")
                }
            }
            return
        case .denied:
            setUnavailableOnMain("Camera access denied")
            return
        case .restricted:
            setUnavailableOnMain("Camera access restricted")
            return
        @unknown default:
            setUnavailableOnMain("Camera Unavailable")
            return
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            setUnavailableOnMain("Camera Unavailable")
            return
        }

        session.addInput(input)
        DispatchQueue.main.async { [weak self] in
            self?.isAvailable = true
            self?.errorMessage = nil
        }
    }

    private func setUnavailableOnMain(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.isAvailable = false
            self?.errorMessage = message
        }
    }

    // MARK: - Lifecycle

    /// Starts the capture session on a background thread. Call when the view appears.
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession?.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    /// Stops the capture session on a background thread. Call when the view disappears.
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession?.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
}
