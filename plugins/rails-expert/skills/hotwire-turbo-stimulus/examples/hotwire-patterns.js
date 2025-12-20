// Hotwire Patterns: Comprehensive Stimulus Controller Examples
//
// This file demonstrates common Stimulus controller patterns for
// building interactive UIs with Hotwire in Rails 8.

// =============================================================================
// PATTERN 1: Dropdown Menu with Outside Click Detection
// =============================================================================

// app/javascript/controllers/dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  static classes = ["open", "closed"]

  toggle(event) {
    event.stopPropagation()

    if (this.menuTarget.classList.contains(this.openClass)) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.menuTarget.classList.remove(this.closedClass)
    this.menuTarget.classList.add(this.openClass)
  }

  close() {
    this.menuTarget.classList.remove(this.openClass)
    this.menuTarget.classList.add(this.closedClass)
  }

  // Close when clicking outside
  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
}

// Usage in ERB:
// <div data-controller="dropdown" data-action="click@window->dropdown#closeOnClickOutside">
//   <button data-action="dropdown#toggle">Menu</button>
//   <div data-dropdown-target="menu"
//        data-dropdown-class="open=block"
//        data-dropdown-class="closed=hidden"
//        class="hidden">
//     <a href="/products">Products</a>
//   </div>
// </div>

// =============================================================================
// PATTERN 2: Auto-Save Form
// =============================================================================

// app/javascript/controllers/autosave_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]
  static values = {
    url: String,
    delay: { type: Number, default: 1000 }
  }

  connect() {
    this.timeout = null
  }

  save() {
    clearTimeout(this.timeout)

    this.showStatus("Waiting...")

    this.timeout = setTimeout(() => {
      this.performSave()
    }, this.delayValue)
  }

  async performSave() {
    this.showStatus("Saving...")

    const formData = new FormData(this.element)

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        body: formData,
        headers: {
          "X-CSRF-Token": this.csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        }
      })

      if (response.ok) {
        this.showStatus("Saved!", "success")
      } else {
        this.showStatus("Error saving", "error")
      }
    } catch (error) {
      this.showStatus("Network error", "error")
    }
  }

  showStatus(message, type = "info") {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.className = `status-${type}`

      if (type === "success") {
        setTimeout(() => {
          this.statusTarget.textContent = ""
        }, 2000)
      }
    }
  }

  get csrfToken() {
    return document.querySelector("[name='csrf-token']").content
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}

// Usage:
// <%= form_with model: @product,
//               data: {
//                 controller: "autosave",
//                 autosave_url_value: product_path(@product),
//                 action: "input->autosave#save"
//               } do |f| %>
//   <%= f.text_field :name %>
//   <span data-autosave-target="status"></span>
// <% end %>

// =============================================================================
// PATTERN 3: Live Search with Debounce
// =============================================================================

// app/javascript/controllers/search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String }

  search() {
    clearTimeout(this.timeout)

    const query = this.inputTarget.value

    if (query.length < 2) {
      this.clearResults()
      return
    }

    this.timeout = setTimeout(() => {
      this.performSearch(query)
    }, 300)  // Debounce 300ms
  }

  async performSearch(query) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.append("q", query)

    try {
      const response = await fetch(url, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      const html = await response.text()
      this.resultsTarget.innerHTML = html
    } catch (error) {
      console.error("Search failed:", error)
    }
  }

  clearResults() {
    this.resultsTarget.innerHTML = ""
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}

// Usage:
// <div data-controller="search" data-search-url-value="<%= search_products_path %>">
//   <input type="search" data-search-target="input" data-action="input->search#search">
//   <div data-search-target="results"></div>
// </div>

// =============================================================================
// PATTERN 4: Infinite Scroll
// =============================================================================

