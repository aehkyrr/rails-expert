# Minitest Patterns: Comprehensive Testing Examples
#
# This file demonstrates common Minitest patterns and best practices
# for testing Rails applications.

# ==============================================================================
# MODEL TESTS
# ==============================================================================

# test/models/product_test.rb
require "test_helper"

class ProductTest < ActiveSupport::TestCase
  # Validation tests
  test "requires name" do
    product = Product.new(price: 9.99)
    assert_not product.valid?
    assert_includes product.errors[:name], "can't be blank"
  end

  test "requires positive price" do
    product = Product.new(name: "Widget", price: -5)
    assert_not product.valid?
    assert_equal ["must be greater than 0"], product.errors[:price]
  end

  test "requires unique SKU" do
    existing = products(:widget)
    duplicate = Product.new(name: "New", sku: existing.sku)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:sku], "has already been taken"
  end

  # Association tests
  test "belongs to category" do
    product = products(:widget)
    assert_instance_of Category, product.category
    assert_equal categories(:electronics), product.category
  end

  test "has many reviews through association" do
    product = products(:widget)
    assert_respond_to product, :reviews

    review = product.reviews.create!(rating: 5, content: "Great!")
    assert_includes product.reviews, review
  end

  test "destroys dependent reviews when destroyed" do
    product = products(:widget)
    review = product.reviews.create!(rating: 5)

    assert_difference("Review.count", -1) do
      product.destroy
    end
  end

  # Scope tests
  test "available scope returns only available products" do
    available = products(:widget)
    available.update!(available: true)

    unavailable = products(:gadget)
    unavailable.update!(available: false)

    results = Product.available
    assert_includes results, available
    assert_not_includes results, unavailable
  end

  # Instance method tests
  test "calculates discounted price" do
    product = Product.new(price: 100, discount_percentage: 20)
    assert_equal 80.0, product.discounted_price
  end

  test "returns full price when no discount" do
    product = Product.new(price: 100)
    assert_equal 100, product.discounted_price
  end

  # Callback tests
  test "generates SKU before creation" do
    product = Product.create!(name: "Test", price: 10)
    assert_not_nil product.sku
    assert_match /^PRD-/, product.sku
  end

  test "normalizes name before validation" do
    product = Product.new(name: "  widget  ", price: 10)
    product.valid?
    assert_equal "Widget", product.name  # Stripped and titleized
  end

  # State changes
  test "updates updated_at when saved" do
    product = products(:widget)
    original_time = product.updated_at

    travel 1.hour do
      product.update!(price: 15.99)
      assert_operator product.updated_at, :>, original_time
    end
  end
end

# ==============================================================================
# CONTROLLER TESTS
# ==============================================================================

# test/controllers/products_controller_test.rb
require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  # Index action
  test "index displays all products" do
    get products_url
    assert_response :success
    assert_select "h1", "Products"
    assert_select "div.product", count: Product.count
  end

  test "index can filter by category" do
    get products_url(category: "electronics")
    assert_response :success
    # Only electronics products shown
  end

  # Show action
  test "show displays product" do
    product = products(:widget)
    get product_url(product)

    assert_response :success
    assert_select "h2", product.name
    assert_select ".price", text: /#{product.price}/
  end

  test "show returns 404 for missing product" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get product_url(id: 999999)
    end
  end

  # Create action
  test "creates product with valid params" do
    assert_difference("Product.count", 1) do
      post products_url, params: {
        product: { name: "New Widget", price: 9.99, category_id: categories(:electronics).id }
      }
    end

    product = Product.last
    assert_equal "New Widget", product.name
    assert_redirected_to product_path(product)

    follow_redirect!
    assert_select "h2", "New Widget"
  end

  test "does not create product with invalid params" do
    assert_no_difference("Product.count") do
      post products_url, params: { product: { price: 9.99 } }  # Missing name
    end

    assert_response :unprocessable_entity
    assert_select ".error", text: /can't be blank/
  end

  # Update action
  test "updates product with valid params" do
    product = products(:widget)

    patch product_url(product), params: {
      product: { name: "Updated Widget" }
    }

    assert_redirected_to product_path(product)
    assert_equal "Updated Widget", product.reload.name
  end

  # Destroy action
  test "destroys product" do
    product = products(:widget)

    assert_difference("Product.count", -1) do
      delete product_url(product)
    end

    assert_redirected_to products_path
  end

  # Authentication/Authorization
  test "requires login for new product" do
    sign_out
    get new_product_url
    assert_redirected_to login_path
  end

  test "requires admin for edit" do
    sign_in_as(:customer)  # Not admin
    product = products(:widget)

    get edit_product_url(product)
    assert_redirected_to root_path
    assert_equal "Not authorized", flash[:alert]
  end
end

# ==============================================================================
# INTEGRATION TESTS
# ==============================================================================

# test/integration/checkout_flow_test.rb
require "test_helper"

class CheckoutFlowTest < ActionDispatch::IntegrationTest
  test "complete checkout process" do
    # Start at products
    get products_path
    assert_response :success

    # Add product to cart
    product = products(:widget)
    post cart_items_path, params: { product_id: product.id, quantity: 2 }
    assert_redirected_to cart_path

    # View cart
    follow_redirect!
    assert_select ".cart-item", count: 1
    assert_select ".total", text: /#{product.price * 2}/

    # Proceed to checkout
    post orders_path
    assert_redirected_to order_path(Order.last)

    # Confirm order created
    order = Order.last
    assert_equal 2, order.line_items.count
    assert_equal product.price * 2, order.total
  end

  test "cannot checkout empty cart" do
    post orders_path
    assert_redirected_to cart_path
    assert_equal "Cart is empty", flash[:alert]
  end
