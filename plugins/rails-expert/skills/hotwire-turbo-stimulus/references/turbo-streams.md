# Turbo Streams: Real-Time HTML Updates

## What Are Turbo Streams?

Turbo Streams deliver targeted HTML updates to specific parts of the page. Unlike Turbo Frames (which replace an entire frame), Turbo Streams can perform multiple surgical updates in a single response.

**Use Turbo Streams when:**
- Updating multiple page sections simultaneously
- Broadcasting real-time updates via WebSockets
- Adding/removing items from lists
- Showing flash messages without page reload

**Use Turbo Frames when:**
- Updating a single, scoped section
- Inline editing
- Modal windows
- Lazy loading content

## Seven Stream Actions

| Action | Purpose | Example |
|--------|---------|---------|
| `append` | Add to end of target | Add new comment to list |
| `prepend` | Add to beginning of target | Add latest item to top |
| `replace` | Replace entire target element | Update product card |
| `update` | Replace target's innerHTML | Update counter value |
| `remove` | Delete target element | Delete comment from list |
| `before` | Insert before target | Add notification above form |
| `after` | Insert after target | Add warning below button |

## After Form Submission

### Inline Turbo Stream Response

```ruby
# app/controllers/products_controller.rb
def create
  @product = Product.new(product_params)

  respond_to do |format|
    if @product.save
      format.turbo_stream {
        render turbo_stream: turbo_stream.prepend("products", @product)
      }
      format.html { redirect_to @product }
    else
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace("form", partial: "form", locals: { product: @product })
      }
      format.html { render :new, status: :unprocessable_entity }
    end
  end
end
```

### Turbo Stream Template

For multiple updates, use a template:

```ruby
# app/controllers/products_controller.rb
def create
  @product = Product.new(product_params)

  if @product.save
    respond_to do |format|
      format.turbo_stream  # Renders create.turbo_stream.erb
      format.html { redirect_to @product }
    end
  else
    render :new, status: :unprocessable_entity
  end
end
```

```erb
<%# app/views/products/create.turbo_stream.erb %>
<%= turbo_stream.prepend "products", @product %>
<%= turbo_stream.update "counter", Product.count %>
<%= turbo_stream.update "flash", partial: "shared/flash", locals: { notice: "Product created!" } %>
```

Multiple updates in one response!

## Broadcasting Updates (Real-Time)

### Model Callbacks

Broadcast changes to all connected users:

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  # After create, prepend to "products" stream
  after_create_commit -> {
    broadcast_prepend_to "products", target: "products"
  }

  # After update, replace in "products" stream
  after_update_commit -> {
    broadcast_replace_to "products"
  }

  # After destroy, remove from "products" stream
  after_destroy_commit -> {
    broadcast_remove_to "products"
  }
end
```

Shorthand:

```ruby
class Product < ApplicationRecord
  broadcasts_to ->(product) { "products" }, inserts_by: :prepend
end
```

Or even simpler:

```ruby
class Product < ApplicationRecord
  broadcasts
  # Broadcasts to model name stream ("products")
  # Uses appropriate action (prepend, replace, remove)
end
```

### View: Subscribe to Stream

```erb
<!-- app/views/products/index.html.erb %>
<%= turbo_stream_from "products" %>

<div id="products">
  <%= render @products %>
</div>
```

Now when any user creates/updates/deletes a product, all connected users see the change instantly via WebSockets.

### Multiple Streams

```erb
<%= turbo_stream_from "products" %>
<%= turbo_stream_from "notifications" %>
<%= turbo_stream_from current_user %>
```

Subscribe to multiple channels on one page.

### Custom Broadcasts

```ruby
# In controller or service
Turbo::StreamsChannel.broadcast_append_to(
  "products",
  target: "products",
  partial: "products/product",
  locals: { product: @product }
)

# Or using helpers
turbo_stream.broadcast_append_to("products", target: "products", content: "<div>New product!</div>")
```

### User-Specific Streams

```erb
<%= turbo_stream_from current_user %>
```

```ruby
# Broadcast to specific user
Turbo::StreamsChannel.broadcast_append_to(
  current_user,
  target: "notifications",
  partial: "notifications/notification",
  locals: { notification: @notification }
)
```

## Advanced Broadcasting

### Scoped Broadcasts

```ruby
class Comment < ApplicationRecord
  belongs_to :post

  after_create_commit -> {
    broadcast_prepend_to [post, "comments"],
      target: "comments",
      locals: { comment: self }
  }
end
```

```erb
<!-- app/views/posts/show.html.erb -->
<%= turbo_stream_from @post, "comments" %>
<!-- Subscribes to "post_123_comments" stream -->

