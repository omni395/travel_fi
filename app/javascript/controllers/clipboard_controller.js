import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  copy(event) {
    event.preventDefault()
    const button = event.target.closest('button')
    const text = button?.getAttribute('data-clipboard-text-value')
    const tooltipId = button?.getAttribute('data-tooltip-target')
    const tooltip = tooltipId ? document.getElementById(tooltipId) : null
    
    if (!text) return
    
    navigator.clipboard.writeText(text).then(() => {
      if (tooltip) {
        const originalContent = tooltip.innerHTML
        // Get the copied text from locale - fallback to English
        const copiedText = document.documentElement.lang === 'ru' ? 'Скопировано' : 'Copied'
        tooltip.innerHTML = `<span>${copiedText}</span><div class="tooltip-arrow" data-popper-arrow></div>`
        setTimeout(() => {
          tooltip.innerHTML = originalContent
        }, 2000)
      }
    }).catch(() => {
      console.error('Failed to copy to clipboard')
    })
  }
}
