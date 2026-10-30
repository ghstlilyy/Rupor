import SwiftUI

struct ContentView: View {
    @StateObject private var audio = AudioEngine()
    @State private var preset: VoicePreset = .megaphone
    @State private var showSettings = false
    @State private var pressed = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.05, blue: 0.15), .black],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                header
                presetGrid
                Spacer()
                statusText
                talkButton
                Spacer()
                bottomBar
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .onAppear { audio.settings = preset.settings }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: $audio.settings)
                .presentationDetents([.medium, .large])
        }
        .alert("Нет доступа к микрофону", isPresented: $audio.permissionDenied) {
            Button("Настройки") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Разрешите доступ к микрофону в Настройках, чтобы использовать Rupor.")
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "megaphone.fill").foregroundStyle(.orange)
            Text("Rupor").font(.largeTitle.bold())
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .padding(10)
                    .background(.white.opacity(0.1), in: Circle())
            }
        }
        .foregroundStyle(.white)
    }

    private var presetGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(VoicePreset.allCases) { p in
                Button {
                    preset = p
                    audio.settings = p.settings
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: p.icon).font(.title3)
                        Text(p.rawValue).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(preset == p ? Color.orange : Color.white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(preset == p ? .black : .white)
                }
            }
        }
    }

    private var statusText: some View {
        Text(statusString)
            .font(.headline)
            .foregroundStyle(.white.opacity(0.7))
            .animation(.default, value: audio.state)
    }

    private var statusString: String {
        switch audio.state {
        case .idle: "Зажми и говори"
        case .recording: "Говори… отпусти, чтобы повторить"
        case .playing: "Воспроизведение"
        }
    }

    private var talkButton: some View {
        let recording = audio.state == .recording
        let color: Color = recording ? .red : (audio.state == .playing ? .green : .orange)
        return ZStack {
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: 240, height: 240)
                .scaleEffect(recording ? 1 + CGFloat(audio.level) * 0.35 : 1)
                .animation(.easeOut(duration: 0.08), value: audio.level)
            Circle()
                .fill(color.gradient)
                .frame(width: 190, height: 190)
                .shadow(color: color.opacity(0.6), radius: pressed ? 30 : 15)
            Image(systemName: recording ? "mic.fill" : (audio.state == .playing ? "speaker.wave.3.fill" : "megaphone.fill"))
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.black)
        }
        .scaleEffect(pressed ? 0.94 : 1)
        .animation(.spring(response: 0.25), value: pressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressed else { return }
                    pressed = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    audio.startRecording()
                }
                .onEnded { _ in
                    pressed = false
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    audio.stopRecordingAndPlay()
                }
        )
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Button {
                audio.replay()
            } label: {
                Label("Повторить", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.1), in: Capsule())
            }
            .disabled(audio.state != .idle)

            Button {
                audio.stopPlayback()
            } label: {
                Label("Стоп", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.1), in: Capsule())
            }
            .disabled(audio.state != .playing)
        }
        .foregroundStyle(.white)
    }
}

struct SettingsView: View {
    @Binding var settings: VoiceSettings

    var body: some View {
        NavigationStack {
            Form {
                Section("Голос") {
                    slider("Высота", value: $settings.pitch, range: -2400...2400,
                           text: String(format: "%+.0f пт", settings.pitch / 100))
                    slider("Скорость", value: $settings.rate, range: 0.5...2,
                           text: String(format: "%.2f×", settings.rate))
                }
                Section("Эффекты") {
                    Toggle("Рупор (фильтр мегафона)", isOn: $settings.megaphone)
                    slider("Искажение", value: $settings.distortion, range: 0...100,
                           text: "\(Int(settings.distortion))%")
                    slider("Эхо", value: $settings.echo, range: 0...100,
                           text: "\(Int(settings.echo))%")
                    slider("Реверб", value: $settings.reverb, range: 0...100,
                           text: "\(Int(settings.reverb))%")
                }
                Section("Выход") {
                    slider("Громкость", value: $settings.volume, range: 0...1,
                           text: "\(Int(settings.volume * 100))%")
                }
                Section {
                    Button("Сбросить", role: .destructive) { settings = VoiceSettings() }
                }
            }
            .navigationTitle("Войсченджер")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func slider(_ title: String, value: Binding<Float>, range: ClosedRange<Float>, text: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(text).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }
}
