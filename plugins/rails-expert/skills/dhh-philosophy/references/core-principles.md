# Core Rails Principles: DRY and Convention Over Configuration

## Don't Repeat Yourself (DRY)

DRY is one of the most fundamental principles in Rails. It states: "Every piece of knowledge must have a single, unambiguous, authoritative representation within a system."

### What DRY Means in Practice

**Anti-Pattern (Not DRY):**
```ruby
# Model file
class User < ApplicationRecord
  attr_accessor :name, :email, :age  # Redundant!
end

# Multiple places defining validation rules
# Controller
def create
  if params[:email].include?('@')
    # ...
  end
end

# Model
validates :email, format: { with: /@/ }
```

**Rails Way (DRY):**
```ruby
# Model file
class User < ApplicationRecord
  # Attributes come from schema - no declaration needed
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end

# Controller trusts the model
def create
  @user = User.new(user_params)
  if @user.save  # Validations handled by model
    # ...
  end
end
```

### DRY in Database Schema

Rails derives model attributes from the database schema. The schema is the single source of truth.

```ruby
# db/migrate/20240101000000_create_users.rb
class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.integer :age
      t.timestamps
    end
  end
end

# app/models/user.rb
class User < ApplicationRecord
  # name, email, age, created_at, updated_at all available automatically!
  # No attr_accessor needed
end
```

After running `rails db:migrate`, your User model knows about all columns without declaring them.

### DRY in Routing

RESTful routing eliminates repetitive route definitions:

**Anti-Pattern:**
```ruby
get '/products', to: 'products#index'
get '/products/new', to: 'products#new'
post '/products', to: 'products#create'
get '/products/:id', to: 'products#show'
get '/products/:id/edit', to: 'products#edit'
patch '/products/:id', to: 'products#update'
delete '/products/:id', to: 'products#destroy'
```

**Rails Way:**
```ruby
resources :products  # One line creates all 7 routes
```

### DRY in Views with Partials

Extract repeated view code into partials:

**Anti-Pattern:**
```erb
<!-- index.html.erb -->
<% @products.each do |product| %>
  <div class="product">
    <h2><%= product.name %></h2>
    <p><%= product.description %></p>
    <span><%= number_to_currency(product.price) %></span>
  </div>
<% end %>

<!-- search.html.erb -->
<% @products.each do |product| %>
  <div class="product">  <!-- Same code repeated! -->
    <h2><%= product.name %></h2>
    <p><%= product.description %></p>
    <span><%= number_to_currency(product.price) %></span>
  </div>
<% end %>
```

**Rails Way:**
```erb
<!-- app/views/products/_product.html.erb -->
<div class="product">
  <h2><%= product.name %></h2>
  <p><%= product.description %></p>
  <span><%= number_to_currency(product.price) %></span>
</div>

<!-- index.html.erb -->
<%= render @products %>  <!-- Rails finds _product.html.erb automatically -->

<!-- search.html.erb -->
<%= render @products %>  <!-- Same partial, no duplication -->
```

### DRY with Concerns

Extract shared behavior into concerns:

```ruby
# app/models/concerns/commentable.rb
module Commentable
  extend ActiveSupport::Concern

  included do
    has_many :comments, as: :commentable, dependent: :destroy
  end

  def recent_comments(limit = 5)
    comments.order(created_at: :desc).limit(limit)
  end
end

# app/models/post.rb
class Post < ApplicationRecord
  include Commentable  # Gains all Commentable behavior
end

# app/models/product.rb
class Product < ApplicationRecord
  include Commentable  # Same behavior, no duplication
end
```

### DRY in Controllers with Before Actions

