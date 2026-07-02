// markdown-it pipeline: GFM + task lists, footnotes, emoji, anchors, KaTeX,
// plus the custom callout and fence-attribute plugins. Produces the HTML that
// the block differ keys on, so everything visual must be decided here (or in
// CSS) — post-render DOM mutation would break hash stability.
import MarkdownIt from 'markdown-it'
import taskLists from 'markdown-it-task-lists'
import footnote from 'markdown-it-footnote'
import { full as emoji } from 'markdown-it-emoji'
import anchor from 'markdown-it-anchor'
import katexPkg from '@vscode/markdown-it-katex'
import hljs from 'highlight.js'
import DOMPurify from 'dompurify'

// CJS package that ships `{ default: plugin }` without an __esModule marker,
// so esbuild's interop can't unwrap it.
const katexPlugin = katexPkg.default ?? katexPkg

const CALLOUTS = {
  note:      { title: 'Note' },
  tip:       { title: 'Tip' },
  warning:   { title: 'Warning' },
  danger:    { title: 'Danger' },
  caution:   { title: 'Danger' },   // GitHub [!CAUTION]
  important: { title: 'Note' },     // GitHub [!IMPORTANT]
}

// GitHub alert syntax `[!NOTE]` or a bare `Note` / `Warning:` first line.
const ALERT_RE = /^\[!(NOTE|TIP|WARNING|DANGER|CAUTION|IMPORTANT)\]\s*/i
const WORD_RE = /^(Note|Tip|Warning|Danger)(:[ \t]*|[ \t]*(?:\n|$))/

// Blockquotes that start with a callout marker become styled callout cards.
// Runs on the token stream: tags the blockquote, injects a title row, and
// strips the marker text from the first inline token.
function calloutPlugin(md) {
  md.core.ruler.after('block', 'callouts', (state) => {
    const tokens = state.tokens
    for (let i = 0; i < tokens.length; i++) {
      if (tokens[i].type !== 'blockquote_open') continue
      // First inline token inside this blockquote.
      let j = i + 1
      while (j < tokens.length && tokens[j].type !== 'inline' &&
             tokens[j].type !== 'blockquote_close') j++
      if (j >= tokens.length || tokens[j].type !== 'inline') continue
      const inline = tokens[j]
      const text = inline.content
      let kind = null, strip = 0
      const alert = ALERT_RE.exec(text)
      if (alert) { kind = alert[1].toLowerCase(); strip = alert[0].length }
      else {
        const word = WORD_RE.exec(text)
        if (word) { kind = word[1].toLowerCase(); strip = word[0].length }
      }
      if (!kind || !CALLOUTS[kind]) continue
      const info = CALLOUTS[kind]
      const cls = info.title.toLowerCase()
      tokens[i].attrJoin('class', `callout callout-${cls}`)
      // Remove the marker from the inline children.
      stripMarker(inline, strip)
      // Title row as a raw token right after blockquote_open.
      const title = new state.Token('html_block', '', 0)
      title.content = `<p class="callout-title"><span class="callout-icon"></span>${info.title}</p>\n`
      tokens.splice(i + 1, 0, title)
    }
  })
}

function stripMarker(inline, count) {
  let remaining = count
  const kids = inline.children || []
  while (remaining > 0 && kids.length) {
    const t = kids[0]
    if (t.type === 'text') {
      if (t.content.length > remaining) { t.content = t.content.slice(remaining); break }
      remaining -= t.content.length
      kids.shift()
    } else if (t.type === 'softbreak' || t.type === 'hardbreak') {
      kids.shift(); break
    } else break
  }
  // Drop a leading break left behind (marker was alone on its line).
  if (kids.length && (kids[0].type === 'softbreak' || kids[0].type === 'hardbreak')) kids.shift()
  inline.content = inline.content.slice(count)
}

// ```ts title=app.ts / filename="app.ts" — parsed off the fence info string.
export function parseFenceInfo(info) {
  const parts = (info || '').trim().split(/\s+/)
  const lang = (parts[0] || '').toLowerCase()
  let filename = null
  for (const p of parts.slice(1)) {
    const m = /^(?:title|filename)=(?:"([^"]*)"|(\S+))$/.exec(p)
    if (m) filename = m[1] ?? m[2]
  }
  return { lang, filename }
}

