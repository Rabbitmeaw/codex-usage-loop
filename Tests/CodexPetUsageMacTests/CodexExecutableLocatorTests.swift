import XCTest
@testable import CodexPetUsageMac

final class CodexExecutableLocatorTests: XCTestCase {
    private let home = "/Users/tester"

    private func makeLocator(
        executables: Set<String> = [],
        directories: [String: [String]] = [:],
        shellResult: String? = nil
    ) -> CodexExecutableLocator {
        CodexExecutableLocator(
            homeDirectory: home,
            isExecutable: { executables.contains($0) },
            directoryNames: { directories[$0] ?? [] },
            shellLookup: { shellResult }
        )
    }

    func testPrefersChatGPTBundledNewLayout() {
        let bundled = "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"
        let nvm = "\(home)/.nvm/versions/node/v24.5.0/bin/codex"
        let locator = makeLocator(executables: [bundled, nvm])

        let outcome = locator.locate()

        XCTAssertEqual(outcome.executable?.path, bundled)
    }

    func testFallsBackToLegacyBundledLayout() {
        let legacy = "/Applications/ChatGPT.app/Contents/Resources/codex"
        let locator = makeLocator(executables: [legacy])

        let outcome = locator.locate()

        XCTAssertEqual(outcome.executable?.path, legacy)
    }

    func testDiscoversNewestNvmVersionFirst() {
        let directory = "\(home)/.nvm/versions/node"
        let newest = "\(directory)/v24.5.0/bin/codex"
        let locator = makeLocator(
            executables: [newest],
            directories: [directory: ["v20.0.0", "v24.5.0"]]
        )

        let outcome = locator.locate()

        XCTAssertEqual(outcome.executable?.path, newest)
        XCTAssertTrue(outcome.searchedPaths.contains(newest))
    }

    func testPrefersBundledOverUserInstalledCodex() {
        let bundled = "/Applications/Codex.app/Contents/Resources/codex-cli/bin/codex"
        let local = "\(home)/.local/bin/codex"
        let locator = makeLocator(executables: [local, bundled])

        XCTAssertEqual(locator.locate().executable?.path, bundled)
    }

    func testFindsVersionManagerShims() {
        let cases = [
            "\(home)/.volta/bin/codex",
            "\(home)/.asdf/shims/codex",
            "\(home)/.mise/shims/codex",
            "\(home)/Library/pnpm/codex"
        ]
        for path in cases {
            let locator = makeLocator(executables: [path])
            XCTAssertEqual(locator.locate().executable?.path, path, "应找到 \(path)")
        }
    }

    func testUsesShellLookupWhenStaticCandidatesAreMissing() {
        let locator = makeLocator(executables: ["/custom/location/codex"],
                                  shellResult: "/custom/location/codex")

        let outcome = locator.locate()

        XCTAssertEqual(outcome.executable?.path, "/custom/location/codex")
        XCTAssertTrue(outcome.searchedPaths.contains("/custom/location/codex"))
    }

    func testIgnoresShellResultThatIsNotExecutable() {
        let locator = makeLocator(shellResult: "/custom/location/codex")

        let outcome = locator.locate()

        XCTAssertNil(outcome.executable)
    }

    func testReportsSearchedPathsWhenNothingIsFound() {
        let locator = makeLocator()

        let outcome = locator.locate()

        XCTAssertNil(outcome.executable)
        XCTAssertTrue(outcome.searchedPaths.contains("/opt/homebrew/bin/codex"))
        XCTAssertTrue(outcome.searchedPaths.contains("/usr/local/bin/codex"))
    }
}