// app/javascript/controllers/infinite_scroll_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["entries", "pagination"]
  static values = { page: Number }

  scroll() {
    const { scrollTop, scrollHeight, clientHeight } = document.documentElement

    // Near bottom?
    if (scrollTop + clientHeight >= scrollHeight - 100) {
      this.loadMore()
    }
  }

  async loadMore() {
    if (this.loading) return

    this.loading = true
    this.pageValue += 1

    const url = new URL(window.location)
    url.searchParams.set("page", this.pageValue)

    try {
      const response = await fetch(url, {
        headers: { "Accept": "text/html" }
      })

      const html = await response.text()
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, "text/html")

      const newEntries = doc.querySelector("#entries").innerHTML
      this.entriesTarget.insertAdjacentHTML("beforeend", newEntries)

      // Hide pagination if no more results
      if (!newEntries.trim()) {
        this.paginationTarget.remove()
      }
    } finally {
      this.loading = false
    }
  }
}

// Usage:
// <div data-controller="infinite-scroll"
//      data-infinite-scroll-page-value="1"
//      data-action="scroll@window->infinite-scroll#scroll:throttle(200)">
//   <div id="entries" data-infinite-scroll-target="entries">
//     <%= render @products %>
//   </div>
//   <div data-infinite-scroll-target="pagination">Loading more...</div>
// </div>

// =============================================================================
// PATTERN 5: Modal Dialog
// =============================================================================

// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  open() {
    this.containerTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }

    this.containerTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  // Close on background click
  closeBackground(event) {
    if (event.target === this.containerTarget) {
      this.close()
    }
  }

  // Close on escape key
  closeWithKeyboard(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  disconnect() {
    document.body.classList.remove("overflow-hidden")
  }
}

// Usage:
// <%= turbo_frame_tag "modal",
//                     data: {
//                       controller: "modal",
//                       action: "keyup@window->modal#closeWithKeyboard"
//                     } do %>
//   <div data-modal-target="container"
//        data-action="click->modal#closeBackground"
//        class="hidden">
//     <div class="modal-content">
//       <%= yield %>
//       <button data-action="modal#close">Close</button>
//     </div>
//   </div>
// <% end %>

// =============================================================================
// PATTERN 6: Form Submission with Loading State
// =============================================================================

// app/javascript/controllers/form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  submit(event) {
    this.disableSubmit()
  }

  // Turbo event listeners
  connect() {
    this.element.addEventListener("turbo:submit-start", this.disableSubmit.bind(this))
    this.element.addEventListener("turbo:submit-end", this.enableSubmit.bind(this))
  }

  disableSubmit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this.originalText = this.submitTarget.textContent
      this.submitTarget.textContent = "Submitting..."
    }
  }

  enableSubmit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      this.submitTarget.textContent = this.originalText
    }
  }
}

// Usage:
// <%= form_with model: @product, data: { controller: "form" } do |f| %>
//   <%= f.text_field :name %>
//   <%= f.submit data: { form_target: "submit" } %>
// <% end %>

// =============================================================================
// PATTERN 7: Tabs
// =============================================================================

// app/javascript/controllers/tabs_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static classes = ["active", "inactive"]
  static values = { index: { type: Number, default: 0 } }

  connect() {
    this.showTab(this.indexValue)
  }

  select(event) {
    const index = this.tabTargets.indexOf(event.currentTarget)
    this.showTab(index)
  }

  showTab(index) {
    this.indexValue = index

    // Update tabs
    this.tabTargets.forEach((tab, i) => {
      tab.classList.toggle(this.activeClass, i === index)
      tab.classList.toggle(this.inactiveClass, i !== index)
    })

    // Update panels
    this.panelTargets.forEach((panel, i) => {
      panel.classList.toggle("hidden", i !== index)
    })
  }

  indexValueChanged(value, previousValue) {
    // Optionally update URL
    const url = new URL(window.location)
    url.searchParams.set("tab", value)
    history.replaceState({}, "", url)
  }
}

// Usage:
// <div data-controller="tabs"
//      data-tabs-active-class="border-blue-500"
//      data-tabs-inactive-class="border-gray-200">
//   <div class="tabs">
//     <button data-tabs-target="tab" data-action="tabs#select">Tab 1</button>
//     <button data-tabs-target="tab" data-action="tabs#select">Tab 2</button>
//   </div>
//   <div data-tabs-target="panel">Content 1</div>
//   <div data-tabs-target="panel" class="hidden">Content 2</div>
// </div>

// =============================================================================
// PATTERN 8: Slideshow/Carousel
// =============================================================================

