import SwiftUI

struct WorkspaceRootView: View {
    @Environment(WorkspaceAppModel.self) private var appModel

    var body: some View {
        Group {
            switch appModel.phase {
            case .restoring:
                WorkspaceLaunchView()
            case .signedOut:
                WorkspaceAuthenticationView()
            case .signedIn:
                WorkspaceMainView()
            }
        }
        .tint(WorkspacePalette.primary)
        .animation(.easeInOut(duration: 0.2), value: appModel.phase)
    }
}

private struct WorkspaceLaunchView: View {
    var body: some View {
        ZStack {
            WorkspacePalette.background.ignoresSafeArea()
            VStack(spacing: 18) {
                WorkspaceMark(size: 72)
                ProgressView()
                    .controlSize(.large)
                    .tint(WorkspacePalette.primary)
                    .accessibilityLabel("Загрузка Workspace")
            }
        }
    }
}

struct WorkspaceMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(WorkspacePalette.primary.gradient)
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview("Restoring") {
    WorkspaceRootView()
        .environment(WorkspaceAppModel())
}
