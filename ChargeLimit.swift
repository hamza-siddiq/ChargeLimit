import SwiftUI
import ServiceManagement

@main
struct ChargeLimitApp: App {
    var body: some Scene {
        MenuBarExtra("Battery Limit", systemImage: "battery.100.bolt") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuRowButtonStyle: ButtonStyle {
    var leadingPadding: CGFloat = 8
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.leading, leadingPadding)
            .padding(.trailing, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(configuration.isPressed ? Color.white.opacity(0.12) : Color.clear)
            )
            .hoverEffect()
            .padding(.horizontal, 6)
    }
}

extension View {
    @ViewBuilder
    func hoverEffect() -> some View {
        modifier(HoverHighlight())
    }
}

struct HoverHighlight: ViewModifier {
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hovering ? Color.accentColor.opacity(0.85) : Color.clear)
            )
            .onHover { hovering = $0 }
    }
}

struct ContentView: View {
    @State private var limit: Int? = nil
    @State private var bclmPath: String = ""
    @State private var errorMessage: String? = nil
    @State private var launchAtStartup = true
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true

    let levels = [80, 85, 90, 95, 100]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if bclmPath.isEmpty {
                Text("Error: bclm not found")
                    .foregroundStyle(.white)
                    .padding(10)
            } else {
                Text("Charge Limit")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 2)

                Divider()
                    .padding(.horizontal, 12)

                ForEach(levels, id: \.self) { level in
                    Button {
                        setLimit(level)
                    } label: {
                        HStack {
                            Text("\(level)%")
                                .foregroundStyle(.white)
                            Spacer()
                            if self.limit == level {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(MenuRowButtonStyle(leadingPadding: 20))
                }

                if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10)
                }

                Divider()
                    .padding(.horizontal, 12)

                Button {
                    launchAtStartup.toggle()
                    toggleLaunchAtStartup(enabled: launchAtStartup)
                } label: {
                    HStack {
                        Text("Launch at Startup")
                            .foregroundStyle(.white)
                        Spacer()
                        if launchAtStartup {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(MenuRowButtonStyle())

                Divider()
                    .padding(.horizontal, 12)

                Button {
                    quitApp()
                } label: {
                    HStack {
                        Text("Quit")
                            .foregroundStyle(.white)
                        Spacer()
                        Text("⌘Q")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .buttonStyle(MenuRowButtonStyle())
                .keyboardShortcut("q")
                .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 4)
        .frame(width: 220)
        .onAppear {
            if isFirstLaunch {
                isFirstLaunch = false
                try? SMAppService.mainApp.register()
            }
            findBclm()
            fetchLimit()
        }
    }

    func findBclm() {
        let paths = ["/opt/homebrew/bin/bclm", "/usr/local/bin/bclm"]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                bclmPath = path
                return
            }
        }
    }

    func fetchLimit() {
        guard !bclmPath.isEmpty else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: bclmPath)
        process.arguments = ["read"]
        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), let value = Int(output) {
                self.limit = value
                self.errorMessage = nil
            }
        } catch {
            print("Failed to read limit: \(error)")
            self.errorMessage = "Failed to read limit"
        }
    }

    func setLimit(_ value: Int) {
        guard !bclmPath.isEmpty else { return }

        let script = """
        do shell script "\(bclmPath) write \(value) && \(bclmPath) persist" with administrator privileges
        """

        var errorDict: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            _ = appleScript.executeAndReturnError(&errorDict)
            if errorDict == nil {
                self.limit = value
                self.errorMessage = nil
            } else {
                if let errorString = errorDict?[NSAppleScript.errorMessage] as? String {
                    self.errorMessage = errorString
                } else {
                    self.errorMessage = "Permission denied or error occurred."
                }
            }
        }
    }

    func toggleLaunchAtStartup(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to toggle launch at startup: \(error)")
        }
    }

    func quitApp() {
        if limit != 100 {
            setLimit(100)
        }
        NSApplication.shared.terminate(nil)
    }
}
