# Active Record Associations: Complete Guide

## Overview

Associations define relationships between models. They enable clean, expressive code for querying related data without writing complex SQL joins.

Rails provides six types of associations:
- `belongs_to` - Foreign key in this table
- `has_one` - Foreign key in other table (one-to-one)
- `has_many` - Foreign key in other table (one-to-many)
- `has_many :through` - Many-to-many through join model
- `has_one :through` - One-to-one through intermediary
- `has_and_belongs_to_many` - Many-to-many without join model

## belongs_to

Declares that this model has a foreign key referencing another model.

### Basic Usage

```ruby
class Product < ApplicationRecord
  belongs_to :category
  # Expects: category_id column in products table
  # Provides: product.category, product.category=, product.build_category, etc.
end

# Usage:
product = Product.find(1)
product.category  # => Category object
product.category.name  # => "Electronics"

# Assignment:
product.category = Category.first
product.category_id = 5

# Building:
product.build_category(name: "New Category")
product.create_category(name: "New Category")  # Saves immediately
```

### Options

```ruby
class Product < ApplicationRecord
  # Custom foreign key
  belongs_to :author, class_name: "User", foreign_key: "creator_id"

  # Optional (Rails 5+ requires belongs_to by default)
  belongs_to :supplier, optional: true

  # Counter cache (updates supplier.products_count automatically)
  belongs_to :supplier, counter_cache: true

  # Polymorphic (belongs to multiple model types)
  belongs_to :commentable, polymorphic: true

  # Custom primary key
  belongs_to :category, primary_key: "slug", foreign_key: "category_slug"

  # Dependent destroy (when product destroyed, destroy associated record too)
  belongs_to :draft, dependent: :destroy

  # Touch (updates parent's updated_at when this changes)
  belongs_to :category, touch: true

  # Validation
  belongs_to :category, required: true  # Same as not optional
end
```

### Methods Provided

```ruby
product.category          # Returns associated category
product.category=(cat)    # Assigns category
product.build_category    # Builds new category (not saved)
product.create_category   # Creates and saves new category
product.create_category!  # Creates or raises error
product.reload_category   # Reloads from database
```

## has_one

Declares a one-to-one relationship where the foreign key is in the other table.

### Basic Usage

```ruby
class User < ApplicationRecord
  has_one :profile
  # Expects: user_id column in profiles table
  # Provides: user.profile, user.profile=, user.build_profile, etc.
end

# Usage:
user = User.find(1)
user.profile  # => Profile object
user.profile.bio  # => "Software developer"

# Building:
user.build_profile(bio: "New bio")
user.create_profile(bio: "New bio")  # Saves immediately
```

### Options

```ruby
class User < ApplicationRecord
  # Custom foreign key and class
  has_one :account, class_name: "BillingAccount", foreign_key: "owner_id"

  # Dependent (when user destroyed, what happens to profile?)
  has_one :profile, dependent: :destroy  # Destroy profile
  has_one :profile, dependent: :delete   # Delete profile (no callbacks)
  has_one :profile, dependent: :nullify  # Set user_id to NULL

  # Through another association
  has_one :profile, through: :account

  # As (polymorphic)
  has_one :image, as: :imageable

  # Source (for through associations)
  has_one :avatar, through: :profile, source: :image

  # Validation
  has_one :profile, required: true
end
```

## has_many

Declares a one-to-many relationship where the foreign key is in the other table.

### Basic Usage

```ruby
class Category < ApplicationRecord
  has_many :products
  # Expects: category_id column in products table
  # Provides: category.products, category.products<<, etc.
end

# Usage:
category = Category.find(1)
category.products  # => [#<Product...>, #<Product...>]
category.products.size  # => 10
category.products.where(available: true)  # Chainable

# Building and creating:
category.products.build(name: "New Product")  # Not saved
category.products.create(name: "New Product")  # Saved
category.products << Product.find(5)  # Add existing product
```

### Options

```ruby
class Category < ApplicationRecord
  # Custom foreign key and class
  has_many :items, class_name: "Product", foreign_key: "category_id"

  # Dependent (when category destroyed)
  has_many :products, dependent: :destroy    # Destroy all products
  has_many :products, dependent: :delete_all # Delete all (no callbacks)
  has_many :products, dependent: :nullify    # Set category_id to NULL
  has_many :products, dependent: :restrict_with_error  # Raise error if products exist

  # Order
  has_many :products, -> { order(created_at: :desc) }
  has_many :recent_products, -> { where('created_at > ?', 1.week.ago).order(created_at: :desc) }

  # Limit
  has_many :top_products, -> { order(sales: :desc).limit(10) }, class_name: "Product"

  # Conditions
  has_many :available_products, -> { where(available: true) }, class_name: "Product"

  # Counter cache
  has_many :products, counter_cache: true  # Updates categories.products_count

  # Through
  has_many :products, through: :category_products

  # Source (for through)
  has_many :items, through: :category_products, source: :product

  # As (polymorphic)
  has_many :comments, as: :commentable

  # Inverse of
  has_many :products, inverse_of: :category
end
```

