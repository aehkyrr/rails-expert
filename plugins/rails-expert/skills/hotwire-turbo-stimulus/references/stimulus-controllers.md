# Stimulus Controllers: Complete Guide

## What is Stimulus?

Stimulus is a modest JavaScript framework for adding behavior to HTML. It's the "JavaScript sprinkles" complement to Turbo's server-rendered HTML.

**Stimulus Philosophy:**
- HTML is the source of truth
- Controllers enhance existing HTML
- Small, focused controllers
- Data attributes connect JavaScript to HTML
- Progressive enhancement
- Plays well with server-rendered content

## Controller Structure

### Basic Controller

```javascript
// app/javascript/controllers/hello_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Hello, Stimulus!")
  }
}
```

```erb
<div data-controller="hello">
  <!-- Controller connects when element appears -->
</div>
```

### Lifecycle Callbacks

```javascript
export default class extends Controller {
  initialize() {
    // Once, when controller instantiated
    console.log("Controller created")
  }

  connect() {
    // When controller connects to DOM
    // Can be called multiple times (if element removed and re-added)
    console.log("Controller connected")
  }

  disconnect() {
    // When controller disconnects from DOM
    // Clean up event listeners, timers, etc.
    console.log("Controller disconnected")
  }
}
```

## Targets

Reference specific elements within the controller's scope:

```javascript
export default class extends Controller {
  static targets = ["input", "output", "button"]

  connect() {
    // Singular: first matching element (throws if missing)
    console.log(this.inputTarget)

    // Plural: all matching elements (array)
    console.log(this.inputTargets)

    // Has: boolean check
    if (this.hasInputTarget) {
      this.inputTarget.focus()
    }
  }
}
```

```erb
<div data-controller="example">
  <input data-example-target="input">
  <input data-example-target="input">
  <div data-example-target="output"></div>
  <button data-example-target="button">Submit</button>
</div>
```

## Actions

Connect DOM events to controller methods:

### Basic Actions

```javascript
export default class extends Controller {
  greet() {
    console.log("Hello!")
  }
}
```

```erb
<!-- Default event (click for buttons) -->
<button data-action="hello#greet">Say Hello</button>

<!-- Explicit event -->
<input data-action="input->hello#greet">

<!-- Multiple actions -->
<button data-action="click->hello#greet mouseover->hello#highlight">
```

### Action Options

```erb
<!-- Prevent default -->
<form data-action="submit->form#save:prevent">
  <!-- Calls event.preventDefault() -->
</form>

<!-- Stop propagation -->
<button data-action="click->menu#open:stop">
  <!-- Calls event.stopPropagation() -->
</button>

<!-- Debounce -->
<input data-action="input->search#query:debounce(500)">
  <!-- Waits 500ms after last input -->
</input>

<!-- Throttle -->
<div data-action="scroll->infinite#load:throttle(1000)">
  <!-- Max once per 1000ms -->
</div>

<!-- Once -->
<button data-action="click->analytics#track:once">
  <!-- Fires only once -->
</button>
```

### Global Actions

Listen to window or document events:

```javascript
export default class extends Controller {
  static targets = ["dropdown"]

  // Close dropdown when clicking outside
  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.dropdownTarget.classList.add("hidden")
    }
  }
}
```

```erb
<div data-controller="dropdown" data-action="click@window->dropdown#closeOnClickOutside">
  <button data-action="dropdown#toggle">Toggle</button>
  <div data-dropdown-target="dropdown" class="hidden">
    <!-- Dropdown content -->
  </div>
</div>
```

## Values

Pass data from HTML to JavaScript:

```javascript
export default class extends Controller {
  static values = {
    url: String,
    count: Number,
    active: Boolean,
    items: Array,
    config: Object
  }

  connect() {
    console.log(this.urlValue)      // String
    console.log(this.countValue)    // Number
    console.log(this.activeValue)   // Boolean
    console.log(this.itemsValue)    // Array
    console.log(this.configValue)   // Object
  }

  // Called when value changes
  countValueChanged(value, previousValue) {
    console.log(`Count changed from ${previousValue} to ${value}`)
  }
}
```

```erb
<div data-controller="example"
     data-example-url-value="<%= products_path %>"
     data-example-count-value="42"
     data-example-active-value="true"
     data-example-items-value="<%= ['a', 'b', 'c'].to_json %>"
     data-example-config-value="<%= { key: 'value' }.to_json %>">
</div>
```

### Default Values

```javascript
static values = {
  count: { type: Number, default: 0 },
  url: { type: String, default: "/api/default" }
}
```

## Classes

Manage CSS classes through data attributes:

```javascript
export default class extends Controller {
  static classes = ["active", "inactive"]

  connect() {
    this.element.classList.add(this.activeClass)
  }

  toggle() {
    this.element.classList.toggle(this.activeClass)
  }
}
```

```erb
<div data-controller="toggle"
     data-toggle-active-class="bg-blue-500"
     data-toggle-inactive-class="bg-gray-200">
</div>
```

Allows styling without hardcoding CSS classes in JavaScript.

## Common Patterns

### Form Validation

