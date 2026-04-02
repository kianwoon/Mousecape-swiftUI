//
//  ToastNotificationView.swift
//  Mousecape
//
//  Non-intrusive auto-dismissing toast banner for success/error feedback.
//

import SwiftUI

struct ToastNotificationView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack {
            if appState.showToast {
                HStack(spacing: 10) {
                    Image(systemName: appState.toastIsSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(appState.toastIsSuccess ? .green : .red)
                        .font(.system(size: 14, weight: .semibold))

                    Text(appState.toastMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(appState.toastIsSuccess ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation(.easeOut(duration: 0.3)) {
                        appState.showToast = false
                    }
                }
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.25), value: appState.showToast)
    }
}
