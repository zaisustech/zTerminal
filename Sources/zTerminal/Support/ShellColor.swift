import Foundation

/// Sets up new shells without editing the user's dotfiles, and installs the
/// user's global script shortcuts:
///   • color env vars so `ls`, `grep`, `git`, etc. colorize;
///   • a ZDOTDIR (zsh) / rcfile (bash) that sources the user's real config first
///     (leaving their own prompt intact), emits OSC 7 for CWD tracking, and
///     defines script-shortcut functions *after* sourcing so they override any
///     same-named user alias.
enum ShellColor {

    /// Environment that turns on color for common tools (safe, non-intrusive).
    static let colorEnv: [String: String] = [
        "CLICOLOR": "1",
        "CLICOLOR_FORCE": "1",
        "LSCOLORS": "GxFxCxDxBxegedabagacad",
        "LS_COLORS": "di=1;36:ln=1;35:so=1;32:pi=33:ex=1;32:bd=34;46:cd=34;43:ln=1;35:tw=1;34:ow=1;34",
        "GREP_COLOR": "1;32",
    ]

    /// Create (once per spawn) a ZDOTDIR whose rc files source the user's config,
    /// then emit OSC 7 for CWD tracking and define `shortcuts`.
    /// Returns the directory path, or nil on failure.
    static func makeZDotDir(shortcuts: [ScriptShortcut] = [], envVars: [EnvVar] = []) -> String? {
        let dir = shellSupportDir()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try zshenv.write(to: dir.appendingPathComponent(".zshenv"), atomically: true, encoding: .utf8)
            try zprofile.write(to: dir.appendingPathComponent(".zprofile"), atomically: true, encoding: .utf8)
            try zshrc(shortcuts: shortcuts, envVars: envVars)
                .write(to: dir.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
            return dir.path
        } catch { return nil }
    }

    /// Create (once per spawn) a bash rcfile that sources ~/.bashrc, then emits
    /// OSC 7 for CWD tracking and defines `shortcuts`.
    /// Returned path is passed via `bash --rcfile <path> -i`.
    static func makeBashRC(shortcuts: [ScriptShortcut] = [], envVars: [EnvVar] = []) -> String? {
        let dir = shellSupportDir()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let rc = dir.appendingPathComponent("bashrc")
            try bashrc(shortcuts: shortcuts, envVars: envVars)
                .write(to: rc, atomically: true, encoding: .utf8)
            return rc.path
        } catch { return nil }
    }

    private static func shellSupportDir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return (base ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("zTerminal/shell", isDirectory: true)
    }

    // MARK: - zsh

    private static let zshenv = #"[ -f "$HOME/.zshenv" ] && source "$HOME/.zshenv"\#n"#
    private static let zprofile = #"[ -f "$HOME/.zprofile" ] && source "$HOME/.zprofile"\#n"#

    private static func zshrc(shortcuts: [ScriptShortcut], envVars: [EnvVar] = []) -> String {
        var s = """
        # zTerminal shell integration — sources your real config first.
        [ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc"

        # Emit OSC 7 so zTerminal tracks the current directory reliably.
        autoload -Uz add-zsh-hook 2>/dev/null
        _zt_osc7() { printf '\\033]7;file://%s%s\\033\\\\' "${HOST}" "${PWD}" }
        add-zsh-hook chpwd _zt_osc7 2>/dev/null
        _zt_osc7

        # Command lifecycle markers (OSC 133) — power the exit code + duration badge.
        _zt_c() { printf '\\033]133;C\\033\\\\' }
        _zt_d() { printf '\\033]133;D;%s\\033\\\\' "$?" }
        add-zsh-hook preexec _zt_c 2>/dev/null
        add-zsh-hook precmd _zt_d 2>/dev/null

        # Vibrant prompt — only when you haven't set your own (respects p10k/starship/etc).
        if [[ -n "$ZT_COLORFUL" ]] && [[ "$PROMPT" == '%m%# ' || "$PROMPT" == '%# ' || "$PROMPT" == '%n@%m %1~ %# ' || -z "$PROMPT" ]]; then
          setopt prompt_subst 2>/dev/null
          _zt_git() { local b; b=$(command git symbolic-ref --short HEAD 2>/dev/null) || return; print -n " %F{141}${b}%f" }
          PROMPT='%F{42}❯%f %F{45}%1~%f$(_zt_git) %f'
        fi

        """
        // Env vars + shortcuts last, so they win over any same-named export/alias
        // from the rc sourced above.
        s += EnvVar.shellBlock(for: envVars)
        s += ScriptShortcut.shellBlock(for: shortcuts)
        return s
    }

    // MARK: - bash

    // Raw string (no Swift escaping) — backslashes are literal for the shell.
    // OSC 7 tracks the CWD; OSC 133 C/D (DEBUG trap + PROMPT_COMMAND, capturing
    // $? first) power the exit code + duration badge. The `__zt_armed` flag emits
    // exactly one C per command line, ignoring our own internal commands.
    private static let bashIntegration = ##"""
    __zt_armed=0
    __zt_preexec() {
      case "$BASH_COMMAND" in __zt_*) return;; esac
      [ "$__zt_armed" = 1 ] || return
      __zt_armed=0
      printf '\033]133;C\033\\'
    }
    trap '__zt_preexec' DEBUG
    PROMPT_COMMAND='__zt_ec=$?; printf "\033]7;file://%s%s\033\\" "$HOSTNAME" "$PWD"; printf "\033]133;D;%s\033\\" "$__zt_ec"; __zt_armed=1'
    """##

    private static func bashrc(shortcuts: [ScriptShortcut], envVars: [EnvVar] = []) -> String {
        var s = "[ -f \"$HOME/.bashrc\" ] && source \"$HOME/.bashrc\"\n"
        s += bashIntegration + "\n"
        // Env vars + shortcuts last, so they win over any same-named export/alias
        // from the rc sourced above.
        s += EnvVar.shellBlock(for: envVars)
        s += ScriptShortcut.shellBlock(for: shortcuts)
        return s
    }
}
