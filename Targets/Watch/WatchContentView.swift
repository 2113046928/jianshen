import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject private var session: WatchSessionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if session.state.isActive {
                    activeView
                } else {
                    idleView
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var idleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("在 iPhone 上开始训练")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if !session.isReachable {
                Text("手机未连接")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.top, 8)
    }

    private var activeView: some View {
        VStack(spacing: 10) {
            Text(session.state.exerciseName)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(L10n.watchSetProgress(current: session.state.setNumber, total: session.state.totalSets))
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                stepper(
                    value: "\(weightText)kg",
                    minus: { session.adjust(weight: -2.5) },
                    plus: { session.adjust(weight: 2.5) }
                )
                stepper(
                    value: "\(session.state.reps)次",
                    minus: { session.adjust(reps: -1) },
                    plus: { session.adjust(reps: 1) }
                )
            }

            Button {
                session.completeSet()
            } label: {
                Label("完成本组", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            if let hint = session.hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stepper(
        value: String,
        minus: @escaping () -> Void,
        plus: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 2) {
            Button(action: minus) {
                Image(systemName: "minus")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            Text(value)
                .font(.caption2.monospacedDigit())
                .frame(minWidth: 44)
            Button(action: plus) {
                Image(systemName: "plus")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color.gray.opacity(0.2))
        .clipShape(Capsule())
    }

    private var weightText: String {
        let value = session.state.weight
        if value == value.rounded() {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

#Preview {
    WatchContentView()
        .environmentObject(WatchSessionManager())
}
