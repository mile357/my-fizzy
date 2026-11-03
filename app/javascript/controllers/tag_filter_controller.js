import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "item", "filterBtn", "emptyNotice", "emptyNoticeText" ]
  static values = {
    current: { type: String, default: "all" },
    emptyAll: { type: String, default: "No tags found." }
  }

  static FILTERS = [ "all", "new", "recent" ]

  connect() {
    const savedFilter = sessionStorage.getItem("initiatives_tag_filter")
    if (savedFilter && this.constructor.FILTERS.includes(savedFilter)) {
      this.currentValue = savedFilter
    }
    this.applyFilter(this.currentValue)
  }

  select(event) {
    const filter = event.currentTarget.dataset.filterValue || "all"
    this.currentValue = filter
    sessionStorage.setItem("initiatives_tag_filter", filter)
    this.applyFilter(filter)
  }

  applyFilter(filter) {
    let visibleCount = 0

    this.itemTargets.forEach(item => {
      let visible = false
      if (filter === "all") {
        visible = true
      } else if (filter === "new") {
        visible = item.dataset.isNew === "true"
      } else if (filter === "recent") {
        visible = item.dataset.isRecent === "true"
      }

      item.style.display = visible ? "" : "none"
      if (visible) visibleCount++
    })

    if (this.hasEmptyNoticeTarget) {
      if (visibleCount === 0) {
        this.emptyNoticeTarget.style.display = "block"
        if (this.hasEmptyNoticeTextTarget) {
          if (filter === "new") {
            this.emptyNoticeTextTarget.textContent = "No new tags created in the past day."
          } else if (filter === "recent") {
            this.emptyNoticeTextTarget.textContent = "No tags created or used in the past month."
          } else {
            this.emptyNoticeTextTarget.textContent = this.emptyAllValue
          }
        }
      } else {
        this.emptyNoticeTarget.style.display = "none"
      }
    }

    if (this.hasFilterBtnTarget) {
      this.filterBtnTargets.forEach(btn => {
        const isCurrent = btn.dataset.filterValue === filter
        btn.classList.toggle("tag-filter-btn--active", isCurrent)
        btn.setAttribute("aria-pressed", isCurrent ? "true" : "false")
      })
    }
  }
}
