import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveStatusStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardLayout.pageSpacing) {
                DashboardPageHeader(
                    title: "概览",
                    subtitle: "实时掌握 Mihomo Core 的运行状态与网络负载。"
                )

                hero
                metrics
                contentColumns
            }
            .padding(.horizontal, DashboardLayout.pageHorizontalPadding)
            .padding(.vertical, DashboardLayout.pageVerticalPadding)
        }
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.025), Color.clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.28)
            )
        )
    }

    private var contentColumns: some View {
        HStack(alignment: .top, spacing: DashboardLayout.sectionSpacing) {
            trafficPanel
                .frame(maxWidth: .infinity)
                .frame(height: 336)
            quickActions
                .frame(width: 334)
                .frame(height: 336)
        }
    }

    private var hero: some View {
        ZStack(alignment: .trailing) {
            LinearGradient(
                colors: [DashboardPalette.accent.opacity(0.11), Color(red: 0.54, green: 0.34, blue: 0.95).opacity(0.12)],
                startPoint: .leading,
                endPoint: .trailing
            )

            Circle()
                .fill(DashboardPalette.accent.opacity(0.065))
                .frame(width: 260, height: 260)
                .offset(x: 90, y: -100)

            HStack(spacing: 14) {
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.105, green: 0.12, blue: 0.15), Color(red: 0.045, green: 0.052, blue: 0.068)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text("M")
                        .font(.system(size: 22, weight: .bold))
                }
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.26), radius: 16, y: 8)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Mihomo Core")
                        .font(.system(size: 20, weight: .bold))
                    Text(live.status?.versions?.core ?? "--")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardPalette.tertiary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 3) {
                    Text(live.status?.service.active == true ? "RUNNING" : "STOPPED")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(live.status?.service.active == true ? DashboardPalette.green : DashboardPalette.red)
                    Text(serviceSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(DashboardPalette.tertiary)
                }
            }
            .padding(.horizontal, 22)
        }
        .frame(height: 116)
        .background(DashboardPalette.surface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DashboardPalette.separator, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
        .clipped()
    }

    private var metrics: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            DashboardMetricCard(title: "MEMORY", value: bytes(live.status?.memoryBytes), subtitle: uptime)
            DashboardMetricCard(title: "UPLOAD", value: rate(live.status?.speed?.up), subtitle: total(live.status?.totals?.up))
            DashboardMetricCard(title: "DOWNLOAD", value: rate(live.status?.speed?.down), subtitle: total(live.status?.totals?.down))
            DashboardMetricCard(title: "CONNECTIONS", value: String(live.status?.connections ?? 0), subtitle: "Active sessions")
        }
    }

    private var trafficPanel: some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: DashboardLayout.panelSpacing) {
                DashboardPanelHeader(title: "实时流量", trailing: "每 \(refreshText) 秒刷新")

                TrafficChartView(samples: live.trafficSamples)
                    .frame(height: 230)

                HStack(spacing: 18) {
                    legendDot(DashboardPalette.accent, "Upload")
                    legendDot(DashboardPalette.green, "Download")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var quickActions: some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: DashboardLayout.panelSpacing) {
                DashboardPanelHeader(title: "快速控制", trailing: "Core only")

                Grid(horizontalSpacing: 9, verticalSpacing: 9) {
                    GridRow {
                        Button("启动") { Task { await model.perform(.start) } }
                            .buttonStyle(DashboardActionButtonStyle())
                            .disabled(live.status?.service.active == true || model.isBusy)
                        Button("停止") { Task { await model.perform(.stop) } }
                            .buttonStyle(DashboardActionButtonStyle(destructive: true))
                            .disabled(live.status?.service.active != true || model.isBusy)
                    }
                    GridRow {
                        Button("重启") { Task { await model.perform(.restart) } }
                            .buttonStyle(DashboardActionButtonStyle())
                            .disabled(model.isBusy)
                        Button("重载配置") { Task { await model.perform(.reload) } }
                            .buttonStyle(DashboardActionButtonStyle())
                            .disabled(model.isBusy)
                    }
                }
                .frame(maxWidth: .infinity)

                Button("应用订阅 + 热重载") { Task { await model.perform(.applySubscriptions) } }
                    .buttonStyle(DashboardActionButtonStyle())
                    .disabled(model.isBusy)

                Button("打开 MetaCubeXD") { model.openMetaCubeXD() }
                    .buttonStyle(DashboardActionButtonStyle())

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text("MetaCubeXD 独立面板：\(model.resolvedMetaCubeXDURL?.absoluteString ?? "未配置")")
                    if let file = live.status?.metacubexd?.settingsFile {
                        Text("配置文件：\(file)")
                    }
                }
                .font(.system(size: 10.5))
                .foregroundStyle(DashboardPalette.tertiary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func legendDot(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(DashboardPalette.tertiary)
        }
    }

    private var serviceSummary: String {
        let manager = live.status?.service.manager ?? "--"
        let sub = live.status?.service.subState ?? "--"
        let enabled = live.status?.service.enabled == true ? "ON" : "OFF"
        return "\(manager) · \(sub) · autostart: \(enabled)"
    }

    private var uptime: String {
        let seconds = Int(live.status?.uptimeSeconds ?? 0)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 { return "Uptime \(days)d \(hours)h" }
        if hours > 0 { return "Uptime \(hours)h \(minutes)m" }
        return "Uptime \(minutes)m"
    }

    private var refreshText: String {
        if model.refreshInterval == model.refreshInterval.rounded() {
            return String(Int(model.refreshInterval))
        }
        return String(format: "%.1f", model.refreshInterval)
    }

    private func rate(_ value: Double?) -> String {
        model.menuRate(value)
    }

    private func bytes(_ value: Int64?) -> String {
        ByteCountFormatter.string(fromByteCount: value ?? 0, countStyle: .memory)
    }

    private func total(_ value: Int64?) -> String {
        "Total " + ByteCountFormatter.string(fromByteCount: value ?? 0, countStyle: .file)
    }
}

private struct TrafficChartView: View {
    let samples: [TrafficSample]

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            guard size.width > 1, size.height > 1 else { return }

            let grid = Path { path in
                for index in 1..<4 {
                    let y = size.height * CGFloat(index) / 4
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
            }
            context.stroke(grid, with: .color(DashboardPalette.separator), lineWidth: 1)

            guard samples.count > 1 else { return }
            let maximum = max(1, samples.reduce(0) { max($0, max($1.upload, $1.download)) })
            draw(\.upload, color: DashboardPalette.accent, maximum: maximum, context: &context, size: size)
            draw(\.download, color: DashboardPalette.green, maximum: maximum, context: &context, size: size)
        }
        .background(DashboardPalette.field.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func draw(
        _ keyPath: KeyPath<TrafficSample, Double>,
        color: Color,
        maximum: Double,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let count = samples.count
        let horizontal = size.width / CGFloat(max(1, count - 1))
        let verticalInset: CGFloat = 7
        let usableHeight = max(1, size.height - verticalInset * 2)
        var path = Path()

        for (index, sample) in samples.enumerated() {
            let value = max(0, sample[keyPath: keyPath])
            let x = CGFloat(index) * horizontal
            let ratio = CGFloat(min(1, value / maximum))
            let y = size.height - verticalInset - ratio * usableHeight
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }
}

private struct DashboardMetricCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.45)
                .foregroundStyle(DashboardPalette.tertiary)
            Text(value)
                .font(.system(size: 23, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(DashboardPalette.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(15)
        .background(DashboardPalette.surface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(DashboardPalette.separator, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.13), radius: 14, y: 7)
    }
}
