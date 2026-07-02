// Table of contents sidebar: built from the rendered headings, updated
// incrementally on every content patch, with smooth-scroll on click and
// IntersectionObserver scroll-spy highlighting the section in view.

let spyObserver = null
let visibleHeadings = new Set()

export function rebuildTOC(content, sidebar) {
  const headings = [...content.querySelectorAll('h1, h2, h3, h4, h5, h6')]
    .filter((h) => h.id)
  const list = sidebar.querySelector('.toc-list')

  const sig = headings.map((h) => `${h.tagName}:${h.id}:${h.textContent}`).join('\n')
  if (list.dataset.sig === sig) { observe(headings); return }
  list.dataset.sig = sig

  list.textContent = ''
  for (const h of headings) {
    const level = Number(h.tagName[1])
    const item = document.createElement('a')
    item.className = `toc-item toc-l${level}`
    item.href = `#${h.id}`
    item.textContent = h.textContent
    item.dataset.target = h.id
    item.addEventListener('click', (e) => {
      e.preventDefault()
      scrollToHeading(h)
      history.replaceState(null, '', `#${h.id}`)
    })
    list.appendChild(item)
  }
  sidebar.classList.toggle('toc-empty', headings.length === 0)
  observe(headings)
}

// content-visibility blocks above the target expand after the first jump and
// shift it; re-snap once layout has settled so the heading truly lands at the
// top of the viewport.
export function scrollToHeading(el) {
  el.scrollIntoView({ behavior: 'smooth', block: 'start' })
  setTimeout(() => el.scrollIntoView({ behavior: 'auto', block: 'start' }), 420)
}

function observe(headings) {
  if (spyObserver) spyObserver.disconnect()
  visibleHeadings = new Set()
  spyObserver = new IntersectionObserver((entries) => {
    for (const e of entries) {
      if (e.isIntersecting) visibleHeadings.add(e.target.id)
      else visibleHeadings.delete(e.target.id)
    }
    updateActive(headings)
  }, { rootMargin: '0px 0px -70% 0px' })
  for (const h of headings) spyObserver.observe(h)
}

function updateActive(headings) {
  // Current section = first visible heading, or the last heading above the fold.
  let currentId = null
  for (const h of headings) {
    if (visibleHeadings.has(h.id)) { currentId = h.id; break }
  }
  if (!currentId) {
    for (const h of headings) {
      if (h.getBoundingClientRect().top < 100) currentId = h.id
      else break
    }
  }
  for (const item of document.querySelectorAll('.toc-item')) {
    item.classList.toggle('active', item.dataset.target === currentId)
  }
}
