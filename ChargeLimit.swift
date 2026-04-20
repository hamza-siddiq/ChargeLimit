import SwiftUI
import ServiceManagement

@main
struct ChargeLimitApp: App {
    var body: some Scene {
        MenuBarExtra("Battery Limit", systemImage: "battery.100.bolt") {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var limit: Int? = nil
    @State private var bclmPath: String = ""
    @State private var errorMessage: String? = nil
    @State private var launchAtStartup = SMAppService.mainApp.status == .enabled
    
    let levels = [80, 85, 90, 95, 100]
    
    var body: some View {
        VStack {
            Text("Limit Battery Charge")
                .font(.headline)
            
            Divider()
            
            if bclmPath.isEmpty {
                Text("Error: bclm not found")
            } else {
                ForEach(levels, id: \.self) { level in
                    Button(action: { setLimit(level) }) {
                        HStack {
                            Text("\(level)%")
                            if limit == level {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                if let error = errorMessage {
                    Divider()
                    Text("Error: \(error)")
                }
            }
            
            Divider()
            
            Button(action: toggleLaunchAtStartup) {
                HStack {
                    Text("Launch at Startup")
                    if launchAtStartup {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            Button("Quit") {
                quitApp()
            }
        }
        .onAppear {
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
        
        // This script requests administrator privileges to run bclm write and bclm persist.
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
    
    func toggleLaunchAtStartup() {
        do {
            if launchAtStartup {
                try SMAppService.mainApp.unregister()
                launchAtStartup = false
            } else {
                try SMAppService.mainApp.register()
                launchAtStartup = true
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

