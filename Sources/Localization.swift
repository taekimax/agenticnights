import Foundation

/// English is the source of truth. User-editable JSON is loaded once at launch.
final class Localization {
    static let shared: Localization = {
        let resources = Bundle.main.resourceURL!.appendingPathComponent("Translations")
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/agenticnights/Translations")
        do { return try Localization(resources: resources, directory: directory) }
        catch { fatalError("Could not load bundled English UI text: \(error)") }
    }()

    let directory: URL
    private(set) var language = "en"
    private(set) var warnings: [String] = []
    private var strings: [String: String]
    private static let tokenPattern = try! NSRegularExpression(pattern: #"\{[A-Za-z][A-Za-z0-9_]*\}"#)

    init(resources: URL, directory: URL, preferredLanguages: [String] = Locale.preferredLanguages) throws {
        self.directory = directory
        let english = try JSONDecoder().decode([String: String].self,
            from: Data(contentsOf: resources.appendingPathComponent("en.json")))
        strings = english
        let files = FileManager.default
        let bundled = Self.catalogs(in: resources)
        let selection = directory.appendingPathComponent("language.txt")
        do {
            try files.createDirectory(at: directory, withIntermediateDirectories: true)
            for source in bundled.values {
                let destination = directory.appendingPathComponent(source.lastPathComponent)
                if !files.fileExists(atPath: destination.path) { try files.copyItem(at: source, to: destination) }
            }
            if !files.fileExists(atPath: selection.path) {
                try Data("auto\n".utf8).write(to: selection, options: .withoutOverwriting)
            }
        } catch {
            warnings.append("Could not prepare editable translations: \(error.localizedDescription)")
        }

        let custom = Self.catalogs(in: directory)
        let requested: String
        do {
            requested = try String(contentsOf: selection, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            requested = "auto"
            warnings.append("Could not read language.txt; using system languages.")
        }
        let preferences = requested.lowercased() == "auto" ? preferredLanguages : [requested]
        let available = Set(bundled.keys).union(custom.keys)
        language = preferences.lazy.flatMap { Self.candidates(for: $0) }.first(where: available.contains) ?? "en"
        if requested.lowercased() != "auto", !Self.candidates(for: requested).contains(language) {
            warnings.append("Requested language is unavailable; using English.")
        }

        // New or invalid entries use the selected bundled language before English,
        // so an older Korean file cannot turn new controls into English controls.
        if let url = bundled[language], let translated = readCatalog(url) {
            overlay(translated, english: english)
        }
        if let url = custom[language], let translated = readCatalog(url) {
            // Recognize previously exported defaults without rewriting user files.
            let legacy = ["legacy-v1.2.json", "legacy-v1.3.json", "legacy-v1.4.json"].compactMap { filename in
                (try? Data(contentsOf: resources.appendingPathComponent(filename))).flatMap {
                    try? JSONDecoder().decode([String: [String: String]].self, from: $0)
                }?[language]
            }
            overlay(translated.filter { key, value in
                guard let text = value as? String else { return true }
                return !legacy.contains { $0[key] == text }
            }, english: english)
        }
    }

    private func overlay(_ translated: [String: Any], english: [String: String]) {
        for (key, source) in english {
            guard let value = translated[key] else { continue }
            guard let text = value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  Self.tokens(in: text) == Self.tokens(in: source) else {
                warnings.append("Invalid translation for \(key); using bundled text.")
                continue
            }
            strings[key] = text
        }
    }

    func text(_ key: String, _ values: [String: String] = [:]) -> String {
        let template = strings[key] ?? key
        // Replace only tokens in the template, never token-looking text inside a value.
        let result = NSMutableString(string: template)
        let matches = Self.tokenPattern.matches(in: template, range: NSRange(template.startIndex..., in: template))
        for match in matches.reversed() {
            let token = (template as NSString).substring(with: match.range)
            if let value = values[String(token.dropFirst().dropLast())] {
                result.replaceCharacters(in: match.range, with: value)
            }
        }
        return result as String
    }

    private func readCatalog(_ url: URL) -> [String: Any]? {
        do {
            let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
            guard let strings = object as? [String: Any] else {
                warnings.append("\(url.lastPathComponent) must contain a JSON object.")
                return nil
            }
            return strings
        } catch {
            warnings.append("Could not read \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    private static func catalogs(in directory: URL) -> [String: URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        var result: [String: URL] = [:]
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where url.pathExtension == "json" {
            if let code = normalized(url.deletingPathExtension().lastPathComponent) { result[code] = url }
        }
        return result
    }

    private static func normalized(_ code: String) -> String? {
        let code = code.replacingOccurrences(of: "_", with: "-").lowercased()
        guard code.range(of: #"^[a-z]{2,3}(-[a-z0-9]{2,8})*$"#, options: .regularExpression) != nil else { return nil }
        return code
    }

    private static func candidates(for code: String) -> [String] {
        guard let code = normalized(code) else { return [] }
        var parts = code.split(separator: "-")
        var result: [String] = []
        while !parts.isEmpty {
            result.append(parts.joined(separator: "-"))
            parts.removeLast()
        }
        return result
    }

    static func tokens(in text: String) -> Set<String> {
        Set(tokenPattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .map { (text as NSString).substring(with: $0.range) })
    }
}

func tr(_ key: String, _ values: [String: String] = [:]) -> String {
    Localization.shared.text(key, values)
}
