import PhotosUI
import SwiftUI

struct FormCheckView: View {
    @StateObject private var service = FormCheckService()
    @State private var pickerItem: PhotosPickerItem?
    @State private var isPreparing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                intro
                pickerCard
                resultCard
                limitCard
            }
            .padding(Theme.pad)
        }
        .background(Theme.bg)
        .navigationTitle("动作评估")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            Task { await handlePicked(newValue) }
        }
    }

    // MARK: - 说明

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("拍一段侧向深蹲，看看深度和节奏")
                .font(.title3.weight(.semibold))
            Text("视频只在这台设备上分析，抽帧跑 Vision 人体关键点，不上传、不保存。")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 选择视频

    private var pickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("拍摄建议")
                .font(.subheadline.weight(.semibold))
            bullet("手机横放或竖放在侧面，全身入镜")
            bullet("光线均匀，背景尽量别有人走动")
            bullet("连续做 3–5 次，节奏稳定")

            PhotosPicker(selection: $pickerItem, matching: .videos) {
                Label(isPreparing ? "准备中…" : "选择视频", systemImage: "video.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.ink)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isPreparing)
        }
        .card()
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: - 结果

    @ViewBuilder
    private var resultCard: some View {
        switch service.state {
        case .idle:
            EmptyView()

        case .analyzing(let progress):
            VStack(alignment: .leading, spacing: 10) {
                Text("正在分析…")
                    .font(.subheadline.weight(.semibold))
                ProgressView(value: progress)
                    .tint(Theme.accent)
                Text(L10n.progressPercent(Int(progress * 100)))
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
            }
            .card()

        case .finished(let result):
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "分析结果", subtitle: "共处理 \(result.frameCount) 帧")

                HStack(spacing: 8) {
                    StatTile(title: "识别次数", value: "\(result.reps)")
                    StatTile(
                        title: "最低膝角",
                        value: result.frameCount == 0 ? "—" : "\(Int(result.minKneeAngle.rounded()))°"
                    )
                    StatTile(
                        title: "平均节奏",
                        value: result.averageTempo == 0 ? "—" : String(format: "%.1f", result.averageTempo),
                        unit: "秒"
                    )
                }

                ForEach(Array(result.notes.enumerated()), id: \.offset) { pair in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 2)
                        Text(pair.element)
                            .font(.caption)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .card()

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text("没能完成分析")
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            .card()
        }
    }

    private var limitCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("能做什么、不能做什么")
                .font(.subheadline.weight(.semibold))
            Text("只评估膝角（深度）、躯干前倾和节奏三件事。它不判断动作对错，也不替代教练或医生——落地姿势、足弓、骨盆位置都超出这台手机能看准的范围。")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    // MARK: - 处理视频

    private func handlePicked(_ item: PhotosPickerItem) async {
        isPreparing = true
        defer { isPreparing = false }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("formcheck-\(UUID().uuidString).mov")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
        await service.analyze(videoURL: url)
        try? FileManager.default.removeItem(at: url)
    }
}

#Preview {
    NavigationStack {
        FormCheckView()
    }
}
