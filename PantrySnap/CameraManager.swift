//
//  CameraManager.swift
//  PantrySnap
//
//  Created by Sam Koog on 2/22/26.
//

import AVFoundation
import Foundation
import UIKit
import Vision

@Observable
final class CameraManager: NSObject {
    private let sessionQueue = DispatchQueue(label: "com.pantrysnap.capture.session", qos: .userInitiated)
    private(set) var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var captureCompletion: ((CGImage?) -> Void)?

    /// True when the camera feed is available and running.
    private(set) var isAvailable: Bool = false

    /// True when the session has been started (startSession was called).
    private(set) var isRunning: Bool = false

    /// Non-nil when the camera is unavailable (e.g. Simulator, denied, or error).
    private(set) var errorMessage: String?

    override init() {
        captureSession = AVCaptureSession()
        super.init()
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

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            self.photoOutput = output
        }

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

    // MARK: - Photo capture for OCR

    /// Captures a still image and runs Vision text recognition; returns the largest/most prominent text string. Calls completion on main queue.
    func captureAndRecognizeText(completion: @escaping (String?) -> Void) {
        guard let output = photoOutput, let session = captureSession, session.isRunning else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        captureCompletion = { [weak self] cgImage in
            guard let cgImage else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self?.recognizeText(in: cgImage, completion: completion)
        }
        let settings = AVCapturePhotoSettings()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    private func recognizeText(in image: CGImage, completion: @escaping (String?) -> Void) {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let results = request.results as? [VNRecognizedTextObservation], !results.isEmpty else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let string = self?.largestText(from: results) ?? results.first?.topCandidates(1).first?.string
            DispatchQueue.main.async { completion(string) }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    private func largestText(from observations: [VNRecognizedTextObservation]) -> String? {
        let pairs: [(String, CGFloat)] = observations.compactMap { obs in
            guard let candidate = obs.topCandidates(1).first?.string, !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let box = obs.boundingBox
            return (candidate, box.width * box.height)
        }
        return pairs.max(by: { $0.1 < $1.1 }).map(\.0)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let completion = captureCompletion
        captureCompletion = nil
        guard error == nil, let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)?.cgImage else {
            DispatchQueue.main.async { completion?(nil) }
            return
        }
        DispatchQueue.main.async { completion?(image) }
    }
}
