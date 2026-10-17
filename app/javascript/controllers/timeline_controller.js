import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "viewport",
    "track",
    "zoomBtn",
    "edgeLeftBtn",
    "edgeRightBtn",
    "todayMarker"
  ]

  static values = {
    zoom: { type: String, default: "6m" },
    todayPct: { type: Number, default: 0 }
  }

  static ZOOMS = [ "12m", "6m", "3m" ]

  connect() {
    const savedZoom = localStorage.getItem("initiatives_timeline_zoom")
    if (savedZoom && this.constructor.ZOOMS.includes(savedZoom)) {
      this.zoomValue = savedZoom
    }
    this.applyZoom(false)

    // Center on today or active row after initial render
    requestAnimationFrame(() => {
      this.scrollToToday(false)
      this.updateScrollIndicators()
    })
  }

  setZoom(event) {
    const targetZoom = event.currentTarget.dataset.zoom
    if (targetZoom && this.constructor.ZOOMS.includes(targetZoom)) {
      this.setZoomLevel(targetZoom)
    }
  }

  setZoomLevel(zoom) {
    if (!this.hasViewportTarget || !this.hasTrackTarget) return

    const viewport = this.viewportTarget
    const currentScrollRatio = (viewport.scrollLeft + viewport.clientWidth / 2) / (this.trackTarget.offsetWidth || 1)

    this.zoomValue = zoom
    localStorage.setItem("initiatives_timeline_zoom", zoom)
    this.applyZoom(true)

    // Keep relative center position when switching zoom
    requestAnimationFrame(() => {
      setTimeout(() => {
        const newScrollLeft = (this.trackTarget.offsetWidth * currentScrollRatio) - (viewport.clientWidth / 2)
        viewport.scrollTo({ left: Math.max(0, newScrollLeft), behavior: "smooth" })
        this.updateScrollIndicators()
      }, 50)
    })
  }

  applyZoom(animated = false) {
    const card = this.element.querySelector(".timeline-card") || this.element
    card.setAttribute("data-zoom", this.zoomValue)

    // Update active state on 3M / 6M / 12M direct select pill buttons
    if (this.hasZoomBtnTarget) {
      this.zoomBtnTargets.forEach(btn => {
        const isActive = btn.dataset.zoom === this.zoomValue
        btn.classList.toggle("timeline-zoom-btn--active", isActive)
        btn.setAttribute("aria-pressed", isActive ? "true" : "false")
      })
    }
  }

  scrollLeft() {
    if (!this.hasViewportTarget) return
    const scrollAmount = Math.max(280, this.viewportTarget.clientWidth * 0.45)
    this.viewportTarget.scrollBy({ left: -scrollAmount, behavior: "smooth" })
  }

  scrollRight() {
    if (!this.hasViewportTarget) return
    const scrollAmount = Math.max(280, this.viewportTarget.clientWidth * 0.45)
    this.viewportTarget.scrollBy({ left: scrollAmount, behavior: "smooth" })
  }

  scrollToToday(smooth = true) {
    if (!this.hasViewportTarget || !this.hasTrackTarget) return
    const viewport = this.viewportTarget
    const track = this.trackTarget
    const targetX = (track.offsetWidth * (this.todayPctValue / 100)) - (viewport.clientWidth / 2)
    viewport.scrollTo({ left: Math.max(0, targetX), behavior: smooth ? "smooth" : "instant" })
    this.updateScrollIndicators()
  }

  onScroll() {
    this.updateScrollIndicators()
  }

  updateScrollIndicators() {
    if (!this.hasViewportTarget) return
    const vp = this.viewportTarget
    const scrollLeft = vp.scrollLeft
    const maxScroll = vp.scrollWidth - vp.clientWidth

    const canScrollLeft = scrollLeft > 10
    const canScrollRight = scrollLeft < maxScroll - 10

    if (this.hasEdgeLeftBtnTarget) {
      this.edgeLeftBtnTarget.classList.toggle("is-visible", canScrollLeft)
    }
    if (this.hasEdgeRightBtnTarget) {
      this.edgeRightBtnTarget.classList.toggle("is-visible", canScrollRight)
    }
  }
}
