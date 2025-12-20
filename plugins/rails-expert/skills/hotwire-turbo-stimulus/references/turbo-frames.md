# Turbo Frames: Complete Guide

## What Are Turbo Frames?

Turbo Frames decompose pages into independent contexts that can be updated individually without affecting the rest of the page.

Think of frames as "mini-pages" within your page. Each frame handles its own navigation and updates independently.

## Basic Turbo Frame

```erb
<%= turbo_frame_tag "example" do %>
  <h2>Frame Content</h2>
  <%= link_to "Update", update_path %>
<% end %>
```

Generates:

```html
<turbo-frame id="example">
  <h2>Frame Content</h2>
  <a href="/update">Update</a>
</turbo-frame>
```

When clicking "Update":
1. Turbo intercepts the click
2. Fetches `/update` via AJAX
3. Finds `<turbo-frame id="example">` in the response
4. Replaces current frame content
5. Rest of page unaffected

## Frame Naming with dom_id

Use Rails' `dom_id` helper for consistent frame IDs:

```erb
<%= turbo_frame_tag dom_id(@product) do %>
  <%= render @product %>
<% end %>
<!-- Generates: <turbo-frame id="product_123"> -->

<%= turbo_frame_tag dom_id(@product, :edit) do %>
  <%= render "form", product: @product %>
<% end %>
<!-- Generates: <turbo-frame id="edit_product_123"> -->
```

## Inline Editing Pattern

**Index page:**

```erb
<% @products.each do |product| %>
  <%= turbo_frame_tag dom_id(product) do %>
    <div>
      <h3><%= product.name %></h3>
      <p><%= product.description %></p>
      <%= link_to "Edit", edit_product_path(product) %>
    </div>
  <% end %>
<% end %>
```

**Edit page:**

```erb
<%= turbo_frame_tag dom_id(@product) do %>
  <%= form_with model: @product do |f| %>
    <%= f.text_field :name %>
    <%= f.text_area :description %>
    <%= f.submit %>
  <% end %>
<% end %>
```

**Controller:**

```ruby
def update
  @product = Product.find(params[:id])

  if @product.update(product_params)
    redirect_to products_path  # Turbo will update the frame
  else
    render :edit, status: :unprocessable_entity
  end
end
```

Flow:
1. Click "Edit" → Edit form appears in frame
2. Submit form → Form submits via Turbo
3. Success → Redirects to index, frame shows updated product
4. Failure → Form re-renders with errors in frame

## Lazy Loading

Load content when frame appears:

```erb
<%= turbo_frame_tag "expensive_content", src: expensive_path, loading: :lazy do %>
  <p>Loading...</p>
<% end %>
```

Frame loads automatically when scrolled into view. Perfect for below-the-fold content.

## Targeting Frames

### Target Another Frame

```erb
<!-- In frame A -->
<%= turbo_frame_tag "frame_a" do %>
  <%= link_to "Update B", update_path, data: { turbo_frame: "frame_b" } %>
<% end %>

<!-- Frame B -->
<%= turbo_frame_tag "frame_b" do %>
  <!-- Updated by link in frame A -->
<% end %>
```

### Target Multiple Frames

Use Turbo Streams for multiple updates (see turbo-streams.md).

### Target the Page

```erb
<%= link_to "Products", products_path, data: { turbo_frame: "_top" } %>
<!-- Navigates the whole page, not just the frame -->
```

## Frame Response Handling

### Successful Response

Server must return matching frame:

```erb
<!-- Request from: <turbo-frame id="product_123"> -->
<!-- Response must include: -->
<%= turbo_frame_tag "product_123" do %>
  <!-- Updated content -->
<% end %>
```

Mismatched IDs? Turbo ignores the response.

### Error Handling

```ruby
def update
  if @product.update(product_params)
    redirect_to @product
  else
    render :edit, status: :unprocessable_entity  # Status important!
  end
end
```

Turbo displays errors in the frame when status is 4xx/5xx.

## Advanced Patterns

### Pagination in Frames

```erb
<%= turbo_frame_tag "products", src: products_path(page: 1) do %>
  <div id="product-list">
    <%= render @products %>
  </div>

  <%= link_to "Next Page", products_path(page: params[:page].to_i + 1), data: { turbo_frame: "products" } %>
<% end %>
```

### Modal Windows

```erb
<!-- Anywhere on page -->
<%= turbo_frame_tag "modal" %>

<!-- Link opens form in modal -->
<%= link_to "New Product", new_product_path, data: { turbo_frame: "modal" } %>
```

```erb
<!-- app/views/products/new.html.erb -->
<%= turbo_frame_tag "modal" do %>
  <div class="modal">
    <h2>New Product</h2>
    <%= form_with model: @product %>
    <%= link_to "Close", products_path, data: { turbo_frame: "modal" } %>
  </div>
<% end %>
```

### Drawer/Sidebar

```erb
<div class="layout">
  <aside>
    <%= turbo_frame_tag "sidebar" %>
  </aside>

  <main>
    <%= yield %>
  </main>
</div>

<!-- Links update sidebar -->
<%= link_to "Details", product_details_path(@product), data: { turbo_frame: "sidebar" } %>
```

## Performance Considerations

### Eager Loading in Frame Responses

```ruby
def show
  @product = Product.includes(:category, :reviews).find(params[:id])
  # Prevent N+1 in partial
end
```

### Minimal Frame Content

Keep frame responses small:

```ruby
# Don't send full layout in frame response
class ProductsController < ApplicationController
  layout :determine_layout

  private

  def determine_layout
    turbo_frame_request? ? false : "application"
  end
end
```

Rails 7+ handles this automatically for Turbo Frame requests.

### Cache Frame Content

```erb
<%= turbo_frame_tag dom_id(@product) do %>
  <% cache @product do %>
    <%= render @product %>
  <% end %>
<% end %>
```

## Troubleshooting

### Frame Not Updating

1. **ID mismatch**: Request frame ID must match response frame ID
2. **Missing frame in response**: Response must include matching frame
3. **JavaScript errors**: Check browser console
4. **Form errors**: Ensure proper status codes (422 for validation errors)

### Frame Shows "Content missing"

Response didn't include a matching `<turbo-frame>`. Check:
- Frame IDs match exactly
- Response isn't redirecting unexpectedly
- Controller renders appropriate format

### Navigation Breaks Frame

Link has `data-turbo-frame="_top"` or form has `data-turbo="false"`. Remove these to keep navigation in frame.

## Best Practices

1. **Use dom_id** for consistent frame naming
2. **Keep frames focused** - single responsibility
3. **Match frame IDs** exactly in requests/responses
4. **Handle errors** with appropriate status codes
5. **Use lazy loading** for below-the-fold content
6. **Cache frame content** when possible
7. **Limit frame nesting** - flat structures work better
8. **Test frame interactions** thoroughly
9. **Use _top** sparingly - only when full page navigation needed
10. **Provide loading states** for slow frames

Turbo Frames enable complex interactions with simple, server-rendered HTML. Master them and you'll build features that feel like SPAs without the SPA complexity.
