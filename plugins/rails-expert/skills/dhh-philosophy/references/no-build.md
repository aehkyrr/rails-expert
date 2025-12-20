# NO BUILD: Rails 8's Frontend Philosophy

## The Problem with Build Tools

For years, JavaScript development required complex build toolchains:

```bash
npm install webpack webpack-cli babel-loader @babel/core @babel/preset-env \
css-loader style-loader mini-css-extract-plugin terser-webpack-plugin \
webpack-dev-server --save-dev

# Plus configuration files
webpack.config.js
babel.config.js
.browserslistrc
postcss.config.js
```

This complexity:
- Slows development (wait for rebuilds)
- Breaks frequently (dependency conflicts)
- Requires JavaScript expertise even for Ruby developers
- Creates deployment headaches
- Ages poorly (config becomes obsolete)

Rails 8 says: **Stop building. Ship source.**

## NO BUILD Philosophy

Rails 8 eliminates JavaScript build tools for most applications. Instead:

1. **Modern browsers support ES modules natively** - no transpilation needed
2. **Import maps** - browser-native module resolution
3. **HTTP/2** - parallel loading makes concatenation unnecessary
4. **Propshaft** - simple asset pipeline without complex builds
5. **Turbo + Stimulus** - rich interactivity with minimal JavaScript

Result: Development is instant. Deployment is simple. Maintenance is minimal.

## How NO BUILD Works

### Import Maps (Browser-Native Modules)

Import maps teach browsers where to find JavaScript modules:

```html
<!-- app/views/layouts/application.html.erb -->
<%= javascript_importmap_tags %>
```

Generates:

```html
<script type="importmap">
{
  "imports": {
    "application": "/assets/application-abc123.js",
    "@hotwired/turbo": "/assets/turbo.min-def456.js",
    "@hotwired/stimulus": "/assets/stimulus.min-ghi789.js"
  }
}
</script>
<script type="module">import "application"</script>
```

Now your JavaScript can use standard imports:

```javascript
// app/javascript/application.js
import "@hotwired/turbo"
import "@hotwired/stimulus"
import { Controller } from "@hotwired/stimulus"

// Your controllers
import HelloController from "./controllers/hello_controller"
```

The browser handles module resolution. No build step.

### Propshaft: The Simple Asset Pipeline

Rails 8 replaces Sprockets with **Propshaft**, a minimal asset pipeline:

**What Propshaft Does:**
- Adds digest fingerprints to filenames for caching
- Generates import maps from `config/importmap.rb`
- Serves assets in development
- Precompiles assets for production

**What Propshaft Doesn't Do:**
- Transpile JavaScript
- Minify code
- Bundle modules
- Process SCSS/LESS
- Run complex build chains

That's the point. Browsers do the work.

### Configuration is Minimal

```ruby
# config/importmap.rb
pin "application"
pin "@hotwired/turbo", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin_all_from "app/javascript/controllers", under: "controllers"
```

That's it. No webpack config. No babel config. No build scripts.

### Adding Packages

Adding JavaScript libraries is simple:

```bash
# Install from CDN
bin/importmap pin lodash

# Or download locally
bin/importmap pin lodash --download
```

Updates `config/importmap.rb`:

```ruby
pin "lodash", to: "https://cdn.jsdelivr.net/npm/lodash@4.17.21/+esm"
# Or
pin "lodash", to: "lodash.js"  # Downloaded to app/assets/builds/
```

Use it in your JavaScript:

```javascript
import _ from "lodash"

_.map([1, 2, 3], n => n * 2)
```

### CSS Without Build

Rails 8 serves CSS directly:

```ruby
# app/assets/stylesheets/application.css
/*
 *= require_tree .
 *= require_self
 */
```

Or use Tailwind via the `tailwindcss-rails` gem (optional):

```bash
bin/rails tailwindcss:install
```

This uses a standalone Tailwind binary—no Node.js required.

## What About TypeScript/JSX/Advanced Features?

Rails' answer: **You probably don't need them.**

### TypeScript

Rails philosophy: Ruby is dynamically typed. JavaScript is dynamically typed. Types are optional.

If you need types, use JSDoc comments:

```javascript
/**
 * @param {string} name
 * @param {number} age
 * @returns {User}
 */
function createUser(name, age) {
  return { name, age }
}
```

Editors provide autocomplete and type checking without build steps.

### JSX/React

Rails philosophy: Use Hotwire (Turbo + Stimulus) instead.

Turbo provides:
- Server-rendered updates
- Instant page navigation
- Form handling
- Real-time updates

Stimulus provides:
- Lightweight controllers
- Progressive enhancement
- Direct DOM manipulation

Together, they handle 95% of use cases without React's complexity.

If you genuinely need React, Rails can accommodate:

```bash
./bin/bundle add jsbundling-rails
./bin/rails javascript:install:esbuild
```

But Rails nudges you toward simpler solutions first.

### Modern JavaScript Features

Modern browsers support ES2015+ features:

```javascript
// All work without transpilation
const arrow = () => "works"
const [a, b] = [1, 2]
const { name } = user
const template = `Hello ${name}`
class Controller extends BaseController { }
async function loadData() { }
```

Caniuse.com shows >95% browser support for modern JavaScript.

If you need cutting-edge features, browsers will support them soon. Wait instead of building.

## Development Experience

### Instant Feedback

With NO BUILD:

1. Edit JavaScript file
2. Refresh browser
3. See changes

No waiting for webpack. No hot module replacement complexity. No build errors.

### Simpler Debugging

