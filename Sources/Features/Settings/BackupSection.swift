import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 设置页的「数据」区块：完整备份、CSV 导出、恢复、清空。
struct BackupSection: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrainingSession.startedAt, order: .reverse) private var sessions: [TrainingSession]
    @Query(sort: \BodyMetric.date, order: .forward) private var metrics: [BodyMetric]
    @Query(sort: \Exercise.sortIndex) private var exercises: [Exercise]
    @Query private var profiles: [UserProfile]

    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var showDeleteConfirm = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var autoBackupCount: Int { BackupService.autoBackups().count }

    var body: some View {
        Section("数据") {
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("导出完整备份（JSON）", systemImage: "doc.badge.arrow.up")
                }
            } else {
                Label("正在准备备份…", systemImage: "doc.badge.arrow.up")
                    .foregroundStyle(.secondary)
            }

            ShareLink(item: CSVExport.make(sessions: sessions)) {
                Label("导出训练数据（CSV）", systemImage: "tablecells")
            }

            Button {
                showImporter = true
            } label: {
                Label("从备份恢复", systemImage: "arrow.down.doc")
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("删除所有训练记录", systemImage: "trash")
            }

            Text(L10n.backupNote(kept: autoBackupCount))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task {
            prepareExport()
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("提示", isPresented: $showAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            "删除所有训练记录？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) { deleteAllSessions() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("该操作不可撤销。动作库与设置会保留，建议先导出完整备份。")
        }
    }

    // MARK: - 导出

    private func prepareExport() {
        let file = BackupService.makeFile(
            profile: profiles.first,
            sessions: sessions,
            metrics: metrics
        )
        guard let data = try? BackupService.encode(file),
              let url = try? BackupService.writeExportFile(data: data) else {
            exportURL = nil
            return
        }
        exportURL = url
    }

    // MARK: - 恢复

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)
            let file = try BackupService.decode(data)
            let unknown = BackupService.unknownExerciseIDs(in: file, exercises: exercises)
            let summary = try BackupService.restore(file, into: context, exercises: exercises)

            var message = "已恢复 \(summary.sessions) 次训练、\(summary.metrics) 条体重记录。"
            if summary.skippedSessions > 0 {
                message += "跳过 \(summary.skippedSessions) 次无法识别的训练。"
            }
            if !unknown.isEmpty {
                message += "\n有 \(unknown.count) 个动作不在当前动作库里，相关组已被跳过。"
            }
            alertMessage = message
            showAlert = true
            prepareExport()
        } catch {
            alertMessage = "恢复失败：\(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: - 删除

    private func deleteAllSessions() {
        for session in sessions {
            context.delete(session)
        }
        try? context.save()
        prepareExport()
    }
}
