import SwiftUI
import ServiceManagement
import IOKit.ps
import Foundation

class BatteryManager: ObservableObject {
    @Published var isSailing = false
    @AppStorage("sailingMode") var sailingModeEnabled = false
    @AppStorage("chargeLimit") var chargeLimit: Int = 100
    
    private var timer: Timer?
    var bclmPath: String = ""
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.checkBattery()
        }
        checkBattery()
    }
    
    func checkBattery() {
        guard !bclmPath.isEmpty else { return }
        let level = getBatteryLevel()
        
        if sailingModeEnabled && chargeLimit < 100 {
            let lowerLimit = chargeLimit - 10
            
            if level <= lowerLimit {
                // Time to pick back up!
                isSailing = false
                setLimitSilently(chargeLimit)
            } else if level >= chargeLimit {
                // Reached top, start sailing (discharge down to lowerLimit)
                isSailing = true
                setLimitSilently(lowerLimit)
            } else {
                // We are in between. Enforce current state limit.
                if isSailing {
                    setLimitSilently(lowerLimit)
                } else {
                    setLimitSilently(chargeLimit)
                }
            }
        } else {
            // Standard mode
            isSailing = false
            setLimitSilently(chargeLimit)
        }
    }
    
    func getBatteryLevel() -> Int {
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                if let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                   let capacity = info[kIOPSCurrentCapacityKey] as? Int {
                    return capacity
                }
            }
        }
        return 100
    }
    
    func setLimitSilently(_ value: Int) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        task.arguments = ["-n", bclmPath, "write", "\(value)"]
        try? task.run()
        task.waitUntilExit()
        
        let task2 = Process()
        task2.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        task2.arguments = ["-n", bclmPath, "persist"]
        try? task2.run()
        task2.waitUntilExit()
    }
}

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
    @StateObject private var batteryManager = BatteryManager()
    @AppStorage("launchAtStartupEnabled") private var launchAtStartup = false
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    @State private var errorMessage: String? = nil
    @State private var installedHelper = false

    let levels = [80, 85, 90, 95, 100]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if batteryManager.bclmPath.isEmpty {
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
                            if batteryManager.chargeLimit == level {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(MenuRowButtonStyle(leadingPadding: 20))
                }

                Divider()
                    .padding(.horizontal, 12)

                Button {
                    batteryManager.sailingModeEnabled.toggle()
                    batteryManager.checkBattery()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Sailing Mode")
                                .foregroundStyle(.white)
                            Text("Picks back up at \(max(0, batteryManager.chargeLimit - 10))%")
                                .font(.system(size: 10))
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        if batteryManager.sailingModeEnabled {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(MenuRowButtonStyle())
                .disabled(batteryManager.chargeLimit == 100)
                .opacity(batteryManager.chargeLimit == 100 ? 0.5 : 1.0)

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
            findBclm()
            installHelperIfNeeded()
            
            if isFirstLaunch {
                isFirstLaunch = false
                try? SMAppService.mainApp.register()
                launchAtStartup = (SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .notFound)
            } else {
                // Ensure the service is in sync with the user's preference
                toggleLaunchAtStartup(enabled: launchAtStartup)
            }
            
            batteryManager.start()
        }
    }

    func installHelperIfNeeded() {
        guard !installedHelper else { return }
        let path = "/private/etc/sudoers.d/chargelimit"
        if !FileManager.default.fileExists(atPath: path) {
            let actualBclmPath = batteryManager.bclmPath.isEmpty ? "/usr/local/bin/bclm" : batteryManager.bclmPath
            let script = """
            do shell script "mkdir -p /private/etc/sudoers.d && echo '%admin ALL=(ALL) NOPASSWD: \(actualBclmPath)' > \(path) && echo '%admin ALL=(ALL) NOPASSWD: /usr/local/bin/bclm' >> \(path) && echo '%admin ALL=(ALL) NOPASSWD: /opt/homebrew/bin/bclm' >> \(path) && chmod 440 \(path)" with administrator privileges
            """
            var errorDict: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&errorDict)
            }
        }
        installedHelper = true
    }

    func findBclm() {
        if let bundledPath = Bundle.main.path(forResource: "bclm", ofType: nil) {
            batteryManager.bclmPath = bundledPath
            return
        }
        let paths = ["/opt/homebrew/bin/bclm", "/usr/local/bin/bclm"]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                batteryManager.bclmPath = path
                return
            }
        }
    }

    func fetchLimit() {
        // Obsolete as BatteryManager tracks state via AppStorage and silent execution
    }

    func setLimit(_ value: Int) {
        batteryManager.chargeLimit = value
        batteryManager.checkBattery()
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
        if batteryManager.chargeLimit != 100 {
            batteryManager.chargeLimit = 100
            batteryManager.sailingModeEnabled = false
            batteryManager.checkBattery()
        }
        NSApplication.shared.terminate(nil)
    }
}
