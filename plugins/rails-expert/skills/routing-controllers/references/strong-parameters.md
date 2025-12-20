# Strong Parameters: Security and Rails 8's `expect`

## Why Strong Parameters Exist

Before Rails 4, mass assignment was a critical security vulnerability. Consider:

```ruby
# Rails 3 (VULNERABLE)
def create
  @user = User.new(params[:user])
  @user.save
end
```

An attacker could send:

```
POST /users
user[name]=Hacker&user[admin]=true
```

Result: Hacker creates an admin account!

Rails 4 introduced Strong Parameters to whitelist allowed parameters. Rails 8 improved the API with `expect`.

## Rails 8: params.expect

The new `expect` method is clearer and more explicit than `require(...).permit(...)`:

### Basic Usage

**Old Way (Rails 4-7):**

```ruby
params.require(:product).permit(:name, :price)
```

**New Way (Rails 8):**

```ruby
params.expect(product: [:name, :price])
```

Both allow only `name` and `price` from the `product` hash, but `expect` is more readable.

### expect vs require/permit

| Aspect | `require(...).permit(...)` | `expect(...)` |
|--------|---------------------------|---------------|
| Readability | Verbose, imperative | Concise, declarative |
| Nesting | Clunky with deep nesting | Clean syntax |
| Arrays | `permit(tags: [])` | `expect(product: [tags: []])` |
| Hashes | `permit(metadata: {})` | `expect(product: [metadata: {}])` |
| Default | Still works | Preferred |

### Nested Parameters

```ruby
# Simple nesting
params.expect(product: [:name, :price, category: [:name]])

# Deep nesting
params.expect(
  order: [
    :notes,
    user: [:name, :email],
    line_items: [
      :quantity,
      product: [:id, :name]
    ]
  ]
)
```

### Arrays

Allow array parameters:

```ruby
# Array of simple values
params.expect(product: [:name, tags: []])

# params[:product][:tags] = ["electronics", "sale"]

# Array of hashes
params.expect(
  order: [
    :notes,
    line_items: [
      [:product_id, :quantity]
    ]
  ]
)

# params[:order][:line_items] = [
#   { product_id: 1, quantity: 2 },
#   { product_id: 3, quantity: 1 }
# ]
```

### Hashes with Arbitrary Keys

Allow hashes with unknown keys:

```ruby
# Traditional (requires listing keys)
params.require(:product).permit(:name, metadata: [:color, :size])

# expect with arbitrary keys
params.expect(product: [:name, metadata: {}])

# Allows: { name: "Shirt", metadata: { color: "red", size: "L", material: "cotton" } }
```

## Traditional Strong Parameters (Still Valid)

### require and permit

```ruby
def create
  @product = Product.new(product_params)
  @product.save
end

private

def product_params
  params.require(:product).permit(:name, :price, :description)
end
```

**require** ensures the key exists (raises `ActionController::ParameterMissing` if not)
**permit** whitelists specific attributes

### Nested permit

```ruby
params.require(:product).permit(
  :name,
  :price,
  category: [:name, :description],
  tags: [],
  metadata: {}
)
```

### permit!

Allow all parameters (DANGEROUS):

```ruby
params.require(:product).permit!
# Allows ALL parameters - only use when you control the input!
```

## Common Patterns

### Conditional Permitting

Permit different fields based on context:

```ruby
def product_params
  permitted = [:name, :price, :description]
  permitted << :featured if current_user.admin?
  params.expect(product: permitted)
end
```

### Multiple Models

```ruby
def order_params
  params.expect(
    order: [
      :notes,
      :shipping_address,
      line_items_attributes: [:id, :product_id, :quantity, :_destroy]
    ]
  )
end
```

### Nested Attributes

Rails' `accepts_nested_attributes_for` requires specific parameter format:

```ruby
class Order < ApplicationRecord
  has_many :line_items
  accepts_nested_attributes_for :line_items, allow_destroy: true
end

# Controller
params.expect(
  order: [
    :notes,
    line_items_attributes: [:id, :product_id, :quantity, :_destroy]
  ]
)
```

**Important:** Use `_attributes` suffix and include `:id` for updates and `:_destroy` for deletions.

### File Uploads

```ruby
params.expect(product: [:name, :price, :image])
# :image is an ActionDispatch::Http::UploadedFile
```

With Active Storage:

```ruby
params.expect(product: [:name, :price, :image, :gallery => []])
# :image is a single upload
# :gallery is multiple uploads
```

