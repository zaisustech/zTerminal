// Keyed block-level DOM diff. Each render produces full document HTML; top-
// level blocks are keyed by a hash of their source HTML, and blocks whose key
// already exists in the live DOM keep their element — so images never refetch
// and enhanced content (Mermaid SVG, lightboxes) survives re-renders. The key
// is the *pre-enhancement* HTML, stored in data-zt-key, which is what makes
// enhancement-in-place safe.

function hashHTML(s) {
  // FNV-1a, 32-bit — cheap and stable; collisions only cost a needless swap.
  let h = 0x811c9dc5
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i)
    h = Math.imul(h, 0x01000193)
  }
  return (h >>> 0).toString(36)
}

/**
 * Reconcile `container`'s children with the freshly rendered `html`.
 * Returns the list of newly inserted (or replaced) elements that still need
 * enhancement (Mermaid, animations, observers).
 */
export function patchContent(container, html) {
  const tpl = document.createElement('template')
  tpl.innerHTML = html
  const fresh = []
  for (const node of tpl.content.children) fresh.push(node)

  // Index existing blocks by key (queue per key to tolerate duplicates).
  const pool = new Map()
  for (const el of container.children) {
    const k = el.getAttribute('data-zt-key')
    if (!k) continue
    if (!pool.has(k)) pool.set(k, [])
    pool.get(k).push(el)
  }

  const target = []
  const added = []
  for (const node of fresh) {
    const key = hashHTML(node.outerHTML)
    const reusable = pool.get(key)
    if (reusable && reusable.length) {
      target.push(reusable.shift())
    } else {
      node.setAttribute('data-zt-key', key)
      target.push(node)
      added.push(node)
    }
  }

  // Apply the target order with minimal moves.
  const keep = new Set(target)
  for (const el of [...container.children]) {
    if (!keep.has(el)) el.remove()
  }
  let cursor = container.firstElementChild
  for (const el of target) {
    if (el === cursor) {
      cursor = cursor.nextElementSibling
    } else {
      container.insertBefore(el, cursor)
    }
  }
  return added
}
