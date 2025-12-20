# Advanced Routing Patterns in Rails

## Route Constraints

Constraints restrict which routes match based on request properties.

### Parameter Format Constraints

Ensure parameters match specific patterns:

```ruby
# Only match numeric IDs
resources :products, constraints: { id: /\d+/ }

# Only match alphanumeric slugs
resources :articles, constraints: { id: /[A-Za-z0-9\-]+/ }

# Match specific formats
resources :products, constraints: { format: /json|xml/ }
```

### Subdomain Constraints

Route based on subdomain:

```ruby
# API on api.example.com
constraints(subdomain: 'api') do
  namespace :api do
    resources :products
  end
end

# Admin on admin.example.com
constraints(subdomain: 'admin') do
  namespace :admin do
    resources :products
  end
end

# Wildcard subdomains
constraints(subdomain: /.+/) do
  # Matches any subdomain
end
```

### Custom Constraint Classes

Create reusable constraint logic:

```ruby
# lib/constraints/api_constraint.rb
class ApiConstraint
  def initialize(version:, default: false)
    @version = version
    @default = default
  end

  def matches?(request)
    @default || request.headers['Accept']&.include?("application/vnd.myapp.v#{@version}")
  end
end

# config/routes.rb
require 'constraints/api_constraint'

Rails.application.routes.draw do
  namespace :api do
    scope module: :v1, constraints: ApiConstraint.new(version: 1, default: true) do
      resources :products
    end

    scope module: :v2, constraints: ApiConstraint.new(version: 2) do
      resources :products
    end
  end
end
```

### Request-Based Constraints

Route based on request properties:

```ruby
# Only AJAX requests
constraints(lambda { |req| req.xhr? }) do
  resources :products
end

# Only specific user agents
constraints(lambda { |req| req.user_agent =~ /iPhone/ }) do
  get 'mobile', to: 'mobile#index'
end

# IP address constraints
constraints(ip: /192\.168\.1\.\d+/) do
  get 'admin', to: 'admin#index'
end
```

## Advanced Resource Routing

### Shallow Nesting

Avoid deep URL nesting for member routes:

```ruby
resources :articles do
  resources :comments, shallow: true
end
```