## Security Best Practices

### Never Trust User Input

```ruby
# BAD - Trusts all user input
@user = User.new(params[:user])

# GOOD - Whitelists safe parameters
@user = User.new(params.expect(user: [:name, :email]))
```

### Separate Admin Parameters

```ruby
# Regular users
def user_params
  params.expect(user: [:name, :email, :bio])
end

# Admin users
def admin_user_params
  base_params = [:name, :email, :bio]
  base_params += [:role, :permissions] if current_user.admin?
  params.expect(user: base_params)
end
```

### Validate Nested Structures

```ruby
# Ensure nested params are valid
def order_params
  permitted = params.expect(
    order: [
      :notes,
      line_items_attributes: [:product_id, :quantity]
    ]
  )

  # Additional validation
  if permitted[:line_items_attributes]
    permitted[:line_items_attributes].each do |item|
      raise "Invalid quantity" unless item[:quantity].to_i > 0
    end
  end

  permitted
end
```

### Log Parameter Filtering

Rails filters sensitive parameters from logs by default:

```ruby
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += [
  :password, :password_confirmation, :credit_card, :ssn
]
```

Logs show:

```
Parameters: {"user"=>{"email"=>"user@example.com", "password"=>"[FILTERED]"}}
```

## Testing Strong Parameters

```ruby
# RSpec
it "permits expected parameters" do
  post :create, params: {
    product: {
      name: "Widget",
      price: 9.99,
      admin_field: "hacked"  # Should be filtered
    }
  }

  expect(assigns(:product).admin_field).to be_nil
end

# Minitest
test "filters unauthorized parameters" do
  post products_path, params: {
    product: {
      name: "Widget",
      price: 9.99,
      admin_field: "hacked"
    }
  }

  assert_nil assigns(:product).admin_field
end
```

## Migration Guide: require/permit to expect

**Before (Rails 4-7):**

```ruby
def create
  @product = Product.new(product_params)
  @product.save
end

private

def product_params
  params.require(:product).permit(:name, :price, category_attributes: [:name])
end
```

**After (Rails 8):**

```ruby
def create
  @product = Product.new(params.expect(product: [:name, :price, category_attributes: [:name]]))
  @product.save
end

# Or keep the helper method
private

def product_params
  params.expect(product: [:name, :price, category_attributes: [:name]])
end
```

## Edge Cases

### Empty Arrays

```ruby
# Allow empty arrays
params.expect(product: [tags: []])

# params[:product][:tags] = [] # Valid
```

### Optional Parameters

```ruby
# Use fetch with default
search_params = params.fetch(:search, {}).permit(:query, :category)

# Rails 8
search_params = params.fetch(:search, {})
params_hash = { search: search_params.to_unsafe_h }
ActionController::Parameters.new(params_hash).expect(search: [:query, :category])
```

### Multiple Root Keys

```ruby
# Traditional
product = params.require(:product).permit(:name)
category = params.require(:category).permit(:name)

# Rails 8 (inline)
product_params = params.expect(product: [:name])
category_params = params.expect(category: [:name])
```

## Common Errors

### ParameterMissing

```ruby
params.expect(product: [:name])
# Raises if params[:product] is missing
```

Handle gracefully:

```ruby
begin
  @product = Product.new(params.expect(product: [:name, :price]))
rescue ActionController::ParameterMissing => e
  flash[:error] = "Product parameters are required"
  redirect_to new_product_path
end
```

### UnpermittedParameters

In development, Rails logs unpermitted parameters:

```
Unpermitted parameters: :admin, :secret
```

Configure behavior:

```ruby
# config/environments/development.rb
config.action_controller.action_on_unpermitted_parameters = :raise
# Options: :log (default), :raise, false
```

## Best Practices

1. **Use expect in Rails 8** - clearer than require/permit
2. **Whitelist, never blacklist** - explicitly allow, don't try to block
3. **Keep parameter methods private** - internal controller concern
4. **Separate admin parameters** - don't mix user and admin permissions
5. **Test parameter filtering** - ensure security works
6. **Filter sensitive data** - passwords, tokens, credit cards
7. **Validate after permitting** - strong parameters aren't validation
8. **Use consistent naming** - `model_params` methods
9. **Document complex structures** - comment nested parameter expectations
10. **Consider service objects** - for very complex parameter handling

Strong parameters are your first line of defense against mass assignment vulnerabilities. Master them, and your Rails app stays secure.
