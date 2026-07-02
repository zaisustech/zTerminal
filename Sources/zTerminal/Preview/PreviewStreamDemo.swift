import Foundation

/// Manual verification harness for flicker-free token streaming (Help menu):
/// opens a preview tab backed by a StreamPreviewSource and feeds it a fixture
/// in small chunks at ~120 tokens/sec, exercising per-frame coalescing, the
/// open-fence heuristic, live TOC updates, and bottom auto-follow.
enum PreviewStreamDemo {

    static func run(in model: WindowModel) {
        let source = StreamPreviewSource(title: "Streaming Demo")
        let pane = PreviewPaneModel(source: source)
        model.openPreviewTab(PreviewPanelModel(doc: pane))

        let text = demoMarkdown
        var index = text.startIndex
        Timer.scheduledTimer(withTimeInterval: 1.0 / 40.0, repeats: true) { timer in
            guard index < text.endIndex else { timer.invalidate(); return }
            // 2–8 characters per tick — token-ish chunk sizes.
            let step = Int.random(in: 2...8)
            let end = text.index(index, offsetBy: step, limitedBy: text.endIndex) ?? text.endIndex
            source.append(String(text[index..<end]))
            index = end
        }
    }

    static let demoMarkdown = """
    # Streaming Markdown Demo

    This document arrives **token by token**, exactly like AI assistant output. \
    Earlier blocks must never flash or shift while new content grows below.

    ## Authentication

    The API uses bearer tokens. Every request includes an `Authorization` header.

    > Note
    > Tokens expire after 24 hours. Refresh them with the `/auth/refresh` endpoint.

    ```typescript title=auth.ts
    export async function login(user: string, secret: string): Promise<Token> {
      const res = await fetch("/auth/login", {
        method: "POST",
        body: JSON.stringify({ user, secret }),
      })
      if (!res.ok) throw new Error(`login failed: ${res.status}`)
      return res.json()
    }
    ```

    ## Endpoints

    | Method | Path | Description |
    | ------ | ---- | ----------- |
    | GET | /users | List users |
    | POST | /users | Create a user |
    | DELETE | /users/:id | Remove a user |

    ## Flow

    ```mermaid
    graph TD
      A[Client] -->|login| B(Auth service)
      B --> C{Valid?}
      C -->|yes| D[Issue token]
      C -->|no| E[401]
    ```

    ## Checklist

    - [x] Streaming renders incrementally
    - [x] Open code fences display as live blocks
    - [ ] You watched the whole demo :tada:

    > Tip
    > Scroll up mid-stream — the viewport must stay put; scroll back to the
    > bottom and auto-follow resumes.

    The math holds: $E = mc^2$, and in display form:

    $$
    \\int_0^\\infty e^{-x^2}\\,dx = \\frac{\\sqrt{\\pi}}{2}
    $$

    ## Done

    That's the demo. ⌘F to search it, click the TOC to jump around, export it
    from the share menu.
    """
}
