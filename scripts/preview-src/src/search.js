// In-preview search: an overlay bar with live match highlighting, an
// "N of M matches" counter, and wraparound next/previous. Matches are found on
// the text content of #content and wrapped in <mark> elements; blocks whose
// layout is skipped by content-visibility get it forced on while they contain
// matches so highlights are visible and scrollable-to.

let matches = []          // <mark> elements in document order
let current = -1
let lastQuery = ''

export function installSearch(content, overlay) {
  const input = overlay.querySelector('.search-input')
  const count = overlay.querySelector('.search-count')

  const refresh = () => {
    highlight(content, input.value)
    setCurrent(matches.length ? 0 : -1, count)
  }

  input.addEventListener('input', refresh)
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); step(e.shiftKey ? -1 : 1, count) }
    else if (e.key === 'Escape') { e.preventDefault(); closeSearch(content, overlay) }
  })
  overlay.querySelector('.search-prev').addEventListener('click', () => step(-1, count))
  overlay.querySelector('.search-next').addEventListener('click', () => step(1, count))
  overlay.querySelector('.search-close').addEventListener('click', () => closeSearch(content, overlay))

  document.addEventListener('keydown', (e) => {
    const cmd = e.metaKey || e.ctrlKey
    if (cmd && e.key.toLowerCase() === 'f') { e.preventDefault(); openSearch(overlay) }
    else if (cmd && e.key.toLowerCase() === 'g' && overlay.classList.contains('open')) {
      e.preventDefault(); step(e.shiftKey ? -1 : 1, count)
    } else if (e.key === 'Escape' && overlay.classList.contains('open')) {
      closeSearch(content, overlay)
    }
  })

  // Re-apply highlights when content changes underneath an open search.
  return { refreshIfOpen: () => { if (overlay.classList.contains('open') && input.value) refresh() } }
}

export function openSearch(overlay) {
  overlay.classList.add('open')
  const input = overlay.querySelector('.search-input')
  input.focus()
  input.select()
}

function closeSearch(content, overlay) {
  overlay.classList.remove('open')
  clearHighlights(content)
  overlay.querySelector('.search-count').textContent = ''
  matches = []; current = -1; lastQuery = ''
}

function clearHighlights(content) {
  for (const mark of content.querySelectorAll('mark.zt-hit')) {
    const parent = mark.parentNode
    mark.replaceWith(...mark.childNodes)
    parent.normalize()
  }
  for (const el of content.querySelectorAll('[data-zt-search-forced]')) {
    el.style.contentVisibility = ''
    el.removeAttribute('data-zt-search-forced')
  }
}

function highlight(content, query) {
  clearHighlights(content)
  matches = []; current = -1; lastQuery = query
  if (!query) return

  const q = query.toLowerCase()
  const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, {
    acceptNode: (n) =>
      n.parentElement?.closest('script, style, .zt-lightbox')
        ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT,
  })
  // Collect first — wrapping mutates the tree under the walker.
  const nodes = []
  for (let n = walker.nextNode(); n; n = walker.nextNode()) nodes.push(n)

  for (let node of nodes) {
    let idx = node.textContent.toLowerCase().indexOf(q)
    while (idx !== -1) {
      const range = document.createRange()
      range.setStart(node, idx)
      range.setEnd(node, idx + query.length)
      const mark = document.createElement('mark')
      mark.className = 'zt-hit'
      range.surroundContents(mark)
      matches.push(mark)
      // Continue in the text node that follows the inserted mark.
      node = mark.nextSibling
      if (!node || node.nodeType !== Node.TEXT_NODE) break
      idx = node.textContent.toLowerCase().indexOf(q)
    }
  }

  // Matches inside content-visibility-skipped blocks: force visibility so the
  // highlight can lay out and be scrolled to.
  for (const mark of matches) {
    const block = mark.closest('#content > *')
    if (block && !block.hasAttribute('data-zt-search-forced')) {
      block.style.contentVisibility = 'visible'
      block.setAttribute('data-zt-search-forced', '1')
    }
  }
}

function setCurrent(idx, countEl) {
  if (current >= 0 && matches[current]) matches[current].classList.remove('current')
  current = idx
  if (current >= 0 && matches[current]) {
    const m = matches[current]
    m.classList.add('current')
    m.scrollIntoView({ behavior: 'smooth', block: 'center' })
  }
  countEl.textContent = matches.length
    ? `${current + 1} of ${matches.length} matches`
    : (lastQuery ? 'No matches' : '')
}

function step(dir, countEl) {
  if (!matches.length) return
  setCurrent((current + dir + matches.length) % matches.length, countEl)
}
