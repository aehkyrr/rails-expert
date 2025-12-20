# Test-Driven Development (TDD) in Rails

## The TDD Philosophy

Test-Driven Development is writing tests before implementation. This ensures:
- Features are testable
- Tests actually test something
- Code does exactly what's needed
- Refactoring is safe
- Documentation is accurate

Rails embraces TDD as a core practice.

## The Red-Green-Refactor Cycle

### 1. Red: Write Failing Test

Write a test for the feature that doesn't exist yet:

```ruby
# test/models/product_test.rb
test "applies discount to price" do
  product = Product.new(price: 100, discount_percentage: 20)
  assert_equal 80, product.discounted_price
end
```

Run test:
```bash
$ rails test test/models/product_test.rb
# Error: undefined method `discounted_price'
```

Test fails (red). Good! This confirms the test works.

### 2. Green: Minimal Implementation

Write just enough code to make the test pass:

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  def discounted_price
    price - (price * discount_percentage / 100.0)
  end
end
```

Run test:
```bash
$ rails test test/models/product_test.rb
# 1 runs, 1 assertions, 0 failures
```

Test passes (green). Good!

### 3. Refactor: Improve Code

Now improve the code while keeping tests green:

```ruby
class Product < ApplicationRecord
  def discounted_price
    return price unless discount_percentage.present? && discount_percentage > 0

    discounted = price * (1 - discount_percentage / 100.0)
    discounted.round(2)
  end
end
```

Run test:
```bash
$ rails test test/models/product_test.rb
# Still passes!
```

### 4. Repeat

Add more tests for edge cases:

```ruby
test "returns full price when no discount" do
  product = Product.new(price: 100)
  assert_equal 100, product.discounted_price
end

test "returns full price when discount is zero" do
  product = Product.new(price: 100, discount_percentage: 0)
  assert_equal 100, product.discounted_price
end

test "rounds to two decimal places" do
  product = Product.new(price: 99.99, discount_percentage: 15)
  assert_equal 84.99, product.discounted_price
end
```

Run, implement, refactor. Repeat.

## TDD for New Features

### Example: Adding a Feature

**User story:** Products can be marked as featured.

#### Step 1: Write Model Test (Red)

```ruby
# test/models/product_test.rb
test "can be marked as featured" do
  product = products(:widget)
  assert_not product.featured?

  product.feature!
  assert product.featured?
end

test "can be unfeatured" do
  product = products(:widget)
  product.feature!

  product.unfeature!
  assert_not product.featured?
end
```

#### Step 2: Add Migration (Red → Green)

```bash
$ rails generate migration AddFeaturedToProducts featured:boolean
$ rails db:migrate
```

#### Step 3: Add Methods (Green)

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  def feature!
    update(featured: true)
  end

  def unfeature!
    update(featured: false)
  end

  def featured?
    featured == true
  end
end
```

Tests pass!

#### Step 4: Add Scope Test (Red)

```ruby
test "scope returns only featured products" do
  featured = products(:widget)
  featured.update(featured: true)

  regular = products(:gadget)
  regular.update(featured: false)

  results = Product.featured
  assert_includes results, featured
  assert_not_includes results, regular
end
```

#### Step 5: Add Scope (Green)

```ruby
class Product < ApplicationRecord
  scope :featured, -> { where(featured: true) }
end
```

#### Step 6: Add Controller Test (Red)

```ruby
# test/controllers/products_controller_test.rb
test "admin can feature product" do
  sign_in_as(:admin)
  product = products(:widget)

  post feature_product_url(product)

  assert_redirected_to product_path(product)
  assert product.reload.featured?
end
```

#### Step 7: Add Route and Action (Green)

```ruby
# config/routes.rb
resources :products do
  member do
    post :feature
    delete :unfeature
  end
end

# app/controllers/products_controller.rb
def feature
  @product = Product.find(params[:id])
  @product.feature!
  redirect_to @product, notice: "Product featured!"
end

def unfeature
  @product = Product.find(params[:id])
  @product.unfeature!
  redirect_to @product, notice: "Product unfeatured!"
end
```

#### Step 8: Add System Test (Red)

```ruby
# test/system/products_test.rb
test "admin features product" do
  sign_in_as(:admin)
  visit product_path(products(:widget))

  click_on "Feature Product"

  assert_text "Product featured"
  assert_selector ".badge", text: "Featured"
end
```

#### Step 9: Add UI (Green)

```erb
<%# app/views/products/show.html.erb %>
<% if @product.featured? %>
  <span class="badge">Featured</span>
<% end %>

<% if current_user&.admin? %>
  <% if @product.featured? %>
    <%= button_to "Unfeature", unfeature_product_path(@product), method: :delete %>
  <% else %>
    <%= button_to "Feature Product", feature_product_path(@product), method: :post %>
  <% end %>
<% end %>
```

Feature complete, fully tested!

## TDD Benefits

1. **Tests Actually Test**: Writing tests first ensures they fail without implementation
2. **No Untested Code**: Every line has a test
3. **Better Design**: Testable code is better structured
4. **Documentation**: Tests show how code should be used
5. **Confidence**: Refactor without fear
6. **Fast Debugging**: Failing tests pinpoint issues

## Common TDD Pitfalls

### Testing Implementation Instead of Behavior

**Bad:**
```ruby
test "calls calculate_total method" do
  order = orders(:pending)
  order.expects(:calculate_total)  # Testing implementation!
  order.place
end
```

**Good:**
```ruby
test "sets total when placing order" do
  order = orders(:pending)
  order.line_items << line_items(:item1)

  order.place

  expected_total = order.line_items.sum { |i| i.quantity * i.price }
  assert_equal expected_total, order.total  # Testing behavior!
end
```

### Too Many Assertions Per Test

**Bad:**
```ruby
test "product" do
  assert product.valid?
  assert_equal "Widget", product.name
  assert_equal 9.99, product.price
  assert product.available?
  assert_equal categories(:electronics), product.category
  # Testing too much!
end
```

**Good:**
```ruby
test "valid product is valid" do
  assert products(:widget).valid?
end

test "has correct attributes" do
  product = products(:widget)
  assert_equal "Widget", product.name
  assert_equal 9.99, product.price
end

test "belongs to category" do
  assert_equal categories(:electronics), products(:widget).category
end
```

One concept per test makes failures easier to diagnose.

## Testing Best Practices

1. **Test behavior, not implementation**
2. **One assertion per test** (or closely related assertions)
3. **Use descriptive test names** (`test "applies 10% discount to price"`)
4. **Use fixtures for common data**, inline creation for test-specific data
5. **Test edge cases** (nil, zero, negative, empty, huge values)
6. **Test error conditions** (validations, exceptions)
7. **Keep tests fast** (use fixtures, minimize database hits)
8. **Don't test framework** (don't test that `validates :name, presence: true` works)
9. **Test public interfaces**, not private methods
10. **Refactor tests** like production code

Master TDD and you'll ship features faster with fewer bugs.
