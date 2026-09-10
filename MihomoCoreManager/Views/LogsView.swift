import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: DashboardLayout.pageSpacing) {
            DashboardPageHeader(title: "运行日志", subtitle: "读取 Mihomo Core 最近的服务日志。")
            DashboardPanel {
                VStack(alignment: .leading, spacing: DashboardLayout.panelSpacing) {
                    HStack(spacing: 10) {
                        Text("服务日志").font(.system(size: 14, weight: .bold))
                        Spacer()
                        Picker("日志行数", selection: $model.logLines) {
                            Text("50 行").tag(50); Text("100 行").tag(100); Text("200 行").tag(200); Text("300 行").tag(300)
                        }.labelsHidden().frame(width: 115)
                        Button("刷新日志") { Task { await model.fetchLogs() } }
                            .buttonStyle(DashboardActionButtonStyle()).frame(width: 108)
                    }
                    ScrollView([.horizontal, .vertical]) {
                        Text(model.logs.isEmpty ? "(no logs)" : model.logs)
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(Color(red: 0.82, green: 0.85, blue: 0.90))
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .topLeading).padding(2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DashboardPalette.field.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DashboardPalette.separator, lineWidth: 1) }
                }
            }.frame(maxHeight: .infinity)
        }
        .padding(.horizontal, DashboardLayout.pageHorizontalPadding)
        .padding(.vertical, DashboardLayout.pageVerticalPadding)
        .task(id: loadTaskID) { guard model.selectedSection == .logs else { return }; await model.ensureLogsLoaded() }
        .disabled(model.isBusy)
    }
    private var loadTaskID: String { "\\(model.selectedProfileID?.uuidString ?? \"none\")|\\(model.selectedSection.rawValue)" }
}