// app/javascript/controllers/slideshow_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide"]
  static values = {
    index: { type: Number, default: 0 },
    autoplay: { type: Boolean, default: false },
    interval: { type: Number, default: 5000 }
  }

  connect() {
    this.showSlide()

    if (this.autoplayValue) {
      this.startAutoplay()
    }
  }

  next() {
    this.indexValue = (this.indexValue + 1) % this.slideTargets.length
  }

  previous() {
    this.indexValue = (this.indexValue - 1 + this.slideTargets.length) % this.slideTargets.length
  }

  showSlide() {
    this.slideTargets.forEach((slide, index) => {
      slide.classList.toggle("hidden", index !== this.indexValue)
    })
  }

  indexValueChanged() {
    this.showSlide()
  }

  startAutoplay() {
    this.autoplayTimer = setInterval(() => {
      this.next()
    }, this.intervalValue)
  }

  stopAutoplay() {
    if (this.autoplayTimer) {
      clearInterval(this.autoplayTimer)
    }
  }

  disconnect() {
    this.stopAutoplay()
  }
}

// =============================================================================
// PATTERN 9: Form Character Counter with Limit
// =============================================================================

// app/javascript/controllers/character_counter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "count", "remaining"]
  static values = { max: Number }
  static classes = ["warning", "danger"]

  update() {
    const length = this.inputTarget.value.length
    const remaining = this.maxValue - length

    this.countTarget.textContent = length
    this.remainingTarget.textContent = remaining

    // Color coding
    if (remaining < 0) {
      this.remainingTarget.classList.add(this.dangerClass)
      this.remainingTarget.classList.remove(this.warningClass)
    } else if (remaining < 20) {
      this.remainingTarget.classList.add(this.warningClass)
      this.remainingTarget.classList.remove(this.dangerClass)
    } else {
      this.remainingTarget.classList.remove(this.warningClass, this.dangerClass)
    }

    // Disable submit if over limit
    const submitButton = this.element.querySelector('[type="submit"]')
    if (submitButton) {
      submitButton.disabled = remaining < 0
    }
  }
}

// =============================================================================
// PATTERN 10: Clipboard Copy with Feedback
// =============================================================================

// app/javascript/controllers/clipboard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]
  static values = {
    successMessage: { type: String, default: "Copied!" },
    successDuration: { type: Number, default: 2000 }
  }

  copy(event) {
    event.preventDefault()

    const text = this.sourceTarget.value || this.sourceTarget.textContent
    navigator.clipboard.writeText(text).then(() => {
      this.showSuccess()
    }).catch(() => {
      this.showError()
    })
  }

  showSuccess() {
    if (this.hasButtonTarget) {
      const originalText = this.buttonTarget.textContent
      this.buttonTarget.textContent = this.successMessageValue
      this.buttonTarget.classList.add("success")

      setTimeout(() => {
        this.buttonTarget.textContent = originalText
        this.buttonTarget.classList.remove("success")
      }, this.successDurationValue)
    }
  }

  showError() {
    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = "Failed!"
      this.buttonTarget.classList.add("error")
    }
  }
}

// =============================================================================
// PATTERN 11: Ajax Form Submission
// =============================================================================

// app/javascript/controllers/remote_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "errors"]
  static values = { url: String }

  async submit(event) {
    event.preventDefault()

    const formData = new FormData(this.element)
    this.disableSubmit()
    this.clearErrors()

    try {
      const response = await fetch(this.urlValue, {
        method: this.element.method,
        body: formData,
        headers: {
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        }
      })

      const data = await response.json()

      if (response.ok) {
        this.handleSuccess(data)
      } else {
        this.handleErrors(data.errors)
      }
    } catch (error) {
      this.handleError(error)
    } finally {
      this.enableSubmit()
    }
  }

  handleSuccess(data) {
    // Reset form or redirect
    this.element.reset()
    this.dispatch("success", { detail: data })
  }

  handleErrors(errors) {
    if (this.hasErrorsTarget) {
      const html = Object.entries(errors)
        .map(([field, messages]) => `<li>${field}: ${messages.join(", ")}</li>`)
        .join("")
      this.errorsTarget.innerHTML = `<ul>${html}</ul>`
    }
  }

  handleError(error) {
    console.error("Form submission failed:", error)
    alert("An error occurred. Please try again.")
  }

  disableSubmit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this.originalText = this.submitTarget.textContent
      this.submitTarget.textContent = "Submitting..."
    }
  }

  enableSubmit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      this.submitTarget.textContent = this.originalText
    }
  }

  clearErrors() {
    if (this.hasErrorsTarget) {
      this.errorsTarget.innerHTML = ""
    }
  }

  get csrfToken() {
    return document.querySelector("[name='csrf-token']").content
  }
}