Browser dev tools show original source:

```javascript
// app/javascript/controllers/hello_controller.js
export default class extends Controller {
  connect() {
    console.log("Hello!")  // Set breakpoint here
  }
}
```

No source maps needed. What you write is what you debug.

### Fewer Dependencies

```json
// package.json - Rails 8 default
{
  "name": "app",
  "private": "true",
  "dependencies": {
    "@hotwired/stimulus": "^3.2.1",
    "@hotwired/turbo": "^8.0.0"
  }
}
```

That's it. Two dependencies. No babel, webpack, or hundreds of transitive dependencies.

Compare to a typical React app:

```json
{
  "dependencies": {
    "react": "^18.0.0",
    "react-dom": "^18.0.0"
  },
  "devDependencies": {
    "@babel/core": "^7.0.0",
    "@babel/preset-env": "^7.0.0",
    "@babel/preset-react": "^7.0.0",
    "babel-loader": "^9.0.0",
    "css-loader": "^6.0.0",
    "html-webpack-plugin": "^5.0.0",
    "style-loader": "^3.0.0",
    "webpack": "^5.0.0",
    "webpack-cli": "^5.0.0",
    "webpack-dev-server": "^4.0.0"
    // Plus 200+ transitive dependencies
  }
}
```

### Easier Upgrades

With NO BUILD, upgrades are simple:

```bash
# Update import map
bin/importmap pin @hotwired/turbo@latest
```

No compatibility checks between webpack and babel and loaders. No `npm audit fix` to run. No lockfile conflicts.

## Production Performance

### HTTP/2 Parallel Loading

HTTP/2 loads multiple files in parallel over a single connection. Bundling provides no benefit.

```html
<!-- Loads in parallel over HTTP/2 -->
<script type="module">
  import "application"  // Loads app + dependencies in parallel
</script>
```

### Browser Caching

Import maps + digested filenames = perfect caching:

```html
<script type="importmap">
{
  "imports": {
    "turbo": "/assets/turbo.min-abc123def456.js"  // Digest changes when file changes
  }
}
</script>
```

Browsers cache files forever. Cache busts when content changes.

### Minification Still Happens

Propshaft serves minified versions in production:

```ruby
# config/environments/production.rb
config.assets.compile = false
config.assets.digest = true
```

Minified `.min.js` files are served as-is. Custom JavaScript is left readable (or use a minimal minifier if needed).

## When You Might Need a Build Step

Rails allows build tools when genuinely needed:

### Scenario 1: Legacy Codebase with Build

If migrating from older Rails with Webpacker:

```bash
./bin/bundle add jsbundling-rails
./bin/rails javascript:install:esbuild
```

Keeps your existing build. Migrate to NO BUILD gradually.

### Scenario 2: TypeScript Requirement

If your team insists on TypeScript:

```bash
./bin/bundle add jsbundling-rails
./bin/rails javascript:install:esbuild
```

Then configure esbuild for TypeScript. But Rails encourages reconsidering this choice.

### Scenario 3: Complex SPA

If building a heavy client-side SPA:

```bash
./bin/bundle add jsbundling-rails
./bin/rails javascript:install:esbuild
```

But Rails asks: Do you really need an SPA? Turbo + Stimulus might suffice.

## The NO BUILD Philosophy in Practice

### Start Simple

```bash
rails new myapp
cd myapp
bin/rails generate controller Home index
```

You have:
- Turbo for navigation
- Stimulus for interactivity
- Import maps for modules
- No build required

### Add Interactivity

```javascript
// app/javascript/controllers/dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }
}
```

```html
<!-- app/views/shared/_header.html.erb -->
<div data-controller="dropdown">
  <button data-action="click->dropdown#toggle">Menu</button>
  <nav data-dropdown-target="menu" class="hidden">
    <!-- Menu items -->
  </nav>
</div>
```

Refresh browser. It works. No build.

### Add NPM Package

Need a date picker?

```bash
bin/importmap pin flatpickr
```

Use it:

```javascript
import flatpickr from "flatpickr"

flatpickr(".datepicker", {})
```

Works instantly.

## Deployment

### Production Build is Minimal

```bash
bin/rails assets:precompile
```

This:
- Copies assets to `public/assets/`
- Adds digest fingerprints
- Generates import map
- Serves minified versions

Takes seconds, not minutes.

### No Node.js in Production

Dockerfile doesn't need Node.js:

```dockerfile
FROM ruby:3.2

# No node installation needed!

COPY Gemfile* ./
RUN bundle install

COPY . .
RUN bundle exec rails assets:precompile

CMD ["rails", "server"]
```

Simpler, smaller, faster.

## Common Questions

**Q: What about older browsers?**
A: Import maps work in all modern browsers. For legacy support, use polyfills from a CDN.

**Q: What about bundling?**
A: HTTP/2 makes bundling unnecessary. Multiple small files load in parallel efficiently.

**Q: What about tree shaking?**
A: Only load what you use via import maps. Unused modules aren't loaded.

**Q: What about npm packages?**
A: Import maps support them via CDN (`pin "package", to: "https://cdn.jsdelivr.net/..."`).

**Q: What if I really need webpack?**
A: Rails supports it via `jsbundling-rails`. But try NO BUILD first.

## Conclusion

NO BUILD is about:
- **Simplicity over complexity**
- **Standards over tooling**
- **Browsers over builders**
- **Shipping over configuring**

Rails 8 trusts browsers to handle JavaScript. This frees you to focus on building features, not configuring builds.

Embrace NO BUILD. Your future self will thank you.
