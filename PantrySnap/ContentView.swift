//
//  ContentView.swift
//  PantrySnap
//
//  Created by Sam Koog on 2/22/26.
//

import SwiftUI

// MARK: - Main Screen

struct ContentView: View {
    @State private var selectedTab: TabItem = .pantry
    @State private var cameraManager = CameraManager()
    @State private var showAddSheetFromSnap = false
    @State private var scannedTextForAdd: String?
    @State private var isScanningText = false
    private let pantryViewModel = PantryViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent
            GlassTabBar(selectedTab: $selectedTab, onSnapTap: {
                selectedTab = .plan
                showAddSheetFromSnap = true
            })
        }
        .sheet(isPresented: $showAddSheetFromSnap) {
            AddPantryItemSheet(viewModel: pantryViewModel, initialName: scannedTextForAdd) {
                scannedTextForAdd = nil
                showAddSheetFromSnap = false
            }
        }
        .onAppear {
            cameraManager.configureSession()
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if selectedTab == .pantry {
            PantryListView(viewModel: pantryViewModel)
        } else {
            cameraView
        }
    }

    @ViewBuilder
    private var cameraView: some View {
        if cameraManager.isAvailable, let session = cameraManager.captureSession {
            ZStack {
                CameraPreview(session: session)
                    .ignoresSafeArea(edges: .top)
                    .accessibilityLabel("Live camera feed")
                cameraOverlay
            }
        } else {
            cameraUnavailableView
        }
    }

    private var cameraOverlay: some View {
        ZStack {
            // Reticle: centered rounded rect showing scan area
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: 260, height: 80)
                .accessibilityHidden(true)
            VStack {
                Spacer()
                Button {
                    scanTextAndOpenAddSheet()
                } label: {
                    Label("Scan Text", systemImage: "text.viewfinder")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isScanningText)
                .padding(.bottom, 100)
                .accessibilityLabel("Scan text")
                .accessibilityHint("Captures text from the camera to pre-fill the item name")
            }
        }
        .allowsHitTesting(true)
    }

    private func scanTextAndOpenAddSheet() {
        isScanningText = true
        cameraManager.captureAndRecognizeText { text in
            isScanningText = false
            scannedTextForAdd = text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? text : nil
            showAddSheetFromSnap = true
        }
    }

    private var cameraUnavailableView: some View {
        ZStack {
            Rectangle()
                .fill(Color(white: 0.22))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("Camera Unavailable")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Camera unavailable")
        .accessibilityHint(cameraManager.errorMessage ?? "Camera is not available on this device.")
    }
}

// MARK: - Plan Icon (shared for tab bar and app icon)

/// Reusable basket + dollar icon. Template and text are applied to the inner views only, not the ZStack.
struct PlanIconContent: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            basketImage
            Text("$")
                .font(.system(size: size * 0.45, weight: .semibold))
        }
        .frame(width: size, height: size)
    }

    /// Basket asset; use "Template Image" in Assets.xcassets so it tints with foregroundStyle.
    private var basketImage: some View {
        Image("BasketIcon")
            .resizable()
            .scaledToFit()
    }
}

// MARK: - Tab Item

enum TabItem: String, CaseIterable {
    case plan = "Plan"
    case pantry = "Pantry"
    case cook = "Cook"
    case social = "Social"

    /// SF Symbol name for tabs that use system images.
    var systemIconName: String? {
        switch self {
        case .plan: return nil
        case .pantry: return "cabinet.fill"
        case .cook: return "flame.fill"
        case .social: return "person.2.fill"
        }
    }

    /// Custom asset name in Assets.xcassets for tabs that use a bundled image.
    var customAssetName: String? {
        switch self {
        case .plan: return "BasketIcon"
        default: return nil
        }
    }
}

// MARK: - Glass Tab Bar

struct GlassTabBar: View {
    @Binding var selectedTab: TabItem
    var onSnapTap: () -> Void = {}

    private let tabBarHeight: CGFloat = 72
    private let snapButtonSize: CGFloat = 60
    private let snapButtonOverlap: CGFloat = 18

    var body: some View {
        ZStack(alignment: .bottom) {
            // Glassmorphic bar background
            tabBarBackground

            // Four tab items with gap in center for Snap button
            HStack(spacing: 0) {
                ForEach([TabItem.plan, .pantry], id: \.self) { tab in
                    tabButton(for: tab)
                }

                // Invisible spacer for Snap button (keeps layout balanced)
                Color.clear
                    .frame(width: snapButtonSize, height: tabBarHeight)

                ForEach([TabItem.cook, .social], id: \.self) { tab in
                    tabButton(for: tab)
                }
            }
            .frame(height: tabBarHeight)

            // Center Snap (Camera) button overlapping the bar
            snapButton
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 24)
    }

    private var tabBarBackground: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
            )
            .frame(height: tabBarHeight)
            .shadow(color: .black.opacity(0.15), radius: 20, y: 4)
    }

    private func tabButton(for tab: TabItem) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                tabIcon(for: tab)
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tab.rawValue) tab")
        .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
    }

    @ViewBuilder
    private func tabIcon(for tab: TabItem) -> some View {
        let size: CGFloat = 24

        if let assetName = tab.customAssetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else if let systemName = tab.systemIconName {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .medium))
                .frame(width: size, height: size)
        }
    }

    private var snapButton: some View {
        Button {
            onSnapTap()
        } label: {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.95), .white.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                )
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.black.opacity(0.75))
                )
                .frame(width: snapButtonSize, height: snapButtonSize)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .offset(y: -snapButtonOverlap)
        .accessibilityLabel("Snap photo")
        .accessibilityHint("Opens form to add a pantry item")
    }
}

// MARK: - App Icon View

/// Same basket + dollar ZStack as the Plan tab, centered on a square Color.gray background.
struct AppIconView: View {
    private let iconSize: CGFloat = 280

    var body: some View {
        Color.gray
            .overlay {
                PlanIconContent(size: iconSize)
                    .foregroundStyle(.primary)
            }
            .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

#Preview("App Icon") {
    AppIconView()
        .frame(width: 512, height: 512)
}