// =============================================================================
// PATTERN 12: Confirm Dialog
// =============================================================================

// app/javascript/controllers/confirm_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { message: String }

  confirm(event) {
    if (!window.confirm(this.messageValue)) {
      event.preventDefault()
      event.stopImmediatePropagation()
    }
  }
}

// Usage:
// <%= button_to "Delete",
//               product_path(@product),
//               method: :delete,
//               data: {
//                 controller: "confirm",
//                 confirm_message_value: "Are you sure?",
//                 action: "confirm#confirm"
//               } %>

// =============================================================================
// PATTERN 13: Toggle Visibility
// =============================================================================

// app/javascript/controllers/toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleable"]
  static classes = ["hidden"]

  toggle() {
    this.toggleableTargets.forEach(target => {
      target.classList.toggle(this.hiddenClass)
    })
  }

  show() {
    this.toggleableTargets.forEach(target => {
      target.classList.remove(this.hiddenClass)
    })
  }

  hide() {
    this.toggleableTargets.forEach(target => {
      target.classList.add(this.hiddenClass)
    })
  }
}

// =============================================================================
// PATTERN 14: Nested Form (Dynamic Fields)
// =============================================================================

// app/javascript/controllers/nested_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  add(event) {
    event.preventDefault()

    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()

    const item = event.target.closest(".nested-fields")

    // Mark for destruction if persisted
    const destroyInput = item.querySelector("input[name*='_destroy']")
    if (destroyInput) {
      destroyInput.value = "1"
      item.style.display = "none"
    } else {
      item.remove()
    }
  }
}

// Usage:
// <div data-controller="nested-form">
//   <div data-nested-form-target="container">
//     <%= f.fields_for :line_items do |ff| %>
//       <div class="nested-fields">
//         <%= ff.text_field :product_id %>
//         <%= ff.number_field :quantity %>
//         <%= ff.hidden_field :_destroy %>
//         <button data-action="nested-form#remove">Remove</button>
//       </div>
//     <% end %>
//   </div>
//
//   <template data-nested-form-target="template">
//     <div class="nested-fields">
//       <input name="order[line_items_attributes][NEW_RECORD][product_id]">
//       <input name="order[line_items_attributes][NEW_RECORD][quantity]">
//       <button data-action="nested-form#remove">Remove</button>
//     </div>
//   </template>
//
//   <button data-action="nested-form#add">Add Line Item</button>
// </div>

// =============================================================================
// KEY TAKEAWAYS
// =============================================================================

// 1. LIFECYCLE:
//    - initialize() - Once when controller created
//    - connect() - When attached to DOM (can be multiple times)
//    - disconnect() - Clean up timers, listeners
//
// 2. TARGETS:
//    - Use targets instead of querySelector
//    - Check hasTarget before accessing
//    - Plural targets returns array
//
// 3. VALUES:
//    - Pass data from HTML to JavaScript
//    - Value types: String, Number, Boolean, Array, Object
//    - valueChanged() callback for reactions
//
// 4. ACTIONS:
//    - Default events (click for buttons, input for fields)
//    - Explicit events with event->controller#method
//    - Action options: :prevent, :stop, :once, :debounce, :throttle
//
// 5. BEST PRACTICES:
//    - Keep controllers small and focused
//    - Clean up in disconnect()
//    - Use native DOM APIs (not jQuery)
//    - Handle errors gracefully
//    - Provide loading states
//
// Master Stimulus and you'll build interactive UIs with minimal JavaScript!
