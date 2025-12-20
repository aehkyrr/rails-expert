# Convention Over Configuration: Real-World Examples
#
# This file demonstrates how Rails conventions eliminate configuration
# and reduce code through smart defaults.

# ==============================================================================
# Example 1: Model to Table Mapping
# ==============================================================================

# Convention: Model name (singular) maps to table name (plural)
class Product < ApplicationRecord
  # No configuration needed!
  # Rails knows:
  # - Table is "products"
  # - Primary key is "id"
  # - Attributes come from table columns
end

# Compare to other frameworks where you'd need:
# @Table(name = "products")
# @Entity
# public class Product {
#   @Id
#   @Column(name = "id")
#   private Long id;
#
#   @Column(name = "name")
#   private String name;
#   // ... repeat for every column
# }

# ==============================================================================
# Example 2: Associations Through Naming
# ==============================================================================

# Convention: Foreign key is {model}_id
class Order < ApplicationRecord
  belongs_to :user      # Rails looks for user_id column
  has_many :line_items  # Rails looks for order_id in line_items table
end

class LineItem < ApplicationRecord
  belongs_to :order    # Rails looks for order_id column
  belongs_to :product  # Rails looks for product_id column
end

# No configuration of foreign keys, join tables, or column names needed!
# Rails infers everything from naming conventions.

# ==============================================================================
# Example 3: RESTful Routes
# ==============================================================================

# In config/routes.rb:
Rails.application.routes.draw do
  resources :products
  # This ONE LINE creates:
  # GET    /products          -> products#index
  # GET    /products/new      -> products#new
  # POST   /products          -> products#create
  # GET    /products/:id      -> products#show
  # GET    /products/:id/edit -> products#edit
  # PATCH  /products/:id      -> products#update
  # DELETE /products/:id      -> products#destroy
  #
  # Plus path helpers:
  # - products_path
  # - new_product_path
  # - product_path(product)
  # - edit_product_path(product)
end

# Compare to manual routing in other frameworks:
# router.get('/products', ProductController.index)
# router.get('/products/new', ProductController.new)
# router.post('/products', ProductController.create)
# router.get('/products/:id', ProductController.show)
# router.get('/products/:id/edit', ProductController.edit)
# router.patch('/products/:id', ProductController.update)
# router.delete('/products/:id', ProductController.destroy)

# ==============================================================================
# Example 4: Controller Actions and View Rendering
# ==============================================================================

class ProductsController < ApplicationController
  def index
    @products = Product.all
    # Rails automatically renders app/views/products/index.html.erb
    # No explicit render statement needed!
  end

  def show
    @product = Product.find(params[:id])
    # Rails automatically renders app/views/products/show.html.erb
  end

  def new
    @product = Product.new
    # Rails automatically renders app/views/products/new.html.erb
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      redirect_to @product  # Convention: redirect to show action
    else
      render :new  # Convention: re-render form with errors
    end
  end

  private

  def product_params
    params.require(:product).permit(:name, :price)
  end
end

# Rails knows:
# - index action renders views/products/index.html.erb
# - show action renders views/products/show.html.erb
# - redirect_to @product goes to product_path(@product)

# ==============================================================================
# Example 5: Form Helpers with Conventions
# ==============================================================================

# In app/views/products/new.html.erb:
#
# <%= form_with model: @product do |f| %>
#   <%= f.label :name %>
#   <%= f.text_field :name %>
#
#   <%= f.label :price %>
#   <%= f.number_field :price %>
#
#   <%= f.submit %>
# <% end %>

# Rails infers:
# - Form posts to /products (new record) or /products/:id (existing)
# - Form method is POST (new) or PATCH (existing)
# - Submit button says "Create Product" or "Update Product"
# - Parameters are nested under params[:product]
# - Form has appropriate HTML classes and IDs

# ==============================================================================
# Example 6: Timestamp Columns
# ==============================================================================

# Convention: created_at and updated_at columns are managed automatically
class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name
      t.decimal :price
      t.timestamps  # Creates created_at and updated_at
    end
  end
end

# Now in your model:
product = Product.create(name: "Widget", price: 9.99)
product.created_at  # => 2024-01-15 10:30:00 UTC
product.updated_at  # => 2024-01-15 10:30:00 UTC

# Update the product
product.update(price: 14.99)
product.updated_at  # => 2024-01-15 10:45:00 UTC (automatically updated!)

# No callbacks or configuration needed!

# ==============================================================================
# Example 7: Partials with Automatic Naming
# ==============================================================================

# Create a partial: app/views/products/_product.html.erb
# <div class="product">
#   <h2><%= product.name %></h2>
#   <p><%= number_to_currency(product.price) %></p>
# </div>

# In index.html.erb, Rails finds the partial automatically:
# <%= render @products %>

# Rails infers:
# - @products is a collection
# - Each item is a Product
# - Partial is at app/views/products/_product.html.erb
# - Local variable is named `product`

# Compare to manual rendering:
# @products.each do |product|
#   render partial: 'products/product', locals: { product: product }
# end

# ==============================================================================
# Example 8: Database Column Type Inference
# ==============================================================================

# Migration automatically infers column types from method names:
class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name          # VARCHAR
      t.text :description     # TEXT
      t.integer :quantity     # INTEGER
      t.decimal :price        # DECIMAL
      t.boolean :available    # BOOLEAN
      t.date :release_date    # DATE
      t.datetime :created_at  # DATETIME
      t.references :category  # INTEGER + INDEX (foreign key)
    end
  end
end

# Rails knows the appropriate SQL type for each column type.
# No manual SQL needed!

# ==============================================================================
# Example 9: Polymorphic Associations with Conventions
# ==============================================================================

# Convention: {association}_type and {association}_id for polymorphic
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  # Rails looks for:
  # - commentable_type (stores class name: "Post" or "Product")
  # - commentable_id (stores record ID)
end

class Post < ApplicationRecord
  has_many :comments, as: :commentable
end

class Product < ApplicationRecord
  has_many :comments, as: :commentable
end

# No configuration of type column or ID column needed!

# ==============================================================================
# Example 10: Single Table Inheritance
# ==============================================================================

# Convention: `type` column enables STI
class Vehicle < ApplicationRecord
  # Base class
end

class Car < Vehicle
  # Inherits from Vehicle
  # Rails automatically sets type = 'Car'
end

class Truck < Vehicle
  # Inherits from Vehicle
  # Rails automatically sets type = 'Truck'
end

# Query for specific types:
Car.all     # WHERE type = 'Car'
Truck.all   # WHERE type = 'Truck'
Vehicle.all # All vehicles

# No configuration needed - Rails sees the `type` column and enables STI!

# ==============================================================================
# Key Takeaways
# ==============================================================================

# Rails conventions eliminate configuration by:
#
# 1. Predictable Naming:
#    - Model: singular, CamelCase
#    - Table: plural, snake_case
#    - Foreign key: {model}_id
#    - Join table: alphabetical_models
#
# 2. Standard Locations:
#    - Models: app/models/
#    - Controllers: app/controllers/
#    - Views: app/views/{controller}/
#    - Migrations: db/migrate/
#
# 3. Automatic Inference:
#    - Attributes from schema
#    - View rendering from action name
#    - Form behavior from record state
#    - Route paths from resources
#
# 4. Smart Defaults:
#    - Primary key: id
#    - Timestamps: created_at, updated_at
#    - STI discriminator: type
#    - Polymorphic: {name}_type, {name}_id
#
# Learn the conventions. Trust them. Ship faster.
