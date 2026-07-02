# zTerminal — User Guide & Help

A fast, native macOS terminal that stays out of your way and knows about your
projects. This guide covers everything you can do as a user. (For building from
source, see [`README.md`](README.md).)

> **New here?** Jump to [Getting Started](#getting-started), then skim the
> [Keyboard Shortcuts](#keyboard-shortcuts) and [Inline Autosuggestions](#inline-autosuggestions).

---

## Contents

1. [What zTerminal is](#what-zterminal-is)
2. [Requirements & Prerequisites](#requirements--prerequisites)
3. [Getting Started](#getting-started)
4. [The Window at a Glance](#the-window-at-a-glance)
5. [Tabs](#tabs)
6. [Keyboard Shortcuts](#keyboard-shortcuts)
7. [Inline Autosuggestions](#inline-autosuggestions) ← *complete `bun`/`npm`/`pnpm`/`yarn` scripts as you type*
8. [Running Project Tasks](#running-project-tasks)
9. [Project Bookmarks (`.zTerminal.json`)](#project-bookmarks-zterminaljson)
10. [Script Shortcuts](#script-shortcuts)
11. [Environment Variables](#environment-variables)
12. [Selecting, Copying & Quick Look](#selecting-copying--quick-look)
13. [Find in Terminal](#find-in-terminal)
14. [Keep Awake](#keep-awake)
15. [Notifications & Attention](#notifications--attention)
16. [Themes & Appearance](#themes--appearance)
17. [Finder Integration](#finder-integration)
18. [Open at a Path (`zterminal://`)](#open-at-a-path-zterminal)
19. [Settings Reference](#settings-reference)
20. [Accurate Directory Tracking (shell hook)](#accurate-directory-tracking-shell-hook)
21. [Troubleshooting & FAQ](#troubleshooting--faq)
22. [Getting Help](#getting-help)

---

## What zTerminal is

zTerminal is a real terminal emulator (VT100/xterm) — it runs your login shell
(zsh or bash) exactly like Terminal.app or iTerm2, with truecolor, your fonts,
and your dotfiles. On top of that it adds project awareness: a status bar that
tracks your current folder and git branch, one-click buttons to run your
project's scripts, and inline suggestions that complete package-manager commands
as you type.

Your shell config is **never modified** — zTerminal sources your real `~/.zshrc`
/ `~/.bashrc` first and layers its integration on top.

---

## Requirements & Prerequisites

**To run zTerminal itself:**

- **macOS 13 (Ventura) or later.** That's the only hard requirement. The app
  bundles its terminal engine and runs the shell you already have — **nothing else
  needs to be installed** just to launch it and use it as a terminal.
- A shell: **zsh** (macOS default) or **bash** — both already ship with macOS.

**For the project-aware features:** zTerminal *reads* your project files (e.g.
`package.json`, lockfiles, a `Makefile`) with nothing installed — so inline
suggestions and the task list **appear regardless**. But to actually **run** a
completed command or a task, the underlying tool must be installed and on your
`PATH`. You install these however you normally would — Homebrew, official
installers, or a version manager (nvm, fnm, asdf). zTerminal never bundles or
manages them; if a tool is missing, your shell simply reports `command not found`.

| Feature / ecosystem | Needs installed | Notes |
|---|---|---|
| Inline suggestions (showing the ghost) | *nothing* | reads `package.json` + lockfile only |
| Run **Node** scripts | **Node.js** | provides `npm`; e.g. via Homebrew or nvm |
| Run **Bun** scripts | **Bun** | `curl -fsSL https://bun.sh/install \| bash` |
| Run **pnpm** / **Yarn** scripts | **pnpm** / **Yarn** | often via `corepack enable` |
| Git branch & status bar | **git** | comes with Xcode Command Line Tools: `xcode-select --install` |
| Rust tasks | **Rust** (`cargo`) | rustup |
| Go tasks | **Go** | |
| Python tasks | **Python 3** (+ `pytest` for tests) | |
| Java tasks | **JDK** + Maven/Gradle | or use the project's `./mvnw` / `./gradlew` |
| .NET tasks | **.NET SDK** | |
| Deno tasks | **Deno** | |
| Ruby tasks | **Ruby** + Bundler / Rake | |
| Make targets | **make** | comes with Xcode Command Line Tools |

> **Tip:** the fastest way to get `git`, `make`, and other Unix build tools is
> `xcode-select --install` (Apple's Command Line Tools). Language runtimes
> (Node, Bun, Go, …) are separate installs, only needed for the ecosystems you use.

**Building zTerminal from source?** That has its own developer prerequisites
(Xcode 15+, Swift 5.9+, XcodeGen) — see [`README.md`](README.md). End users
running the packaged `.app` don't need any of those.

---

## Getting Started

1. **Launch** zTerminal. A new window opens with one tab at your home folder,
   running your login shell.
2. **Use it like any terminal** — run commands, pipe, edit files, run `vim`,
   `top`, etc.
3. *(Recommended)* Add the shell hook for pinpoint folder tracking — see
   [Accurate Directory Tracking](#accurate-directory-tracking-shell-hook). Most
   things work without it, but the folder/git status bar is more reliable with it.
4. *(Optional)* Enable the Finder extension to right-click a folder →
   **Open in zTerminal**. See [Finder Integration](#finder-integration).

---

## The Window at a Glance

```
┌───────────────────────────────────────────────┐
│  ⌘  tab 1   tab 2   +                          │  ← tab bar (⌘T for a new tab)
├───────────────────────────────────────────────┤
│                                                 │
│  your shell / terminal output                   │  ← the terminal
│  ❯ bun run dev                                  │
│                                                 │
├───────────────────────────────────────────────┤
│  📁 ~/proj   ⎇ main●   ▶   ⬢ node   ✓ 0.4s  12m│  ← bottom toolbar
└───────────────────────────────────────────────┘
```

### Bottom toolbar items

Every item is **individually toggleable** — open **Settings → Appearance →
Toolbar Items**, or **right-click the toolbar** to show/hide items in place.

| Item | Meaning |
|---|---|
| **Folder path** | The shell's current working directory (click behavior below). |
| **Reveal in Finder** | Opens the current folder in Finder (local folders only). |
| **Git branch / status** | Current branch and a dirty indicator when there are changes. |
| **Runtime badges** | Detected runtimes for the folder (e.g. Node, Python). |
| **Run / Play button** ▶ | Appears when a build manifest is detected — runs project tasks. See [Running Project Tasks](#running-project-tasks). |
| **Bookmark button** | Always present — your per-project saved commands. See [Project Bookmarks](#project-bookmarks-zterminaljson). |
| **Command status** | Exit code + duration of the last command that finished. |
| **Session timer** | How long this tab's session has been open. |

---

## Tabs

- **New tab:** `⌘T` — opens in the **same folder** as the current tab.
- **Close tab:** `⌘W`.
- **Switch tabs:** `⌘1`…`⌘9` jump to tab 1–9.
- **Rename a tab:** double-click its title; clear the name to revert to the
  automatic (folder/program) title.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘T` | New tab (inherits current folder) |
| `⌘W` | Close tab |
| `⌘1`–`⌘9` | Select tab 1–9 |
| `⌘K` | Clear the screen and scrollback |
| `⌘F` | Find in terminal |
| `⌘=` | Zoom in (larger font) |
| `⌘-` | Zoom out (smaller font) |
| `⌘0` | Actual size (reset font) |
| `⌘Y` | Quick Look the selected file path |
| `⌘⇧U` | Cycle **Keep Awake**: Off → While Busy → Always |
| `⌘,` | Open Settings |
| `⌘C` / `⌘V` | Copy / paste (text is also copied automatically on selection) |
| `⌘A` | Select all |
| **`Tab`** | **Accept an inline suggestion** when one is shown; otherwise your shell's normal completion runs unchanged |

> `⌥` (Option) is sent as **Meta**, so readline/agent keybindings like `⌥←`/`⌥→`
> work. Hold `⌥` and drag to select text even inside mouse-reporting programs.

---

## Inline Autosuggestions

As you type at an **idle prompt**, zTerminal shows a **dim "ghost" suffix** after
the cursor completing your project's package-manager scripts. Press **`Tab`** to
accept it.

**How it works**

- It reads the scripts from the `package.json` in your **current folder**.
- It detects your package manager from the **lockfile** (or the `packageManager`
  field) and only completes the matching command:

| Your project has… | Completes | Also completes (bare) |
|---|---|---|
| `bun.lockb` / `bun.lock` | `bun run <script>` | `bun <script>` |
| `pnpm-lock.yaml` | `pnpm run <script>` | `pnpm <script>` |
| `yarn.lock` | `yarn run <script>` | `yarn <script>` |
| `package-lock.json` | `npm run <script>` | *(npm needs `run`)* |

**Example** — in a Bun project with a `dev` script:

```
❯ bun run d█ev        ← "ev" is the dim ghost; press Tab to fill it
```

**Details & behavior**

- **Empty input after `run `** suggests a likely script first (`dev`, `start`, …).
- **Tab does the right thing:** if a ghost is visible, Tab completes it; if not,
  Tab falls through to your shell's own completion — you never lose native
  completion.
- **It stays out of the way:** no suggestion while a command is running, inside a
  full-screen program (e.g. `vim`), or when it can't tell where your input begins.
- **It's a visual hint only** — nothing is sent to your shell until you press Tab.
- **The lockfile gates it:** in a `yarn.lock` project, typing `bun run …` shows
  nothing (bun isn't your manager here).

> **Not seeing suggestions?** It needs the prompt-end marker from zTerminal's
> shell integration. Some prompt frameworks (powerlevel10k, starship, some
> oh-my-zsh themes) rebuild the prompt on every keystroke and drop that marker —
> in which case suggestions quietly stay off. See
> [Troubleshooting](#troubleshooting--faq).

---

## Running Project Tasks

When zTerminal detects a build manifest in the current folder, a **▶ Play button**
appears in the toolbar. Click it to see the tasks it found and run one. Detected
ecosystems include:

- **Node / Bun / pnpm / Yarn** — scripts from `package.json` (run with your
  detected package manager)
- **Rust** — `cargo run/build/test/check/clippy/fmt`
- **Go** — `go run/build/test/vet`
- **Python** — `pytest`, `pip install`, Django `manage.py` tasks
- **Java** — Maven (`mvn`/`./mvnw`) and Gradle (`gradle`/`./gradlew`)
- **.NET** — `dotnet run/build/test/restore`
- **Deno** — tasks from `deno.json`, plus `deno test`
- **Ruby** — Rake tasks and `bundle install`
- **Make** — targets parsed from your `Makefile`

A task runs in the **current tab** when it's idle, or in a **new tab** when the
tab is busy (or when you ⌘-click it).

---

## Project Bookmarks (`.zTerminal.json`)

Drop a `.zTerminal.json` file in a project folder to give it **bookmarks** —
your favorite shell commands, each with an icon and color. When a tab is in that
folder, open the **bookmark button** in the toolbar to run them.

You can **add, edit, and delete** bookmarks right from the popover (hover a row
for edit/delete); every change is written back to the file. The bookmark button
is always available, so you can add your first bookmark even in a folder that has
no `.zTerminal.json` yet (the file is created when you save).

```json
{
  "bookmarks": [
    { "name": "Start",         "command": "bun run dev",                  "icon": "play.fill",  "color": "#10B981" },
    { "name": "Clean install", "command": "rm -rf node_modules && bun i", "icon": "trash.fill", "color": "#FB7185" },
    { "name": "Test filter",   "command": "bun test --filter <pattern>",  "icon": "line.3.horizontal.decrease.circle" }
  ]
}
```

- `icon` is any **SF Symbol** name; `color` is a hex tint (defaults to the app accent).
- A command may take **run-time arguments** with `<label>` placeholders — running
  `bun test --filter <pattern>` prompts you for `pattern`, then runs the filled-in
  command. A command with no `<…>` runs immediately.
- `.zTerminal.json` can also carry a **per-project theme** — see [Themes](#themes--appearance).

---

## Script Shortcuts

Define short **global** command aliases in **Settings → Scripts**. Type the
shortcut's name at any prompt and it runs the mapped command (extra arguments are
passed through).

- Example: name `zaisus` → command `bun run start`. Type `zaisus` and it runs
  `bun run start`. Type `zaisus --watch` and the extra flag is forwarded.
- These are installed as shell functions in every new tab, **after** your dotfiles
  load, so they override same-named aliases.
- zTerminal warns you if a name would shadow an existing command on your `PATH`.

---

## Environment Variables

Set variables in **Settings → Environment**. They're exported into **new** tabs
**after** your `~/.zshrc` is sourced, so they take precedence over values set in
your dotfiles. Toggle each variable on/off without deleting it.

- Example: `NODE_ENV` = `development`. Open a new tab and `echo $NODE_ENV`.

---

## Selecting, Copying & Quick Look

- **Copy on select:** selecting text copies it automatically; `⌘C` also works.
- **Paste:** `⌘V`, or right-click → Paste.
- **Select over full-screen programs:** hold **`⌥` (Option)** and drag to select
  text even when a program (like `tmux` or `htop`) is capturing the mouse.
- **Quick Look a file:** select a file path and press `⌘Y` (or right-click →
  Quick Look). Relative paths resolve against the current folder; `~` expands.
- **Drag & drop:** drop files from Finder to insert their (shell-escaped) paths.
  Hold **`⌘`** while dropping a **folder** to open it in a new tab instead.

---

## Find in Terminal

Press `⌘F` to open the find bar and search the visible buffer and scrollback.
Matches are highlighted; searching is per-tab, so each tab keeps its own query.

---

## Keep Awake

Prevent your Mac from sleeping while you work. Cycle the mode with `⌘⇧U` or set it
in **Settings → Terminal**:

- **Off** — normal system sleep behavior.
- **While Busy** — stay awake only while a command is running (great for long
  builds/tests).
- **Always** — stay awake as long as the app is open.

---

## Notifications & Attention

When a background (unfocused) tab's program **rings the bell**, zTerminal posts a
macOS notification and adds a **badge to the Dock icon** with the count of tabs
wanting attention. The badge clears when you return to that tab.

- The first time, macOS asks permission to show notifications — allow it if you
  want completion alerts.

---

## Themes & Appearance

Open **Settings → Appearance** to style the terminal:

- **Theme mode** — including a **Liquid Glass** look and a translucent **Blur**
  mode that lets your desktop show through.
- **Gradient presets** and a **custom gradient** for the accent.
- **Terminal color scheme**, **glass opacity**, **blur intensity**, **corner
  radius**, and **window transparency**.
- **Hide title bar** for a cleaner, frameless window.
- **Toolbar Items** — show/hide each bottom-bar element.

### Per-project themes & the cascade

A `.zTerminal.json` can include a `theme` block that applies only while a tab is
in that folder. Themes resolve by layering, in increasing priority:

1. your **Settings** (base),
2. a **global** `~/.zTerminal.json` `theme` (your default everywhere),
3. a **project** `<folder>/.zTerminal.json` `theme` (wins in that folder).

A project theme only needs the fields it wants to change; everything else falls
through. `cd` out of the folder and the global/Settings theme applies again.
Your saved Settings are never overwritten.

```json
{
  "theme": {
    "mode": "glass",
    "accentHex": "#38BDF8",
    "terminalScheme": "liquidGlass",
    "terminalBackgroundHex": "#0A0F1A"
  }
}
```

---

## Finder Integration

After launching the app once, enable the extension in **System Settings →
General → Login Items & Extensions → Finder Extensions → zTerminal**. Then
right-click a folder (or a Finder window's background) and choose **Open in
zTerminal** to launch the app there.

---

## Open at a Path (`zterminal://`)

zTerminal registers a URL scheme so other tools (and the Finder extension) can
open it at a specific folder:

```
zterminal://open?path=/Users/you/projects/app
```

Opening this URL launches zTerminal (or focuses it) and opens a new tab at that
path. Paths are validated before use.

---

## Settings Reference

Open with `⌘,`. Four tabs:

| Tab | What's there |
|---|---|
| **Appearance** | Theme mode, gradient presets, custom gradient, terminal color scheme, hide title bar, glass opacity, blur intensity, corner radius, window transparency, and per-item toolbar toggles. |
| **Terminal** | Shell (**zsh**/**bash**), **Keep Awake** mode, terminal **font family**, and **font size**. |
| **Scripts** | Add / edit / delete your global [script shortcuts](#script-shortcuts). |
| **Environment** | Add / edit / toggle [environment variables](#environment-variables). |

---

## Accurate Directory Tracking (shell hook)

zTerminal follows your current folder using an **OSC 7** escape sequence. Its
built-in integration already emits this, but if you use a heavily customized
prompt and notice the folder/git status not updating, add one of these hooks to
your dotfiles:

**zsh** (`~/.zshrc`):

```zsh
autoload -Uz add-zsh-hook
_zterm_osc7() { printf '\033]7;file://%s%s\033\\' "$HOST" "$PWD" }
add-zsh-hook chpwd _zterm_osc7; _zterm_osc7
```

**bash** (`~/.bashrc`):

```bash
_zterm_osc7() { printf '\033]7;file://%s%s\033\\' "$HOSTNAME" "$PWD"; }
PROMPT_COMMAND="_zterm_osc7${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
```

Without a hook, zTerminal falls back to reading the foreground process's working
directory.

---

## Troubleshooting & FAQ

**Inline suggestions don't appear.**
The feature needs zTerminal's prompt-end marker, which is added to your prompt
after your dotfiles load. Some prompt frameworks (**powerlevel10k**, **starship**,
certain oh-my-zsh themes) rebuild the prompt on every render and drop it, so
suggestions stay off — this is by design (it never breaks your prompt). Other
things to check:
- You're in a folder with a `package.json` that has a `scripts` block.
- You typed a command word matching your **lockfile's** manager (e.g. `yarn …`
  in a `yarn.lock` project). Remember **npm needs `run`** (`npm run dev`, not
  `npm dev`).
- The shell is idle at the prompt (not mid-command) and you're not in a
  full-screen program.

**`Tab` isn't completing my suggestion.**
Tab only accepts when a ghost is actually visible and the shell is idle. If no
ghost is shown, Tab intentionally passes through to your shell's normal completion.

**The folder / git branch in the status bar looks stale.**
Add the [OSC 7 shell hook](#accurate-directory-tracking-shell-hook).

**My prompt / colors look different from my usual terminal.**
zTerminal sources your real dotfiles and keeps your prompt. The vibrant built-in
prompt is only used when you haven't set your own. Colors for `ls`/`grep`/`git`
are enabled in the Liquid Glass scheme.

**"Open in zTerminal" isn't in the Finder menu.**
Enable the extension in **System Settings → General → Login Items & Extensions →
Finder Extensions**, then relaunch Finder if needed.

**Text selection doesn't work while a program is running.**
Hold **`⌥` (Option)** and drag — that temporarily bypasses the program's mouse
capture so you can select.

---

## Getting Help

- **Help menu → "Welcome to zTerminal"** opens the in-app welcome screen.
- This guide lives at `USER_GUIDE.md`; build and packaging instructions are in
  [`README.md`](README.md).

---

*zTerminal — a native macOS terminal that knows your projects.*