```ruby
class ProductsController < ApplicationController
  before_action :set_product, only: [:show, :edit, :update, :destroy]
  before_action :authorize_user, only: [:edit, :update, :destroy]

  def show
    # @product already set by before_action
  end

  def edit
    # @product already set, user already authorized
  end

  def update
    # @product already set, user already authorized
    if @product.update(product_params)
      redirect_to @product
    else
      render :edit
    end
  end

  def destroy
    # @product already set, user already authorized
    @product.destroy
    redirect_to products_path
  end

  private

  def set_product
    @product = Product.find(params[:id])  # Single source of truth
  end

  def authorize_user
    redirect_to root_path unless current_user.can_edit?(@product)
  end

  def product_params
    params.require(:product).permit(:name, :price)
  end
end
```

## Convention Over Configuration

Rails favors conventions that eliminate the need for configuration files. Learn the conventions, and your code "just works."

### File Structure Conventions

Rails file structure is predictable and meaningful:

```
app/
├── controllers/
│   └── products_controller.rb     # ProductsController
├── models/
│   └── product.rb                 # Product model
├── views/
│   └── products/                  # ProductsController views
│       ├── index.html.erb         # index action view
│       ├── show.html.erb          # show action view
│       └── _product.html.erb      # product partial
```

This structure means:
- `ProductsController` automatically finds views in `app/views/products/`
- Partials start with `_` and are rendered without it: `render 'product'`
- Layouts live in `app/views/layouts/application.html.erb`

No configuration needed—Rails knows where everything is.

### Naming Conventions

Rails uses consistent naming patterns:

| Element | Convention | Example |
|---------|-----------|---------|
| Model | Singular, CamelCase | `Product`, `OrderItem` |
| Table | Plural, snake_case | `products`, `order_items` |
| Controller | Plural, CamelCase + "Controller" | `ProductsController` |
| Foreign Key | Singular model + "_id" | `user_id`, `product_id` |
| Join Table | Both models, alphabetical, plural | `orders_products` |
| Primary Key | Always `id` | `products.id` |

With these conventions:

```ruby
class Product < ApplicationRecord
  belongs_to :category  # Rails looks for category_id column
  has_many :reviews     # Rails looks for product_id in reviews table
end
```

Rails infers:
- `Product` maps to `products` table
- `category` association needs `category_id` column
- `reviews` association finds `product_id` in `reviews` table

### RESTful Route Conventions

Rails defaults to RESTful routing patterns:

```ruby
# config/routes.rb
resources :products
```

Generates:

| HTTP Verb | Path | Controller#Action | Purpose |
|-----------|------|-------------------|---------|
| GET | /products | products#index | List all products |
| GET | /products/new | products#new | Form to create product |
| POST | /products | products#create | Create product |
| GET | /products/:id | products#show | Show specific product |
| GET | /products/:id/edit | products#edit | Form to edit product |
| PATCH/PUT | /products/:id | products#update | Update product |
| DELETE | /products/:id | products#destroy | Delete product |

Plus path helpers:
- `products_path` → `/products`
- `new_product_path` → `/products/new`
- `product_path(@product)` → `/products/123`
- `edit_product_path(@product)` → `/products/123/edit`

### Controller Action Conventions

Standard CRUD actions follow a pattern:

```ruby
class ProductsController < ApplicationController
  def index
    @products = Product.all
    # Renders app/views/products/index.html.erb automatically
  end

  def show
    @product = Product.find(params[:id])
    # Renders app/views/products/show.html.erb automatically
  end

  def new
    @product = Product.new
    # Renders app/views/products/new.html.erb automatically
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      redirect_to @product  # Convention: redirect to show action
    else
      render :new  # Convention: re-render form with errors
    end
  end

  def edit
    @product = Product.find(params[:id])
    # Renders app/views/products/edit.html.erb automatically
  end

  def update
    @product = Product.find(params[:id])
    if @product.update(product_params)
      redirect_to @product
    else
      render :edit
    end
  end

  def destroy
    @product = Product.find(params[:id])
    @product.destroy
    redirect_to products_path  # Convention: redirect to index
  end

  private

  def product_params
    params.require(:product).permit(:name, :price)
  end
end
```

