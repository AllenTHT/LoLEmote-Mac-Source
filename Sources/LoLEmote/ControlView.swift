import SwiftUI
import AppKit
import EmoteCore

private let gold = Color(red: 0.80, green: 0.68, blue: 0.43)
private let ink = Color(red: 0.035, green: 0.060, blue: 0.080)

struct ControlView: View {
    @ObservedObject var model: AppModel
    @State private var search = ""
    @State private var category: EmoteCategory?
    private var visibleEmotes: [Emote] {
        Assets.emotes.filter { (category == nil || $0.category == category) && $0.matches(search) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 18) { wheelEditor; preview }
                        .frame(width: 348)
                    VStack(alignment: .leading, spacing: 18) { library; controls }
                        .frame(maxWidth: .infinity)
                }
                HStack(spacing: 6) {
                    Image(systemName: "menubar.rectangle")
                    Text("关闭窗口后，仍可从菜单栏控制表情。Esc / 右键取消轮盘。")
                }.font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(26)
        }
        .background(ink).foregroundStyle(Color(white: 0.92)).tint(gold)
        .preferredColorScheme(.dark).frame(minWidth: 780, minHeight: 690)
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("LoLEmote").font(.system(size: 29, weight: .semibold, design: .rounded)).foregroundStyle(gold)
                    Text("让表情出现在你的桌面").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("启用桌面表情", isOn: Binding(get: { model.enabled || model.awaitingPermission }, set: model.setEnabled))
                    .toggleStyle(.switch).fixedSize()
                    .disabled(!Assets.errors.isEmpty || Assets.availableEmotes.isEmpty)
            }
            HStack(alignment: .top, spacing: 8) {
                Circle().fill(model.enabled ? Color.green : gold.opacity(0.7)).frame(width: 6, height: 6).padding(.top, 5)
                Text(model.message).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if model.awaitingPermission {
                    Button("打开系统设置", action: model.openAccessibility).font(.system(size: 11))
                }
            }
        }
    }
    private var wheelEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("你的表情轮盘", detail: "点击位置，再装备右侧表情")
            ZStack {
                WheelCanvas(loadout: model.settings.loadout, selected: model.editingSlot)
                ForEach(WheelSlot.allCases) { slot in
                    Button { model.editingSlot = slot } label: { Circle().fill(Color.white.opacity(0.001)) }
                        .buttonStyle(.plain).frame(width: slot == .center ? 86 : 68, height: slot == .center ? 86 : 68)
                        .position(slotPosition(slot))
                        .help("\(slot.title)：\(Assets.emote(model.settings.loadout[slot])?.title ?? "空位")")
                        .accessibilityLabel("\(slot.title)位置，\(Assets.emote(model.settings.loadout[slot])?.title ?? "空位")")
                        .accessibilityAddTraits(model.editingSlot == slot ? .isSelected : [])
                }
            }.frame(width: 324, height: 324).frame(maxWidth: .infinity)
            HStack {
                Text("正在编辑 · \(model.editingSlot.title)").font(.system(size: 12)).foregroundStyle(gold)
                Spacer()
                Button("清空此格") { model.assign(nil) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }.padding(12).background(panel)
    }
    private var library: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("表情仓库", detail: "\(Assets.availableEmotes.count) / \(Assets.emotes.count) 个已配置 · 声音与动态可选")
            if Assets.availableEmotes.isEmpty {
                Text(Assets.setupMessage).font(.system(size: 11)).foregroundStyle(gold)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("名称、英雄或战队", text: $search)
                    .textFieldStyle(.plain).font(.system(size: 12))
                    .accessibilityLabel("搜索表情")
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("清空搜索")
                }
            }.padding(9).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Picker("表情分类", selection: $category) {
                    Text("全部").tag(nil as EmoteCategory?)
                    ForEach(EmoteCategory.allCases) { value in Text(value.title).tag(Optional(value)) }
                }.labelsHidden().accessibilityLabel("表情分类")
                Spacer()
                Text("\(visibleEmotes.count) 个").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            ScrollView {
              if visibleEmotes.isEmpty {
                Text("没有找到表情，试试其他名称或分类。")
                    .font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 35)
              } else {
              LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
                ForEach(visibleEmotes) { emote in
                    VStack(spacing: 6) {
                        Button { model.assign(emote) } label: {
                            VStack(spacing: 5) {
                                if let image = Assets.image(emote.id) { Image(nsImage: image).resizable().interpolation(.high).frame(width: 58, height: 58) }
                                else { Image(systemName: "photo.badge.plus").font(.system(size: 25)).foregroundStyle(.secondary).frame(width: 58, height: 58) }
                                Text(emote.title).font(.system(size: 11, weight: .medium))
                                    .multilineTextAlignment(.center).lineLimit(2).frame(height: 28)
                            }.frame(maxWidth: .infinity).padding(.top, 8)
                        }.buttonStyle(.plain).help("装备到\(model.editingSlot.title)")
                        .accessibilityLabel("装备\(emote.title)").disabled(!Assets.isReady(emote))
                        Text(Assets.status(emote)).font(.system(size: 9)).foregroundStyle(Assets.isReady(emote) ? gold : Color.secondary)
                        Button { model.preview(emote) } label: { Label("试用", systemImage: "play.fill").font(.system(size: 10)) }
                            .buttonStyle(.plain).foregroundStyle(gold).padding(.bottom, 9)
                            .accessibilityLabel("试用\(emote.title)").disabled(!Assets.isReady(emote))
                    }
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.035)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(model.settings.loadout[model.editingSlot] == emote.id ? gold : Color.white.opacity(0.07), lineWidth: 1))
                }
              }
              }
            }.frame(height: 300)
        }.padding(16).background(panel)
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionTitle("播放设置", detail: "修改后自动保存")
            VStack(alignment: .leading, spacing: 7) {
                Text("呼出快捷键").font(.system(size: 12))
                Picker("呼出快捷键", selection: Binding(get: { model.settings.trigger }, set: model.setChord)) {
                    ForEach(TriggerChord.allCases) { chord in Text(chord.title).tag(chord) }
                }.labelsHidden().font(.system(size: 11))
                Text("按住约 0.18 秒 → 移动选择 → 松开发送")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                if model.settings.trigger == .controlOptionCommand {
                    Text("这组键与 Ping 默认设置相同；同时使用时请为其中一个 App 换一组。").font(.system(size: 10)).foregroundStyle(gold)
                }
            }
            Divider().overlay(gold.opacity(0.12))
            HStack { Text("表情大小"); Spacer(); Text("\(Int(model.settings.size)) 点").foregroundStyle(gold).monospacedDigit() }.font(.system(size: 12))
            Slider(value: Binding(get: { model.settings.size }, set: { model.setSize($0.rounded()) }), in: 64...128).accessibilityLabel("表情大小")
            HStack {
                Text("原声音量")
                Spacer()
                Text(model.settings.muted ? "已静音" : "\(Int((model.settings.volume*100).rounded()))%").foregroundStyle(gold).monospacedDigit()
            }.font(.system(size: 12))
            Slider(value: Binding(get: { model.settings.volume }, set: model.setVolume), in: 0...1).accessibilityLabel("原声音量")
            Toggle("静音", isOn: Binding(get: { model.settings.muted }, set: model.setMuted)).toggleStyle(.checkbox).font(.system(size: 12))
        }.padding(16).background(panel)
    }
    private var preview: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("表情试用").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(model.previewEmote?.title ?? "无需开启桌面权限").font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(.horizontal, 14).padding(.top, 13)
            ZStack {
                if model.previewEmote == nil {
                    Text("点击收藏中的「试用」").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                EmotePreview(emote: model.previewEmote, size: model.settings.size, token: model.previewToken)
            }.frame(height: 192)
        }.background(panel)
    }
    private var panel: some View {
        RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.025))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(gold.opacity(0.16), lineWidth: 1))
    }
    private func sectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
    private func slotPosition(_ slot: WheelSlot) -> CGPoint {
        guard slot != .center else { return CGPoint(x: 162, y: 162) }
        let theta = Double(slot.rawValue)*Double.pi/4
        return CGPoint(x: 162+sin(theta)*106, y: 162-cos(theta)*106)
    }
}

private struct WheelCanvas: NSViewRepresentable {
    let loadout: Loadout
    let selected: WheelSlot
    func makeNSView(context: Context) -> WheelView { WheelView(frame: CGRect(x: 0, y: 0, width: 324, height: 324)) }
    func updateNSView(_ view: WheelView, context: Context) { view.loadout = loadout; view.selected = selected }
}

struct EmotePreview: NSViewRepresentable {
    let emote: Emote?
    let size: Double
    let token: UUID
    final class Coordinator { var token: UUID? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView(frame: CGRect(x: 0, y: 0, width: 324, height: 192)) }
    func updateNSView(_ view: NSView, context: Context) {
        guard context.coordinator.token != token || emote == nil else { return }
        view.subviews.forEach { ($0 as? EmoteEffectView)?.stop(); $0.removeFromSuperview() }
        context.coordinator.token = token
        guard let emote else { return }
        let effect = EmoteEffectView(frame: view.bounds, emote: emote, size: size)
        effect.autoresizingMask = [.width, .height]; view.addSubview(effect); effect.start()
    }
    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        view.subviews.forEach { ($0 as? EmoteEffectView)?.stop() }
    }
}
