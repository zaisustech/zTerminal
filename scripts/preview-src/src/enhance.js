// Post-diff enhancement of newly inserted blocks: lazy Mermaid rendering,
// delegated code-block controls, image lightbox, and entry animations.
// Everything here must be idempotent per element and must never change
// data-zt-key (the differ's identity).

let mermaidPromise = null
let mermaidTheme = 'default'
let seq = 0

function loadMermaid() {
  if (!mermaidPromise) {
    mermaidPromise = import('mermaid').then(({ default: mermaid }) => {
      mermaid.initialize({ startOnLoad: false, theme: mermaidTheme, securityLevel: 'strict' })
      return mermaid
    })
  }
  return mermaidPromise
}

const diagramObserver = new IntersectionObserver((entries) => {
  for (const e of entries) {
    if (!e.isIntersecting) continue
    diagramObserver.unobserve(e.target)
    renderDiagram(e.target)
  }
}, { rootMargin: '200px' })

async function renderDiagram(block) {
  const code = decodeURIComponent(block.getAttribute('data-mermaid') || '')
  const target = block.querySelector('.mermaid-target')
  if (!target || !code) return
  try {
    const mermaid = await loadMermaid()
    const { svg } = await mermaid.render(`zt-mmd-${seq++}`, code)
    target.innerHTML = svg
    block.classList.add('mermaid-done')
  } catch {
    // Invalid diagram: show the source with an inline error note; the rest of
    // the document is unaffected.
    target.innerHTML = ''
    const note = document.createElement('p')
    note.className = 'mermaid-error'
    note.textContent = 'Mermaid diagram failed to render'
    const pre = document.createElement('pre')
    pre.className = 'mermaid-source'
    const codeEl = document.createElement('code')
    codeEl.textContent = code
    pre.appendChild(codeEl)
    target.append(note, pre)
    block.classList.add('mermaid-done')
  }
}

/** Re-render all diagrams (used when the theme flips). */
export async function rerenderDiagrams(theme) {
  mermaidTheme = theme === 'dark' ? 'dark' : 'default'
  if (!mermaidPromise) return
  const mermaid = await mermaidPromise
  mermaid.initialize({ startOnLoad: false, theme: mermaidTheme, securityLevel: 'strict' })
  for (const block of document.querySelectorAll('.mermaid-block.mermaid-done')) {
    block.classList.remove('mermaid-done')
    renderDiagram(block)
  }
}

/** Enhance freshly inserted blocks and animate them in. */
export function enhance(blocks, { animate = true } = {}) {
  for (const el of blocks) {
    if (animate) {
      el.classList.add('zt-enter')
      el.addEventListener('animationend', () => el.classList.remove('zt-enter'), { once: true })
    }
    if (el.matches('.mermaid-block')) diagramObserver.observe(el)
    for (const d of el.querySelectorAll('.mermaid-block')) diagramObserver.observe(d)
  }
}

// --- Delegated interactions (installed once) -------------------------------

export function installInteractions(content) {
  content.addEventListener('click', (ev) => {
    const copy = ev.target.closest('.code-copy')
    if (copy) {
      const code = copy.closest('.code-block')?.querySelector('code')
      if (code) {
        navigator.clipboard.writeText(code.textContent.replace(/​/g, ''))
        copy.classList.add('copied')
        setTimeout(() => copy.classList.remove('copied'), 1200)
      }
      return
    }
    const wrap = ev.target.closest('.code-wrap')
    if (wrap) {
      wrap.closest('.code-block')?.classList.toggle('wrapped')
      return
    }
    // Current-line highlight: click a code line to mark it.
    const line = ev.target.closest('.code-body .cl')
    if (line) {
      const active = line.classList.contains('current')
      line.closest('code')?.querySelectorAll('.cl.current')
        .forEach((l) => l.classList.remove('current'))
      if (!active) line.classList.add('current')
      return
    }
    // Image lightbox.
    const img = ev.target.closest('#content img')
    if (img && !ev.target.closest('a')) {
      openLightbox(img)
    }
  })
}

function openLightbox(img) {
  const overlay = document.createElement('div')
  overlay.className = 'zt-lightbox'
  const big = document.createElement('img')
  big.src = img.currentSrc || img.src
  big.alt = img.alt || ''
  overlay.appendChild(big)
  const close = () => { overlay.remove(); document.removeEventListener('keydown', onKey) }
  const onKey = (e) => { if (e.key === 'Escape') close() }
  overlay.addEventListener('click', close)
  document.addEventListener('keydown', onKey)
  document.body.appendChild(overlay)
}