Generates:
- `/articles/1/comments` (collection, needs article context)
- `/articles/1/comments/new` (new, needs article context)
- `/comments/5` (show, doesn't need article)
- `/comments/5/edit` (edit, doesn't need article)

Benefits:
- Shorter URLs
- Easier to work with
- More RESTful

### Only and Except

Limit generated routes:

```ruby
# Only specific actions
resources :photos, only: [:index, :show]

# All except certain actions
resources :photos, except: [:destroy]
```

### Path and Module Options

Customize URLs and controller locations:

```ruby
# Custom URL path
resources :products, path: 'items'
# URLs: /items, /items/1, etc.
# Controllers: ProductsController

# Custom module
resources :products, module: 'shop'
# URLs: /products
# Controllers: Shop::ProductsController

# Both
resources :products, path: 'items', module: 'shop'
# URLs: /items
# Controllers: Shop::ProductsController
```

### Namespaced Routes

Organize routes by module:

```ruby
namespace :admin do
  resources :products
end
# URLs: /admin/products
# Controllers: Admin::ProductsController
# Helpers: admin_products_path

# Scope without URL prefix
scope module: 'admin' do
  resources :products
end
# URLs: /products
# Controllers: Admin::ProductsController
# Helpers: products_path

# Scope with URL but no module
scope '/admin' do
  resources :products
end
# URLs: /admin/products
# Controllers: ProductsController (not namespaced!)
# Helpers: products_path
```

### Concerns

Extract common routing patterns:

```ruby
concern :commentable do
  resources :comments
end

concern :image_attachable do
  resources :images, only: [:index, :create, :destroy]
end

resources :articles, concerns: [:commentable, :image_attachable]
resources :photos, concerns: :commentable
# Articles get comments and images routes
# Photos get only comments routes
```

## Member and Collection Routes

### Member Routes

Act on a specific resource:

```ruby
resources :products do
  member do
    get :preview
    post :duplicate
    patch :publish
  end
end

# Shorthand
resources :products do
  get :preview, on: :member
end
```

Generates:
- `GET /products/1/preview` → `products#preview`
- `POST /products/1/duplicate` → `products#duplicate`
- Helper: `preview_product_path(@product)`

### Collection Routes

Act on the collection:

```ruby
resources :products do
  collection do
    get :search
    post :bulk_update
  end
end

# Shorthand
resources :products do
  get :search, on: :collection
end
```

Generates:
- `GET /products/search` → `products#search`
- `POST /products/bulk_update` → `products#bulk_update`
- Helper: `search_products_path`

## Non-RESTful Routes

### Simple Routes

```ruby
get 'about', to: 'pages#about'
get 'contact', to: 'pages#contact'
post 'contact', to: 'pages#send_contact'
```

### Root Route

```ruby
root 'home#index'
root to: 'home#index'  # Same thing
```

### Match with Multiple Verbs

```ruby
match 'search', to: 'search#query', via: [:get, :post]
match 'search', to: 'search#query', via: :all  # All verbs (dangerous!)
```

### Redirect Routes

```ruby
# Simple redirect
get '/old-path', to: redirect('/new-path')

# Dynamic redirect
get '/users/:id', to: redirect { |path_params, req|
  "/profiles/#{path_params[:id]}"
}

# Status code
get '/old-path', to: redirect('/new-path', status: 301)  # Permanent
```

## Route Globbing

Capture multiple URL segments:

```ruby
get 'files/*path', to: 'files#show'
# Matches: /files/images/logo.png
# params[:path] = "images/logo.png"

get 'photos/*other', to: 'photos#unknown'
# Catch-all for unmatched photo routes
```

## Default URL Options

Set defaults for all routes:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  default_url_options host: 'example.com', protocol: 'https'

  resources :products
end
```

## Route Testing

List all routes:

```bash
bin/rails routes
bin/rails routes | grep product
bin/rails routes -c products  # Only ProductsController routes
bin/rails routes -g new        # Routes matching "new"
```

Test routes in console:

```ruby
# Rails console
Rails.application.routes.url_helpers.products_path
# => "/products"

# Recognize path
Rails.application.routes.recognize_path("/products/1")
# => {:controller=>"products", :action=>"show", :id=>"1"}
```

## Route Performance

### Optimize Route Matching

```ruby
# SLOW: Extensive regex matching on every request
get '*path', to: 'application#not_found', constraints: { path: /very|complex|regex/ }

# FAST: Simple, specific routes
get 'about', to: 'pages#about'
get 'contact', to: 'pages#contact'
```

### Disable Unused Routes

```ruby
resources :products, only: [:index, :show]
# Faster than generating all 7 routes when you only need 2
```

## Route Organization

### Group Related Routes

```ruby
Rails.application.routes.draw do
  # Public routes
  root 'home#index'
  resources :products, only: [:index, :show]

  # Authenticated routes
  authenticated :user do
    resources :orders
    resource :profile
  end

  # Admin routes
  namespace :admin do
    resources :products
    resources :users
  end

  # API routes
  namespace :api do
    namespace :v1 do
      resources :products
    end
  end
end
```

### Extract Route Files

For large applications:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  draw(:api)
  draw(:admin)

  # Public routes here
end

# config/routes/api.rb
namespace :api do
  namespace :v1 do
    resources :products
  end
end

# config/routes/admin.rb
namespace :admin do
  resources :products
  resources :users
end
```

## Security Considerations

### Disable Unused HTTP Verbs

```ruby
# Only allow safe verbs
resources :products, only: [:index, :show]

# Explicitly define what's allowed
resources :products do
  member do
    get :preview    # Safe
    delete :purge   # Explicitly allowed destruction
  end
end
```

### CSRF Protection

Rails automatically protects non-GET requests with CSRF tokens. For API routes:

```ruby
# Disable CSRF for API
class ApiController < ActionController::Base
  skip_before_action :verify_authenticity_token
end
```

## Best Practices

1. **Use RESTful routes** whenever possible
2. **Limit nesting** to 1 level (use shallow nesting)
3. **Be specific** with `only:` and `except:`
4. **Name custom actions clearly** (avoid generic names like `process`)
5. **Group related routes** for maintainability
6. **Test routes** with `bin/rails routes`
7. **Use constraints** for validation, not business logic
8. **Keep routes.rb organized** - extract large route files
9. **Prefer conventions** over custom routes
10. **Document unusual routes** with comments

Master these patterns and you'll handle any routing scenario Rails throws at you.