Rails automatically renders views matching controller actions. Explicit `render` only needed when deviating from convention.

### Database Column Conventions

Certain column names have special meaning:

- `id`: Primary key (always auto-generated)
- `created_at`: Automatically set on create
- `updated_at`: Automatically updated on save
- `{model}_id`: Foreign key for belongs_to association
- `type`: Single Table Inheritance (STI) discriminator
- `{association}_type`: Polymorphic association type
- `{association}_id`: Polymorphic association ID
- `lock_version`: Optimistic locking counter

```ruby
# Migration
create_table :posts do |t|
  t.string :title
  t.text :body
  t.references :user  # Creates user_id column
  t.timestamps        # Creates created_at and updated_at
end

# Model gets automatic behavior
class Post < ApplicationRecord
  belongs_to :user  # Uses user_id automatically
  # created_at and updated_at managed automatically
end
```

### Form Conventions

Rails form helpers use conventions to reduce configuration:

```erb
<%# app/views/products/new.html.erb %>
<%= form_with model: @product do |f| %>
  <%# Rails determines:
      - POST to /products (new record)
      - PATCH to /products/:id (existing record)
      - Form ID and class based on model
  %>

  <%= f.label :name %>
  <%= f.text_field :name %>

  <%= f.label :price %>
  <%= f.number_field :price %>

  <%= f.submit %>  <%# Button text: "Create Product" or "Update Product" %>
<% end %>
```

Rails infers:
- Form submits to `products_path` for new records
- Form submits to `product_path(@product)` for existing records
- Submit button says "Create Product" or "Update Product"
- Form parameters nested under `product` key

### Configuration When Needed

Conventions are defaults, not restrictions. Configure when necessary:

```ruby
# Custom table name
class Product < ApplicationRecord
  self.table_name = "inventory_items"
end

# Custom primary key
class Product < ApplicationRecord
  self.primary_key = "sku"
end

# Custom foreign key
class Order < ApplicationRecord
  belongs_to :customer, class_name: "User", foreign_key: "buyer_id"
end

# Custom route
resources :products do
  member do
    post :duplicate
  end
  collection do
    get :search
  end
end
```

## Benefits of DRY and Convention Over Configuration

### Faster Development

Less code to write means faster implementation:
- Generators create conventional boilerplate
- Migrations handle schema changes
- Routes defined in one line
- Views automatically render

### Easier Maintenance

Single source of truth makes changes easier:
- Update schema once, all models reflect changes
- Change routing convention, all URLs update
- Modify partial once, all usages update

### Better Onboarding

New developers learn conventions once, apply everywhere:
- Predictable file locations
- Consistent naming
- Standard patterns across codebases
- Less project-specific knowledge needed

### Fewer Bugs

Conventions eliminate classes of errors:
- Typos in configuration files
- Mismatched names between files
- Forgotten route definitions
- Inconsistent file structures

### Shared Understanding

Rails developers worldwide use same conventions:
- Code reviews easier
- Open source contributions smoother
- Team transitions faster
- Documentation applies universally

## When to Break Conventions

Conventions optimize for common cases. Break them when:

1. **Legacy Database**: Existing schema doesn't match conventions
2. **Domain Language**: Business terminology conflicts with Rails naming
3. **Performance**: Convention creates inefficiency
4. **External Integration**: Third-party systems dictate structure
5. **Genuine Improvement**: You have a better approach for your specific case

But break thoughtfully—fighting conventions creates friction.

## Embracing Conventions

To work effectively with Rails:

1. **Learn conventions first** before customizing
2. **Trust the defaults** until they fail you
3. **Use generators** to see conventional code
4. **Follow the Rails Guides** for standard approaches
5. **Review established Rails apps** to see conventions in practice

Rails conventions represent thousands of collective hours of experience. Respect that wisdom.