### Methods Provided

```ruby
category.products             # Returns collection
category.products<<(product)  # Appends product
category.products.delete(product)  # Removes product
category.products.destroy(product) # Destroys product
category.products.clear       # Removes all
category.products.empty?      # true if none
category.products.size        # Count
category.products.find(1)     # Find within collection
category.products.where(...)  # Query within collection
category.products.build       # Build new
category.products.create      # Create new
category.products.create!     # Create or raise
category.product_ids          # Array of IDs
category.product_ids=(ids)    # Replace with these IDs
```

## has_many :through

Many-to-many relationship through a join model.

### Basic Usage

```ruby
class Order < ApplicationRecord
  has_many :line_items
  has_many :products, through: :line_items
end

class LineItem < ApplicationRecord
  belongs_to :order
  belongs_to :product
end

class Product < ApplicationRecord
  has_many :line_items
  has_many :orders, through: :line_items
end

# Usage:
order = Order.find(1)
order.products  # All products in this order
order.products << Product.find(5)  # Adds product via new line_item

product = Product.find(1)
product.orders  # All orders containing this product
```

### Accessing Join Model

```ruby
order.line_items  # Access join records
order.line_items.where(quantity: 5)
order.line_items.create(product: product, quantity: 2, price: 9.99)
```

### Options

```ruby
class Order < ApplicationRecord
  has_many :line_items
  has_many :products, through: :line_items

  # Custom source
  has_many :items, through: :line_items, source: :product

  # With conditions on through
  has_many :active_products, through: :line_items, source: :product, -> { where(available: true) }

  # Source type (for polymorphic)
  has_many :sellers, through: :line_items, source: :sellable, source_type: "User"
end
```

### Nested Through

```ruby
class Supplier < ApplicationRecord
  has_many :products
  has_many :orders, through: :products
  has_many :customers, through: :orders  # Nested through!
end
```

## has_and_belongs_to_many

Simple many-to-many without a join model.

### Basic Usage

```ruby
class Product < ApplicationRecord
  has_and_belongs_to_many :tags
end

class Tag < ApplicationRecord
  has_and_belongs_to_many :products
end

# Migration for join table:
create_table :products_tags, id: false do |t|
  t.belongs_to :product
  t.belongs_to :tag
end

# Usage:
product = Product.find(1)
product.tags  # => [#<Tag...>, #<Tag...>]
product.tags << Tag.find(5)
product.tag_ids = [1, 2, 3]
```

### Options

```ruby
class Product < ApplicationRecord
  # Custom join table
  has_and_belongs_to_many :tags, join_table: "categorizations"

  # Custom foreign keys
  has_and_belongs_to_many :tags,
    join_table: "product_tags",
    foreign_key: "product_id",
    association_foreign_key: "tag_id"

  # With conditions
  has_and_belongs_to_many :active_tags,
    -> { where(active: true) },
    class_name: "Tag"
end
```

**When to use:** Simple many-to-many with no extra data on the relationship.
**When not to use:** If you need attributes on the join (use `has_many :through` instead).

## Polymorphic Associations

One model belongs to multiple model types.

### Basic Setup

```ruby
# Migration
create_table :comments do |t|
  t.text :body
  t.references :commentable, polymorphic: true  # Creates commentable_id and commentable_type
  t.timestamps
end

# Model
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
end

class Post < ApplicationRecord
  has_many :comments, as: :commentable
end

class Product < ApplicationRecord
  has_many :comments, as: :commentable
end

# Usage:
post = Post.find(1)
post.comments.create(body: "Great post!")

product = Product.find(1)
product.comments.create(body: "Love this product!")

comment = Comment.first
comment.commentable  # Returns Post or Product
comment.commentable_type  # => "Post" or "Product"
comment.commentable_id  # => 1
```

### Querying Polymorphic

```ruby
# Find all comments for posts
Comment.where(commentable_type: "Post")

# Eager load polymorphic
comments = Comment.includes(:commentable).all
comments.each do |comment|
  puts comment.commentable.class  # No N+1 query
end
```

## Self-Referential Associations

Models that reference themselves.

### Example: Employee Hierarchy

```ruby
class Employee < ApplicationRecord
  belongs_to :manager, class_name: "Employee", optional: true
  has_many :subordinates, class_name: "Employee", foreign_key: "manager_id"
end

# Usage:
ceo = Employee.find(1)
ceo.subordinates  # Direct reports

employee = Employee.find(10)
employee.manager  # Boss
employee.manager.manager  # Boss's boss
```

