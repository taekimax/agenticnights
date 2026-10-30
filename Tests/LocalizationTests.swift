import Foundation

@main
struct LocalizationTests {
    struct Failure: Error { let message: String }
    static var resources: URL { URL(fileURLWithPath: CommandLine.arguments[1]) }

    static func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
        if !value() { throw Failure(message: message) }
    }

    static func withDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    static func write(_ object: [String: Any], to url: URL) throws {
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            .write(to: url, options: .atomic)
    }

    static func select(_ language: String, in directory: URL) throws {
        try language.write(to: directory.appendingPathComponent("language.txt"), atomically: true, encoding: .utf8)
    }

    static func main() throws {
        let tests: [(String, () throws -> Void)] = [
            ("bundled catalogs have matching keys and placeholders", catalogs),
            ("first launch exports translations and follows system language", firstLaunch),
            ("custom translation takes effect after restart and preserves files", customTranslation),
            ("invalid entries fall back individually to English", invalidEntries),
            ("malformed catalogs recover without overwriting user data", malformedCatalog),
            ("explicit language, regional fallback and unsupported language", languageSelection),
            ("new English keys remain available after an upgrade", upgrade),
            ("legacy defaults update without changing custom translation files", legacyUpgrade),
            ("partial Korean files fall back to current Korean text", partialKorean),
            ("bundled UI works when app data cannot be created", unavailableDirectory),
        ]
        for (name, test) in tests { try test(); print("PASS: \(name)") }
        print("PASS: \(tests.count) localization tests")
    }

    static func catalogs() throws {
        let decoder = JSONDecoder()
        let english = try decoder.decode([String: String].self, from: Data(contentsOf: resources.appendingPathComponent("en.json")))
        let korean = try decoder.decode([String: String].self, from: Data(contentsOf: resources.appendingPathComponent("ko.json")))
        try expect(!english.isEmpty && english.keys.sorted() == korean.keys.sorted(), "Bundled catalogs must be complete")
        for (key, value) in english {
            try expect(!value.isEmpty && !(korean[key] ?? "").isEmpty, "Empty bundled text: \(key)")
            try expect(Localization.tokens(in: value) == Localization.tokens(in: korean[key]!), "Placeholder mismatch: \(key)")
        }
    }

    static func firstLaunch() throws {
        try withDirectory { root in
            let directory = root.appendingPathComponent("Translations")
            let ui = try Localization(resources: resources, directory: directory, preferredLanguages: ["ko-KR", "en-US"])
            try expect(ui.language == "ko" && ui.warnings.isEmpty, "Korean system preference must work on first launch")
            try expect(ui.text("settings.cancel") != "Cancel", "Settings must use Korean text")
            for name in ["en.json", "ko.json"] {
                let actual = try Data(contentsOf: directory.appendingPathComponent(name))
                let source = try Data(contentsOf: resources.appendingPathComponent(name))
                try expect(actual == source, "First launch must export \(name)")
            }
            let choice = try String(contentsOf: directory.appendingPathComponent("language.txt"), encoding: .utf8)
            try expect(choice.trimmingCharacters(in: .whitespacesAndNewlines) == "auto", "Default must follow system")
            for filename in ["legacy-v1.2.json", "legacy-v1.3.json"] {
                try expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(filename).path),
                           "Migration data must not be exported as a user language")
            }
        }
    }

    static func customTranslation() throws {
        try withDirectory { directory in
            let original = try Localization(resources: resources, directory: directory, preferredLanguages: ["en-US"])
            let url = directory.appendingPathComponent("de.json")
            try write([
                "settings.cancel": "Abbrechen",
                "status.summary": "{awake} / {cover}",
                "status.error": "100%: {error}",
            ], to: url)
            let saved = try Data(contentsOf: url)
            try select("de\n", in: directory)
            try expect(original.text("settings.cancel") == "Cancel", "Changes must wait for next launch")
            let restarted = try Localization(resources: resources, directory: directory, preferredLanguages: ["ko"])
            try expect(restarted.language == "de" && restarted.text("settings.cancel") == "Abbrechen", "Custom language must override system")
            try expect(restarted.text("settings.apply") == original.text("settings.apply"), "Partial translations must use English fallback")
            try expect(restarted.text("status.summary", ["awake": "Ready", "cover": "Covered"]) == "Ready / Covered", "Translations must support reordered placeholders")
            try expect(restarted.text("status.error", ["error": "{awake} %s"]) == "100%: {awake} %s", "Values must be literal, not recursively substituted or printf-formatted")
            let after = try Data(contentsOf: url)
            try expect(after == saved && restarted.warnings.isEmpty, "Restart must preserve custom translation bytes")
        }
    }

    static func invalidEntries() throws {
        let english = try JSONDecoder().decode([String: String].self,
            from: Data(contentsOf: resources.appendingPathComponent("en.json")))
        try withDirectory { directory in
            try write([
                "settings.cancel": "Custom cancel",
                "settings.apply": 42,
                "status.off": "  ",
                "status.nextCover": "At {wrong}",
                "status.stopsAt": "At some time",
            ], to: directory.appendingPathComponent("de.json"))
            try select("de", in: directory)
            let ui = try Localization(resources: resources, directory: directory, preferredLanguages: ["ko"])
            try expect(ui.text("settings.cancel") == "Custom cancel", "Valid neighboring entry must survive")
            try expect(ui.text("settings.apply") == english["settings.apply"] && ui.text("status.off") == english["status.off"], "Bad types and blank entries must fall back")
            try expect(ui.text("status.nextCover", ["time": "22:00"]) == english["status.nextCover"]!.replacingOccurrences(of: "{time}", with: "22:00"), "Wrong placeholder must fall back")
            try expect(ui.text("status.stopsAt", ["time": "23:00"]) == english["status.stopsAt"]!.replacingOccurrences(of: "{time}", with: "23:00"), "Missing placeholder must fall back")
            try expect(ui.warnings.count == 4, "Invalid entries must be reported")
        }
    }

    static func malformedCatalog() throws {
        try withDirectory { directory in
            let bad = Data("{broken json".utf8)
            let korean = directory.appendingPathComponent("ko.json")
            try bad.write(to: korean)
            try select("ko", in: directory)
            let ui = try Localization(resources: resources, directory: directory)
            try expect(ui.text("settings.cancel") != "Cancel" && !ui.warnings.isEmpty, "Broken Korean file must use bundled Korean")
            let preserved = try Data(contentsOf: korean)
            try expect(preserved == bad, "Do not replace the user's broken file")
            try bad.write(to: directory.appendingPathComponent("de.json"))
            try select("de", in: directory)
            let custom = try Localization(resources: resources, directory: directory)
            try expect(custom.text("settings.cancel") == "Cancel" && !custom.warnings.isEmpty, "Broken custom language must use English")
        }
    }

    static func languageSelection() throws {
        try withDirectory { directory in
            try select("en", in: directory)
            let english = try Localization(resources: resources, directory: directory, preferredLanguages: ["ko"])
            try expect(english.language == "en", "Explicit English must override Korean system preference")
            try write(["settings.cancel": "Regional cancel"], to: directory.appendingPathComponent("pt-BR.json"))
            try select("auto", in: directory)
            let regional = try Localization(resources: resources, directory: directory, preferredLanguages: ["pt_BR", "en"])
            try expect(regional.language == "pt-br" && regional.text("settings.cancel") == "Regional cancel", "Region and separator normalization must match custom files")
            let nextPreferred = try Localization(resources: resources, directory: directory, preferredLanguages: ["fr-CA", "ko-KR"])
            try expect(nextPreferred.language == "ko", "Try the next supported system preference")
            try select("ja", in: directory)
            let unsupported = try Localization(resources: resources, directory: directory, preferredLanguages: ["ko"])
            try expect(unsupported.language == "en" && !unsupported.warnings.isEmpty, "Unavailable explicit selection must use English")
        }
    }

    static func upgrade() throws {
        try withDirectory { root in
            let bundle = root.appendingPathComponent("resources")
            let directory = root.appendingPathComponent("data")
            try FileManager.default.copyItem(at: resources, to: bundle)
            _ = try Localization(resources: bundle, directory: directory, preferredLanguages: ["en"])
            try write(["settings.cancel": "Keep my custom label"], to: directory.appendingPathComponent("en.json"))
            var updated = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: bundle.appendingPathComponent("en.json")))
            updated["new.feature"] = "New feature"
            try write(updated, to: bundle.appendingPathComponent("en.json"))
            let ui = try Localization(resources: bundle, directory: directory, preferredLanguages: ["en"])
            try expect(ui.text("settings.cancel") == "Keep my custom label", "Update must preserve existing translation edits")
            try expect(ui.text("new.feature") == "New feature", "New bundled keys must remain usable without rewriting user file")
        }
    }

    static func unavailableDirectory() throws {
        try withDirectory { root in
            let blocked = root.appendingPathComponent("file")
            try Data("not a directory".utf8).write(to: blocked)
            let ui = try Localization(resources: resources, directory: blocked, preferredLanguages: ["ko-KR"])
            try expect(ui.language == "ko" && ui.text("settings.cancel") != "Cancel", "Bundled UI must work without writable app data")
            try expect(!ui.warnings.isEmpty, "App data failure must be reported")
        }
    }

    static func legacyUpgrade() throws {
        for filename in ["legacy-v1.2.json", "legacy-v1.3.json"] {
            let legacy = try JSONDecoder().decode([String: [String: String]].self,
                from: Data(contentsOf: resources.appendingPathComponent(filename)))
            for language in ["en", "ko"] {
                try withDirectory { directory in
                    var oldCatalog = legacy[language]!
                    oldCatalog["settings.cancel"] = "My custom cancel"
                    let url = directory.appendingPathComponent("\(language).json")
                    try write(oldCatalog, to: url)
                    let original = try Data(contentsOf: url)
                    try select(language, in: directory)
                    let ui = try Localization(resources: resources, directory: directory)
                    let current = try JSONDecoder().decode([String: String].self,
                        from: Data(contentsOf: resources.appendingPathComponent("\(language).json")))
                    try expect(ui.text("feature.cover") == current["feature.cover"], "Old feature names must update")
                    try expect(ui.text("settings.footer") == current["settings.footer"], "Obsolete click/shortcut instructions must update")
                    try expect(ui.text("status.tooltip", ["status": "Ready"]) == current["status.tooltip"]!.replacingOccurrences(of: "{status}", with: "Ready"),
                               "Obsolete tooltip placeholders must not cause warnings or stale instructions")
                    try expect(ui.text("settings.dismissOnMouseMove") == current["settings.dismissOnMouseMove"], "New controls must use the selected language")
                    try expect(ui.text("settings.cancel") == "My custom cancel", "Existing user edits must survive")
                    try expect(ui.warnings.isEmpty, "Unedited legacy values must upgrade without warnings")
                    let after = try Data(contentsOf: url)
                    try expect(after == original, "Upgrade must preserve exact custom-file bytes")
                }
            }
        }
    }

    static func partialKorean() throws {
        try withDirectory { directory in
            let url = directory.appendingPathComponent("ko.json")
            try write([
                "settings.cancel": "내 취소",
                "settings.shortcut": 42,
                "status.nextCover": "잘못된 {placeholder}",
            ], to: url)
            try select("ko", in: directory)
            let ui = try Localization(resources: resources, directory: directory)
            let korean = try JSONDecoder().decode([String: String].self,
                from: Data(contentsOf: resources.appendingPathComponent("ko.json")))
            try expect(ui.text("settings.cancel") == "내 취소", "A custom Korean label must win")
            for key in ["settings.shortcut", "settings.dismissOnMouseMove", "status.nextCover"] {
                try expect(ui.text(key) == korean[key], "Missing or invalid Korean entries must use bundled Korean: \(key)")
            }
            try expect(ui.warnings.count == 2, "Invalid custom entries must still be reported")
        }
    }
}
