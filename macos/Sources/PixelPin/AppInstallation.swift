import Foundation

enum AppInstallation {
    static func isInstalled(_ bundleURL: URL = Bundle.main.bundleURL,
                            home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let components = bundleURL.standardizedFileURL.pathComponents
        return [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")].contains { root in
            let prefix = root.standardizedFileURL.pathComponents
            return components.count > prefix.count && components.starts(with: prefix)
        }
    }
}
