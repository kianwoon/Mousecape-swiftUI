//
//  MainView.swift
//  Mousecape
//
//  Main view with page-based navigation (Home / Settings)
//  Uses toolbar buttons for page switching
//

import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    var body: some View {
        ZStack {
            if appState.isWindowVisible {
                switch appState.currentPage {
                case .home:
                    HomeView()
                case .settings:
                    SettingsView()
                }

                // Loading overlay
                if appState.isLoading {
                    LoadingOverlayView(message: appState.loadingMessage)
                }
            } else {
                // Empty view when window is hidden - releases all child views and their caches
                Color.clear
            }

            // Non-intrusive toast overlay
            ToastNotificationView()
        }
        .alert(
            appState.importResultIsSuccess ? String(localized: "Import Complete") : String(localized: "Import Failed"),
            isPresented: Binding(
                get: { appState.showImportResult },
                set: { appState.showImportResult = $0 }
            )
        ) {
            Button("OK") {
                appState.showImportResult = false
            }
        } message: {
            Text(appState.importResultMessage)
        }
        .alert(
            appState.operationResultIsSuccess ? String(localized: "Success") : String(localized: "Error"),
            isPresented: Binding(
                get: { appState.showOperationResult },
                set: { appState.showOperationResult = $0 }
            )
        ) {
            Button("OK") {
                appState.showOperationResult = false
            }
        } message: {
            Text(appState.operationResultMessage)
        }
        .alert(
            String(localized: "Cannot Apply Cursor"),
            isPresented: Binding(
                get: { appState.showPointerColorWarning },
                set: { appState.showPointerColorWarning = $0 }
            )
        ) {
            Button(String(localized: "Open Settings")) {
                openAccessibilityPointerSettings()
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(String(localized: "Mousecape cannot apply custom cursors because your system pointer color has been changed. Please go to System Settings > Accessibility > Display > Pointer and tap \"Reset Color\", then try again."))
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlayView: View {
    let message: String

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Loading card
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle())

                Text(message)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(radius: 20)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environment(AppState.shared)
}
