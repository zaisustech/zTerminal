// Entry point: owns the render loop and exposes the `window.preview` API the
// Swift host drives (setContent / setTheme / setHTMLEnabled / find /
// exportHTML / getSource). Updates are coalesced to one render per frame; the
// block differ keeps unchanged DOM alive so streaming never flickers.
import { createMarkdown, renderMarkdown } from './markdown.js'
import { patchContent } from './diff.js'
import { enhance, installInteractions, rerenderDiagrams } from './enhance.js'
import { rebuildTOC, scrollToHeading } from './toc.js'
import { installSearch, openSearch } from './search.js'

const content = document.getElementById('content')
const tocSidebar = document.getElementById('toc')
const searchOverlay = document.getElementById('search')

let htmlEnabled = false
let md = createMarkdown({ html: htmlEnabled })
let source = ''
let renderPending = false
let rafId = 0
let timeoutId = 0
let firstRender = true

const searchCtl = installSearch(content, searchOverlay)
installInteractions(content)

function post(msg) {
  window.webkit?.messageHandlers?.preview?.postMessage(msg)
}

// Streaming often leaves the last fence unclosed; close it for display so the
// tail renders as a live code block instead of escaping as text.
function closeOpenFence(src) {
  const fences = src.match(/^(`{3,}|~{3,})/gm) || []
  let open = null
  for (const f of fences) {
    if (!open) open = f
    else if (f[0] === open[0] && f.length >= open.length) open = null
  }
  return open ? src + '\n' + open : src
}

function nearBottom() {
  const el = document.scrollingElement
  return el.scrollHeight - el.scrollTop - el.clientHeight < 48
}

function render() {
  renderPending = false
  cancelAnimationFrame(rafId)
  clearTimeout(timeoutId)
  const follow = !firstRender && nearBottom()
  const html = renderMarkdown(md, closeOpenFence(source), { html: htmlEnabled })
  const added = patchContent(content, html)
  enhance(added, { animate: !firstRender })
  rebuildTOC(content, tocSidebar)
  searchCtl.refreshIfOpen()
  if (follow) {
    const el = document.scrollingElement
    el.scrollTop = el.scrollHeight
  }
  firstRender = false
}

// Coalesce to one render per frame. rAF is the normal path; the timeout
// backstop covers hidden/offscreen web views (inactive tabs keep their
// preview mounted invisibly, where WebKit never fires rAF).
function scheduleRender() {
  if (renderPending) return
  renderPending = true
  rafId = requestAnimationFrame(render)
  timeoutId = setTimeout(render, 50)
}

// Link routing: external links go to the default browser via Swift; relative
// .md links open in the preview; anchors smooth-scroll in place.
content.addEventListener('click', (ev) => {
  const a = ev.target.closest('a[href]')
  if (!a) return
  const href = a.getAttribute('href')
  if (href.startsWith('#')) {
    ev.preventDefault()
    const target = document.getElementById(decodeURIComponent(href.slice(1)))
    if (target) scrollToHeading(target)
    return
  }
  ev.preventDefault()
  if (/^(https?|mailto):/i.test(href)) post({ type: 'openExternal', url: href })
  else if (/\.(md|markdown)(#.*)?$/i.test(href)) post({ type: 'openRelative', path: href })
})

document.getElementById('toc-toggle').addEventListener('click', () => {
  document.body.classList.toggle('toc-collapsed')
})

window.preview = {
  /** Replace the full Markdown source (file load, watcher reload, stream tick). */
  setContent(src) {
    source = src ?? ''
    scheduleRender()
  },

  /** Append streamed Markdown (AI token output). */
  append(chunk) {
    source += chunk
    scheduleRender()
  },

  getSource() { return source },

  /** 'light' | 'dark' — resolved on the Swift side (auto never reaches JS). */
  setTheme(theme) {
    document.documentElement.dataset.theme = theme === 'dark' ? 'dark' : 'light'
    rerenderDiagrams(theme)
  },

  /**
   * Reader customization from Settings: font size, reading width, code line
   * numbers, default code wrap, TOC visibility, animations.
   */
  setOptions(opts = {}) {
    const root = document.documentElement
    if (opts.fontSize) root.style.setProperty('--md-font-size', opts.fontSize + 'px')
    if (opts.readingWidth) root.style.setProperty('--md-width', opts.readingWidth + 'px')
    document.body.classList.toggle('no-line-numbers', opts.lineNumbers === false)
    document.body.classList.toggle('wrap-code', opts.wrapCode === true)
    document.body.classList.toggle('toc-collapsed', opts.showTOC === false)
    document.body.classList.toggle('no-animations', opts.animations === false)
    root.classList.toggle('no-animations', opts.animations === false)
  },

  /** Toggle sanitized raw-HTML rendering (Settings). */
  setHTMLEnabled(enabled) {
    htmlEnabled = !!enabled
    md = createMarkdown({ html: htmlEnabled })
    scheduleRender()
  },

  /** Open the ⌘F overlay (routed from the Swift shell). */
  find() { openSearch(searchOverlay) },

  /**
   * Self-contained HTML export. Serializes same-origin stylesheet rules
   * (minus @font-face — exports fall back to system fonts) and the enhanced
   * content. zt-asset:// image URLs are replaced with data URIs by Swift.
   */
  async exportHTML(title) {
    let css = ''
    for (const sheet of document.styleSheets) {
      try {
        for (const rule of sheet.cssRules) {
          if (rule.type !== CSSRule.FONT_FACE_RULE) css += rule.cssText + '\n'
        }
      } catch { /* cross-origin sheet — none expected */ }
    }
    const theme = document.documentElement.dataset.theme || 'light'
    const body = content.cloneNode(true)
    for (const el of body.querySelectorAll('.zt-hit')) el.replaceWith(...el.childNodes)
    return `<!doctype html>
<html data-theme="${theme}"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${(title || 'Document').replace(/[<>&]/g, '')}</title>
<style>${css}</style></head>
<body class="export"><main id="content">${body.innerHTML}</main></body></html>`
  },
}

window.addEventListener('error', (e) => post({ type: 'error', message: String(e.message) }))
post({ type: 'ready' })