const escapeHtml = (s) => s.replace(/[&<>"]/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]))

function highlightCode(code, lang) {
  if (lang && hljs.getLanguage(lang)) {
    try { return hljs.highlight(code, { language: lang, ignoreIllegals: true }).value }
    catch { /* fall through to plain */ }
  }
  return escapeHtml(code)
}

// Full code-block chrome: header (language badge, filename, actions) + numbered
// lines. Buttons are wired by delegated listeners in enhance.js.
function renderCodeBlock(code, infoString) {
  const { lang, filename } = parseFenceInfo(infoString)
  if (lang === 'mermaid') {
    return `<div class="mermaid-block" data-mermaid="${escapeHtml(encodeURIComponent(code))}">` +
           `<div class="mermaid-target" aria-label="Mermaid diagram"></div></div>\n`
  }
  const body = code.replace(/\n$/, '')
  const highlighted = highlightCode(body, lang)
  const lines = highlighted.split('\n')
  const rows = lines.map((l) => `<span class="cl">${l || '​'}</span>`).join('\n')
  const label = lang || 'text'
  return (
    `<figure class="code-block${filename ? ' has-filename' : ''}" data-lang="${escapeHtml(label)}">` +
    `<figcaption class="code-header">` +
      (filename ? `<span class="code-filename">${escapeHtml(filename)}</span>` : '') +
      `<span class="code-lang">${escapeHtml(label)}</span>` +
      `<button type="button" class="code-btn code-wrap" title="Toggle word wrap" aria-label="Toggle word wrap"></button>` +
      `<button type="button" class="code-btn code-copy" title="Copy code" aria-label="Copy code"></button>` +
    `</figcaption>` +
    `<pre class="code-body"><code class="hljs">${rows}</code></pre>` +
    `</figure>\n`
  )
}

function slugify(s) {
  return String(s).trim().toLowerCase()
    .replace(/[^\p{L}\p{N}\s-]/gu, '')
    .replace(/\s+/g, '-') || 'section'
}

/**
 * Build a configured markdown-it instance.
 * @param {{ html?: boolean }} opts — html enables sanitized raw-HTML rendering.
 */
export function createMarkdown({ html = false } = {}) {
  const md = new MarkdownIt({
    html,
    linkify: true,
    typographer: true,
    highlight: (code, lang) => highlightCode(code, lang),
  })
  md.use(taskLists, { label: true })
  md.use(footnote)
  md.use(emoji)
  md.use(anchor, { slugify, tabIndex: false })
  md.use(katexPlugin, { throwOnError: false })
  md.use(calloutPlugin)

  // Rich code blocks (chrome + line numbers) replace the default fence.
  md.renderer.rules.fence = (tokens, idx) =>
    renderCodeBlock(tokens[idx].content, tokens[idx].info)
  md.renderer.rules.code_block = (tokens, idx) =>
    renderCodeBlock(tokens[idx].content, '')

  // Local images route through the zt-asset:// scheme (Swift enforces that
  // only files under the document directory are served).
  const defaultImage = md.renderer.rules.image
  md.renderer.rules.image = (tokens, idx, options, env, self) => {
    const src = tokens[idx].attrGet('src') || ''
    if (!/^(https?|data|zt-asset|blob):/i.test(src)) {
      tokens[idx].attrSet('src', 'zt-asset://doc/' + encodeURI(src.replace(/^\.\//, '')))
    }
    return defaultImage
      ? defaultImage(tokens, idx, options, env, self)
      : self.renderToken(tokens, idx, options)
  }

  return md
}

/** Render markdown to (sanitized when html is on) HTML. */
export function renderMarkdown(md, source, { html = false } = {}) {
  const out = md.render(source)
  if (!html) return out
  return DOMPurify.sanitize(out, {
    ADD_TAGS: ['figure', 'figcaption'],
    ADD_ATTR: ['data-lang', 'data-mermaid'],
    ALLOW_UNKNOWN_PROTOCOLS: false,
    ALLOWED_URI_REGEXP: /^(?:https?|mailto|data|zt-asset|#)/i,
  })
}