### Example: Following System

```ruby
# Migration
create_table :follows do |t|
  t.integer :follower_id, null: false
  t.integer :followee_id, null: false
  t.timestamps
end

add_index :follows, [:follower_id, :followee_id], unique: true

# Models
class User < ApplicationRecord
  has_many :follower_relationships, class_name: "Follow", foreign_key: "followee_id"
  has_many :followers, through: :follower_relationships, source: :follower

  has_many :followee_relationships, class_name: "Follow", foreign_key: "follower_id"
  has_many :following, through: :followee_relationships, source: :followee
end

class Follow < ApplicationRecord
  belongs_to :follower, class_name: "User"
  belongs_to :followee, class_name: "User"
end

# Usage:
user = User.find(1)
user.followers  # Users following this user
user.following  # Users this user follows

user.following << User.find(5)  # Follow someone
```

## Advanced Patterns

### Bi-Directional Associations

Ensure Rails knows both sides of an association:

```ruby
class User < ApplicationRecord
  has_many :posts, inverse_of: :author
end

class Post < ApplicationRecord
  belongs_to :author, class_name: "User", inverse_of: :posts
end
```

Benefits:
- Single object identity (both sides reference same object)
- Automatic inverse assignment
- Better validation

### Callbacks on Associations

```ruby
class Category < ApplicationRecord
  has_many :products,
    before_add: :check_limit,
    after_add: :update_cache,
    before_remove: :check_if_removable,
    after_remove: :clear_cache

  private

  def check_limit(product)
    raise "Category full" if products.count >= 100
  end

  def update_cache(product)
    Rails.cache.delete("category_#{id}_products")
  end

  def check_if_removable(product)
    raise "Can't remove featured product" if product.featured?
  end

  def clear_cache(product)
    Rails.cache.delete("category_#{id}_products")
  end
end
```

### Extensions

Add methods to associations:

```ruby
class User < ApplicationRecord
  has_many :posts do
    def published
      where(published: true)
    end

    def recent(limit = 5)
      order(created_at: :desc).limit(limit)
    end
  end
end

# Usage:
user.posts.published
user.posts.recent(10)
```

### Scopes on Associations

```ruby
class Category < ApplicationRecord
  has_many :products
  has_many :available_products, -> { where(available: true) }, class_name: "Product"
  has_many :expensive_products, -> { where("price > ?", 100) }, class_name: "Product"
  has_many :recent_products, -> { where('created_at > ?', 1.week.ago).order(created_at: :desc) }, class_name: "Product"
end
```

## Association Caching

### Counter Caches

Automatically maintain count columns:

```ruby
# Migration
add_column :categories, :products_count, :integer, default: 0

# Model
class Product < ApplicationRecord
  belongs_to :category, counter_cache: true
end

# Usage:
category.products_count  # No query! Reads from column
```

Reset counter cache:

```bash
Category.find_each { |c| Category.reset_counters(c.id, :products) }
```

### Touch

Update parent's `updated_at` when child changes:

```ruby
class Product < ApplicationRecord
  belongs_to :category, touch: true
end

product.update(name: "New Name")
# Also updates category.updated_at
```

## Querying Associations

### Joining

```ruby
# Inner join
Product.joins(:category)
Product.joins(:category, :tags)

# With conditions
Product.joins(:category).where(categories: { name: "Electronics" })

# Multiple levels
Order.joins(line_items: :product)
Order.joins(line_items: { product: :category })
```

### Eager Loading

```ruby
# Preload (separate queries)
products = Product.preload(:category, :tags)

# Includes (automatic strategy)
products = Product.includes(:category, :tags)

# Eager load (LEFT OUTER JOIN)
products = Product.eager_load(:category, :tags)

# Nested
orders = Order.includes(line_items: { product: :category })
```

### Association Queries

```ruby
# Query through association
category.products.where(available: true)
category.products.order(price: :desc)

# Existence
Product.where.missing(:category)  # Products without category
Product.where.associated(:reviews)  # Products with reviews
```

## Best Practices

1. **Use inverse_of** for bi-directional associations
2. **Add counter_cache** for frequently counted associations
3. **Eager load** to prevent N+1 queries
4. **Use has_many :through** instead of HABTM for flexibility
5. **Add indexes** on foreign keys
6. **Use dependent:** to clean up associated records
7. **Validate presence** of required associations
8. **Prefer scopes** over conditions in associations
9. **Use touch:** to invalidate caches
10. **Test associations** thoroughly

Associations are the heart of relational data in Rails. Master them, and you master Rails data modeling.