end

# ==============================================================================
# SYSTEM TESTS (Full Browser)
# ==============================================================================

# test/system/products_test.rb
require "application_system_test_case"

class ProductsTest < ApplicationSystemTestCase
  test "admin creates product" do
    sign_in_as(:admin)

    visit products_path
    click_on "New Product"

    fill_in "Name", with: "Test Widget"
    fill_in "Price", with: "19.99"
    fill_in "Description", with: "A great product"
    select "Electronics", from: "Category"

    click_on "Create Product"

    # Verify success
    assert_text "Product created successfully"
    assert_text "Test Widget"
    assert_text "$19.99"
  end

  test "user searches products" do
    visit products_path

    fill_in "Search", with: "Widget"
    click_on "Search"

    assert_text "Widget"
    assert_no_text "Gadget"
  end

  test "user adds product to cart" do
    visit products_path

    within "#product_#{products(:widget).id}" do
      click_on "Add to Cart"
    end

    assert_text "Added to cart"

    click_on "Cart"
    assert_text "Widget"
    assert_selector ".cart-item", count: 1
  end

  # Testing JavaScript interactions
  test "dropdown menu works" do
    visit root_path

    # Menu should be hidden
    assert_selector ".dropdown-menu", visible: :hidden

    # Click to open
    find("#menu-button").click

    # Menu should be visible
    assert_selector ".dropdown-menu", visible: :visible

    # Click outside to close
    find("body").click

    # Menu should be hidden again
    assert_selector ".dropdown-menu", visible: :hidden
  end
end

# ==============================================================================
# HELPER METHODS
# ==============================================================================

# test/test_helper.rb
class ActiveSupport::TestCase
  # Setup all fixtures
  fixtures :all

  # Helper: Sign in as a user
  def sign_in_as(fixture_name)
    user = users(fixture_name)
    post login_path, params: { email: user.email, password: "password" }
  end

  # Helper: Sign out
  def sign_out
    delete logout_path
  end

  # Helper: Assert JSON response
  def assert_json_response(expected_hash)
    assert_equal "application/json", response.content_type
    assert_equal expected_hash, JSON.parse(response.body)
  end

  # Helper: Assert email sent
  def assert_email_sent(to:, subject:)
    assert_enqueued_email_with ActionMailer::MailDeliveryJob, args: ->(args) {
      args[1] == to && args[2] == subject
    }
  end
end

# test/application_system_test_case.rb
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  # Helper: Sign in for system tests
  def sign_in_as(fixture_name)
    user = users(fixture_name)
    visit login_path

    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_on "Log in"
  end

  # Helper: Take screenshot on failure
  def after_teardown
    super
    if !passed?
      take_screenshot
    end
  end
end

# ==============================================================================
# TESTING JOBS
# ==============================================================================

# test/jobs/export_job_test.rb
require "test_helper"

class ExportJobTest < ActiveJob::TestCase
  test "exports products to CSV" do
    user = users(:admin)

    assert_enqueued_with(job: ExportJob, args: [user.id]) do
      ExportJob.perform_later(user.id)
    end

    # Perform job
    perform_enqueued_jobs

    # Check export was created
    export = user.exports.last
    assert_not_nil export
    assert_equal "completed", export.status
  end

  test "handles errors gracefully" do
    ExportJob.perform_now(999999)  # Invalid user ID

    # Should not raise, should log error
    assert_no_enqueued_jobs
  end
end

# ==============================================================================
# TESTING MAILERS
# ==============================================================================

# test/mailers/order_mailer_test.rb
require "test_helper"

class OrderMailerTest < ActionMailer::TestCase
  test "sends confirmation email" do
    order = orders(:pending)
    email = OrderMailer.confirmation(order)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [order.user.email], email.to
    assert_equal "Order Confirmation ##{order.number}", email.subject
    assert_match /Thank you for your order/, email.body.encoded
    assert_match order.number, email.body.encoded
  end

  test "includes order items in email" do
    order = orders(:pending)
    email = OrderMailer.confirmation(order)

    order.line_items.each do |item|
      assert_match item.product.name, email.body.encoded
    end
  end
end

# ==============================================================================
# KEY TAKEAWAYS
# ==============================================================================

# 1. TEST TYPES:
#    - Model: Business logic, validations, associations
#    - Controller: Request handling, responses
#    - Integration: Multi-controller flows
#    - System: Full browser simulation
#
# 2. FIXTURES:
#    - Define in test/fixtures/*.yml
#    - Access via fixtures(:name)
#    - Use for common test data
#
# 3. ASSERTIONS:
#    - assert / assert_not - basic truth
#    - assert_equal / assert_not_equal - equality
#    - assert_difference - count changes
#    - assert_response - HTTP responses
#    - assert_select - HTML content
#
# 4. TDD WORKFLOW:
#    - Red: Write failing test
#    - Green: Minimal implementation
#    - Refactor: Improve while tests pass
#
# 5. BEST PRACTICES:
#    - One concept per test
#    - Descriptive test names
#    - Test behavior, not implementation
#    - Keep tests fast
#    - Use helper methods for common setup
#
# Master Rails testing and ship features with confidence!
