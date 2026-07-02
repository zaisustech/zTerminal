import Foundation

/// Pure, testable logic that turns the current prompt input into an inline
/// ghost-text suggestion for a **package.json script name**, aware of which
/// package manager the project uses.
///
/// zTerminal already discovers a project's scripts and its package manager(s)
/// from the lockfile / `packageManager` field (see `PackageRunner`). This type
/// answers a narrower question for the autosuggest overlay: given what the user
/// has typed, the managers detected for the current directory, and the available
/// scripts, what dim suffix should we draw after the cursor?
///
/// It completes a script name only when the typed command word matches a
/// **detected** manager and the cursor is in a script position for that manager:
///   • `npm run <script>`                     (npm runs scripts only via `run`)
///   • `pnpm run <script>` / `pnpm <script>`
///   • `yarn run <script>` / `yarn <script>`  (yarn runs scripts bare)
///   • `bun run <script>`  / `bun <script>`    (bun runs scripts bare)
///
/// The returned value is only the *remaining* characters of the match (fish
/// style): typing `yarn de` with a `dev` script yields `"v"`.
public enum ScriptCompletion {

    /// Script names that make the best default suggestion, in priority order.
    public static let preferredNames = ["dev", "start", "develop", "serve", "watch"]

    /// Reorder `scripts` so preferred names lead (in `preferredNames` order),
    /// followed by the rest in their original order. Pure; stable for the tail.
    public static func ranked(_ scripts: [String]) -> [String] {
        var head: [String] = []
        for name in preferredNames where scripts.contains(name) { head.append(name) }
        let tail = scripts.filter { !head.contains($0) }
        return head + tail
    }

    /// The dim suffix to draw after the cursor, or nil when nothing applies.
    ///
    /// - Parameters:
    ///   - input: current prompt input (prompt end → cursor, no trailing newline).
    ///   - managers: the package managers detected for the current directory (from
    ///     the lockfile / `packageManager` field). The command word must be one of
    ///     these for a suggestion to appear — so a `yarn.lock` project completes
    ///     `yarn …` but not `bun …`.
    ///   - scripts: the available script names, already ranked (see `ranked(_:)`).
    public static func ghostSuffix(forInput input: String,
                                   managers: [PackageManager],
                                   scripts: [String]) -> String? {
        guard !scripts.isEmpty, !managers.isEmpty else { return nil }
        guard let (manager, partial, precedingArgs) = slot(forInput: input, managers: managers)
        else { return nil }

        // A script slot is `<mgr> run <partial>`, plus the bare `<mgr> <partial>`
        // for managers that run scripts without `run` (bun/pnpm/yarn).
        let isScriptSlot = precedingArgs == ["run"] || (manager.runsScriptsBare && precedingArgs.isEmpty)
        guard isScriptSlot else { return nil }

        // Most-preferred script that has `partial` as a prefix and is strictly
        // longer than it (so an already-complete word yields no ghost of itself).
        guard let match = scripts.first(where: {
            $0.count > partial.count && $0.hasPrefix(partial)
        }) else { return nil }

        return String(match.dropFirst(partial.count))
    }

    /// Resolve `(manager, partial, precedingArgs)` when the command word is a
    /// detected package manager, else nil. `partial` is the word being typed
    /// (empty when the input ends in whitespace); `precedingArgs` are the
    /// arguments after the command word that come before `partial`.
    private static func slot(forInput input: String,
                             managers: [PackageManager]) -> (PackageManager, String, [String])? {
        let words = input.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let cmd = words.first,
              let manager = PackageManager(rawValue: cmd),
              managers.contains(manager) else { return nil }
        let endsWithSpace = input.last == " "
        let args = Array(words.dropFirst())
        if endsWithSpace {
            return (manager, "", args)
        } else {
            return (manager, args.last ?? "", Array(args.dropLast()))
        }
    }
}