<div id="comments">
  <%= render @post.comments %>
</div>
```

### Conditional Broadcasting

```ruby
class Product < ApplicationRecord
  after_update_commit :broadcast_if_public

  private

  def broadcast_if_public
    broadcast_replace_to "products" if published?
  end
end
```

### Background Job Broadcasting

```ruby
class ProcessReportJob < ApplicationJob
  def perform(report)
    # Process report
    report.update(status: "completed")

    # Broadcast update
    Turbo::StreamsChannel.broadcast_replace_to(
      report.user,
      target: dom_id(report),
      partial: "reports/report",
      locals: { report: report }
    )
  end
end
```

## Turbo Stream Helpers

### In Controllers

```ruby
turbo_stream.append("target", @product)
turbo_stream.prepend("target", @product)
turbo_stream.replace("target", @product)
turbo_stream.update("target", @product)
turbo_stream.remove("target")
turbo_stream.before("target", @product)
turbo_stream.after("target", @product)

# With custom partial
turbo_stream.append("target", partial: "products/card", locals: { product: @product })

# With plain HTML
turbo_stream.append("target", html: "<div>New content</div>")
```

### In Views

```erb
<%= turbo_stream.append "products", @product %>
<%= turbo_stream.replace dom_id(@product), @product %>
<%= turbo_stream.remove dom_id(@product) %>
<%= turbo_stream.update "counter", Product.count %>
```

## Common Patterns

### List Management

**Adding items:**

```ruby
# Controller
def create
  @product = Product.new(product_params)

  if @product.save
    respond_to do |format|
      format.turbo_stream
    end
  end
end
```

```erb
<%# create.turbo_stream.erb %>
<%= turbo_stream.prepend "products", @product %>
<%= turbo_stream.update "counter", Product.count %>
<%= turbo_stream.replace "form", partial: "form", locals: { product: Product.new } %>
```

**Removing items:**

```ruby
def destroy
  @product = Product.find(params[:id])
  @product.destroy

  respond_to do |format|
    format.turbo_stream
  end
end
```

```erb
<%# destroy.turbo_stream.erb %>
<%= turbo_stream.remove dom_id(@product) %>
<%= turbo_stream.update "counter", Product.count %>
```

### Flash Messages

```ruby
# Controller
flash.now[:notice] = "Product created!"

respond_to do |format|
  format.turbo_stream
end
```

```erb
<%# create.turbo_stream.erb %>
<%= turbo_stream.prepend "products", @product %>
<%= turbo_stream.update "flash" do %>
  <div class="notice"><%= flash[:notice] %></div>
<% end %>
```

### Optimistic UI Updates

```erb
<%= form_with model: @product, data: { turbo_stream_optimistic: true } do |f| %>
  <%= f.text_field :name %>
  <%= f.submit %>
<% end %>

<script>
document.addEventListener('turbo:submit-start', (event) => {
  // Show optimistic update
  const list = document.getElementById('products')
  list.insertAdjacentHTML('afterbegin', '<div class="loading">Adding product...</div>')
})
</script>
```

## Combining Streams and Frames

```erb
<!-- Frame for editing -->
<%= turbo_frame_tag dom_id(@product) do %>
  <%= render @product %>
<% end %>

<!-- Subscribe to stream for real-time updates -->
<%= turbo_stream_from "products" %>
```

Frame handles user interactions. Stream broadcasts updates from other users.

## Testing

### System Tests

```ruby
test "creates product with turbo stream" do
  visit products_path

  fill_in "Name", with: "New Product"
  click_button "Create"

  # Turbo stream should add product
  assert_selector "#product_#{Product.last.id}"
  assert_text "New Product"
end
```

### Controller Tests

```ruby
test "responds with turbo stream" do
  post products_path, params: { product: { name: "Widget" } }, as: :turbo_stream

  assert_turbo_stream action: :prepend, target: "products"
end
```

## Best Practices

1. **Use broadcasts for real-time** updates from server-side events
2. **Use after form submissions** for immediate feedback
3. **Combine multiple actions** in one response
4. **Target by ID** for specificity (`dom_id` helper)
5. **Provide fallbacks** (HTML format) for non-Turbo requests
6. **Test thoroughly** - streams add complexity
7. **Monitor performance** - broadcasting can be expensive
8. **Use background jobs** for heavy broadcast operations
9. **Handle errors gracefully** with proper status codes
10. **Cache streamed partials** when appropriate

Turbo Streams enable real-time, reactive interfaces with server-rendered HTML. Master them and you'll build applications that feel instant.
