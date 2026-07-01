# zTerminal — Manual Verification Checklist

The 17 remaining `bootstrap-terminal-app` tasks are visual/interactive checks that
must be done on a real display. Work through these, tick each box, and tell me any
that fail — I'll fix, then mark them in `openspec/changes/bootstrap-terminal-app/tasks.md`
and archive the change.

**Build & launch the full app (with Finder extension):**

```bash
cd ~/Desktop/terminal-app
xcodegen generate
xcodebuild -project zTerminal.xcodeproj -scheme zTerminal -configuration Debug -derivedDataPath build/dd build
open build/dd/Build/Products/Debug/zTerminal.app
```

On first launch: **allow the notification prompt**.

---

## Terminal core

- [ ] **2.5 Bidirectional I/O** — type `ls`, press Return (output appears). Run `vim` → it renders full-screen and responds; `:q` restores the previous screen. Run `top` → live updates; `q` exits cleanly.
- [ ] **2.6 Resize** — drag the window edge, then run `stty size` → rows/cols match the new size (and `vim`/`top` reflow while open).
- [ ] **2.7 Copy / paste** — select text with the mouse, **⌘C**; **⌘V** pastes it back at the prompt. (Also verify **copy-on-select** already put the selection on the clipboard.)
- [ ] **2.9 Scrollback + clean teardown** — `seq 1 500`, scroll up to see history. Type `exit` → tab shows **"[process completed]"**; **Restart** respawns in the same dir. Quit the app → no leftover `zsh`/`bash` in Activity Monitor.

## Appearance & color

- [ ] **3.2 Truecolor** — `printf '\e[38;2;255;100;0mORANGE\e[0m\n'` shows exact orange. `echo $COLORTERM` prints `truecolor`.
- [ ] **3.3 Attributes & diffs** — `git diff --color` (in any repo) shows red/green; `printf '\e[1mbold\e[0m \e[3mitalic\e[0m \e[4munderline\e[0m\n'`. If installed: `bat somefile`.
- [ ] **3.4 Glyphs / emoji / wide** — a powerline prompt (or `echo '  ✅ 🚀 你好'`) → Nerd icons + **color emoji** + CJK all render at correct width, no clipping.

## TUI agent compatibility

- [ ] **3b.1 Alternate screen** — open `vim`/`less`, then quit → prior scrollback is intact.
- [ ] **3b.2 Mouse / bracketed paste / focus / links** — in `vim` with mouse mode, clicks position the cursor; paste multi-line text into a prompt and confirm it's not executed line-by-line; ⌘-hover a URL if OSC 8.
- [ ] **3b.3 Scroll in alt-screen** — inside `less`/`vim`, the mouse wheel scrolls the *program*, not the terminal scrollback.
- [ ] **3b.4 Claude Code** — run `claude`: colors correct, typing works, **Option+Return** inserts a newline, streaming output renders, resizing reflows, screen restores on exit. **Bell test:** trigger a confirmation prompt while focused on another app/tab → you get a **notification + Dock badge**; returning clears the badge.
- [ ] **3b.5 Another agent** — run one of `codex` / `opencode` / `aider` → full-screen UI, colors, spinners render cleanly; restores on exit.

## Tabs & Finder

- [ ] **5.6 Per-tab independence** — open two tabs in the **same** folder (⌘T); run a long command in one → the other keeps its own prompt, CWD, start time, and timer.
- [ ] **6.5 Finder entries** — enable the extension: **System Settings → General → Login Items & Extensions → Finder Extensions → zTerminal**. Then (a) right-click a **selected folder** → Services → *Open in zTerminal*; (b) right-click a Finder **window background** → *Open in zTerminal*. Both open a tab at that folder.
- [ ] **6.6 Graceful degradation** — with the Finder Sync extension **disabled**, the Services entry (selected folder) still works.
- [ ] **6.7 Path safety** — a folder with **spaces/unicode** opens in the correct dir; `open "zterminal://open?path=/no/such/dir"` from another terminal is ignored (no shell spawned).

## Full pass

- [ ] **8.1 End-to-end** — launch seeds the toolbar CWD immediately; `cd` updates it; folder icon reveals in Finder (and is **disabled over SSH**); timer runs per tab; tabs open/switch/close/reorder/rename; shell-exit + restart; right-click opens at folder; truecolor + emoji + agents all clean.

---

**When done:** reply with anything that failed (I'll fix it), or "all pass" and I'll mark these tasks and run `openspec archive bootstrap-terminal-app`.