```javascript
// app/javascript/controllers/form_validation_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["email", "password", "submit"]

  validate() {
    const emailValid = this.emailTarget.value.includes("@")
    const passwordValid = this.passwordTarget.value.length >= 8

    this.submitTarget.disabled = !(emailValid && passwordValid)
  }
}
```

```erb
<div data-controller="form-validation">
  <input type="email" data-form-validation-target="email" data-action="input->form-validation#validate">
  <input type="password" data-form-validation-target="password" data-action="input->form-validation#validate">
  <button data-form-validation-target="submit" disabled>Submit</button>
</div>
```

### Dropdown Menu

```javascript
// app/javascript/controllers/dropdown_controller.js
export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }

  hide(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }
}
```

```erb
<div data-controller="dropdown" data-action="click@window->dropdown#hide">
  <button data-action="dropdown#toggle">Menu</button>

  <div data-dropdown-target="menu" class="hidden">
    <a href="/products">Products</a>
    <a href="/about">About</a>
  </div>
</div>
```

### Auto-Save

```javascript
// app/javascript/controllers/autosave_controller.js
export default class extends Controller {
  static values = { url: String }
  static targets = ["status"]

  save() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.performSave()
    }, 1000)  // Debounce 1 second
  }

  async performSave() {
    this.statusTarget.textContent = "Saving..."

    const formData = new FormData(this.element)

    const response = await fetch(this.urlValue, {
      method: "PATCH",
      body: formData,
      headers: {
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      }
    })

    if (response.ok) {
      this.statusTarget.textContent = "Saved!"
    } else {
      this.statusTarget.textContent = "Error saving"
    }
  }
}
```

```erb
<%= form_with model: @product,
              data: {
                controller: "autosave",
                autosave_url_value: product_path(@product),
                action: "input->autosave#save"
              } do |f| %>
  <%= f.text_field :name %>
  <%= f.text_area :description %>
  <span data-autosave-target="status"></span>
<% end %>
```

### Character Counter

```javascript
export default class extends Controller {
  static targets = ["input", "count"]
  static values = { max: Number }

  update() {
    const length = this.inputTarget.value.length
    this.countTarget.textContent = `${length}/${this.maxValue}`

    if (length > this.maxValue) {
      this.countTarget.classList.add("text-red-500")
    } else {
      this.countTarget.classList.remove("text-red-500")
    }
  }
}
```

```erb
<div data-controller="character-counter" data-character-counter-max-value="500">
  <textarea data-character-counter-target="input" data-action="input->character-counter#update"></textarea>
  <span data-character-counter-target="count">0/500</span>
</div>
```

### Clipboard Copy

```javascript
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { successMessage: String }

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.value)

    const originalText = this.buttonTarget.textContent
    this.buttonTarget.textContent = this.successMessageValue || "Copied!"

    setTimeout(() => {
      this.buttonTarget.textContent = originalText
    }, 2000)
  }
}
```

```erb
<div data-controller="clipboard" data-clipboard-success-message-value="Copied to clipboard!">
  <input data-clipboard-target="source" value="<%= @product.sku %>" readonly>
  <button data-clipboard-target="button" data-action="clipboard#copy">Copy SKU</button>
</div>
```

## Controller Composition

### Multiple Controllers

```erb
<div data-controller="dropdown autosave">
  <!-- Both controllers active -->
</div>
```

### Nested Controllers

```erb
<div data-controller="parent">
  <div data-controller="child">
    <!-- Both parent and child controllers active -->
  </div>
</div>
```

### Controller Inheritance

```javascript
// app/javascript/controllers/application_controller.js
import { Controller } from "@hotwired/stimulus"

export class ApplicationController extends Controller {
  get csrfToken() {
    return document.querySelector("[name='csrf-token']").content
  }

  async post(url, data) {
    return fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify(data)
    })
  }
}

// app/javascript/controllers/product_controller.js
import { ApplicationController } from "./application_controller"

export default class extends ApplicationController {
  async save() {
    const response = await this.post("/products", this.formData)
    // Uses inherited post() method
  }
}
```

## Working with Turbo

### Stimulus + Turbo Frames

```javascript
export default class extends Controller {
  loadFrame() {
    const frame = document.getElementById("product-details")
    frame.src = `/products/${this.productIdValue}`
  }
}
```

### Stimulus + Turbo Streams

```javascript
export default class extends Controller {
  async delete() {
    await fetch(this.urlValue, {
      method: "DELETE",
      headers: { "X-CSRF-Token": this.csrfToken }
    })
    // Turbo Stream response automatically updates DOM
  }
}
```

## Best Practices

1. **Keep controllers focused** - single responsibility
2. **Use targets** instead of querySelector
3. **Use values** for data passing
4. **Use classes** for styling flexibility
5. **Handle cleanup** in disconnect()
6. **Use lifecycle callbacks** appropriately
7. **Name controllers descriptively** (dropdown, not utils)
8. **Test controllers** with Stimulus Testing Library
9. **Avoid jQuery** - use native DOM APIs
10. **Compose controllers** instead of creating giant ones

Stimulus provides just enough JavaScript to make HTML interactive. Master it and you'll rarely need heavier frameworks.
