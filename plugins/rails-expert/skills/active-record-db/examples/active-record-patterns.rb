# Active Record Patterns: Comprehensive Examples
#
# This file demonstrates common Active Record patterns, best practices,
# and solutions to frequent challenges.

# ==============================================================================
# MODELS WITH ASSOCIATIONS
# ==============================================================================

# app/models/category.rb
class Category < ApplicationRecord
  has_many :products, dependent: :destroy
  has_many :available_products, -> { where(available: true) }, class_name: "Product"

  validates :name, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
  scope :with_products, -> { joins(:products).distinct }
end

# app/models/product.rb
class Product < ApplicationRecord
  belongs_to :category
  belongs_to :supplier, optional: true
  has_many :line_items, dependent: :restrict_with_error
  has_many :orders, through: :line_items
  has_many :reviews, dependent: :destroy
  has_and_belongs_to_many :tags

  # Validations
  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :sku, presence: true, uniqueness: true
  validates :price, numericality: { greater_than: 0 }
  validate :price_must_be_reasonable

  # Callbacks
  before_validation :normalize_sku
  before_save :calculate_discount_price
  after_create :notify_supplier
  after_destroy :cleanup_images

  # Scopes
  scope :available, -> { where(available: true) }
  scope :in_stock, -> { where("quantity > ?", 0) }
  scope :cheap, -> { where("price < ?", 10) }
  scope :expensive, -> { where("price > ?", 100) }
  scope :in_category, ->(category_name) { joins(:category).where(categories: { name: category_name }) }

  # Class methods
  def self.search(query)
    where("name LIKE ? OR description LIKE ?", "%#{query}%", "%#{query}%")
  end

  # Instance methods
  def discounted?
    discount_price.present? && discount_price < price
  end

  def margin
    return 0 unless cost.present?
    ((price - cost) / price * 100).round(2)
  end

  private

  def normalize_sku
    self.sku = sku.upcase.strip if sku.present?
  end

  def calculate_discount_price
    if quantity > 100
      self.discount_price = price * 0.9
    end
  end

  def price_must_be_reasonable
    if price.present? && price > 10_000
      errors.add(:price, "is unreasonably high")
    end
  end

  def notify_supplier
    SupplierMailer.new_product(self).deliver_later if supplier.present?
  end

  def cleanup_images
    # Remove associated files
  end
end

# app/models/order.rb
class Order < ApplicationRecord
  belongs_to :user
  has_many :line_items, dependent: :destroy
  has_many :products, through: :line_items

  # Nested attributes for creating order with line items in one form
  accepts_nested_attributes_for :line_items, allow_destroy: true, reject_if: :all_blank

  # Enum for status
  enum status: { pending: 0, processing: 1, shipped: 2, delivered: 3, cancelled: 4 }

  # Validations
  validates :user, presence: true
  validates :line_items, presence: true, on: :create

  # Callbacks
  before_create :generate_order_number
  after_create :charge_payment
  before_save :calculate_total

  # State machine methods
  def process!
    processing!
    ProcessOrderJob.perform_later(id)
  end

  def ship!
    shipped!
    ShipmentMailer.notification(self).deliver_later
  end

  private

  def generate_order_number
    self.order_number = "ORD-#{SecureRandom.hex(8).upcase}"
  end

  def calculate_total
    self.total = line_items.sum { |item| item.quantity * item.price }
  end

  def charge_payment
    PaymentService.charge(self)
  end
end

# app/models/line_item.rb
class LineItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, numericality: { greater_than: 0, only_integer: true }
  validates :price, numericality: { greater_than: 0 }

  # Set price from product before validation
  before_validation :set_price_from_product

  private

  def set_price_from_product
    self.price ||= product.price if product.present?
  end
end

# ==============================================================================
# POLYMORPHIC ASSOCIATIONS
# ==============================================================================

# app/models/comment.rb
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  belongs_to :user

  validates :body, presence: true, length: { minimum: 2, maximum: 500 }
end

# Models that can be commented on
class Post < ApplicationRecord
  has_many :comments, as: :commentable, dependent: :destroy
end

class Product < ApplicationRecord
  has_many :comments, as: :commentable, dependent: :destroy
end

# Usage:
# post = Post.find(1)
# post.comments.create(body: "Great post!", user: current_user)
#
# product = Product.find(1)
# product.comments.create(body: "Love this!", user: current_user)
#
# comment = Comment.first
# comment.commentable  # Returns Post or Product

# ==============================================================================
# SINGLE TABLE INHERITANCE (STI)
# ==============================================================================

# app/models/user.rb
class User < ApplicationRecord
  # type column required for STI
  validates :email, presence: true, uniqueness: true
end

# app/models/admin.rb
class Admin < User
  def can_manage?(resource)
    true
  end
end

# app/models/customer.rb
class Customer < User
  has_many :orders

  def can_manage?(resource)
    resource.user_id == id
  end
end

# Queries:
# User.all          # All users (admins + customers)
# Admin.all         # WHERE type = 'Admin'
# Customer.all      # WHERE type = 'Customer'
#
# user = Admin.create(email: "admin@example.com")
# user.type  # => "Admin"
# user.is_a?(Admin)  # => true
# user.is_a?(User)   # => true

# ==============================================================================
# QUERY OPTIMIZATION PATTERNS
# ==============================================================================

# N+1 Problem
class ProductsController < ApplicationController
  def index
    # BAD: N+1 queries
    # @products = Product.all
    # @products.each { |p| puts p.category.name }  # N queries!

    # GOOD: Eager loading
    @products = Product.includes(:category, :tags).all
    # @products.each { |p| puts p.category.name }  # No extra queries!
  end

  def show
    # BAD: Loads all columns
    # @product = Product.find(params[:id])

    # GOOD: Only load needed columns
    @product = Product.select(:id, :name, :price, :description).find(params[:id])

    # GOOD: Nested eager loading
    @product = Product.includes(line_items: { order: :user }).find(params[:id])
  end
end

# Batch processing
class ProductsReporter
  def generate_report
    # BAD: Loads all products into memory
    # Product.all.each { |p| process(p) }

    # GOOD: Process in batches
    Product.find_each(batch_size: 1000) do |product|
      process(product)
    end
  end

  def bulk_update
    # BAD: N UPDATE queries
    # products.each { |p| p.update(processed: true) }

    # GOOD: Single UPDATE query
    Product.where(id: product_ids).update_all(processed: true)
  end
end

# Counting efficiently
class DashboardController < ApplicationController
  def stats
    @products = Product.available

    # GOOD: Uses count
    @total = @products.count

    # GOOD: Uses size (smart about loaded vs not loaded)
    @total = @products.size

    # BAD: Loads all records then counts in Ruby
    # @total = @products.length

    # Existence checks
    # BAD: Loads records
    # has_products = @products.any?

    # GOOD: SELECT 1 query
    has_products = @products.exists?
  end
end

# Pluck for efficiency
class ReportsController < ApplicationController
  def export
    # BAD: Loads full objects
    # names = Product.all.map(&:name)

    # GOOD: Directly extracts column
    names = Product.pluck(:name)

    # Multiple columns
    data = Product.pluck(:id, :name, :price)
    # => [[1, "Widget", 9.99], [2, "Gadget", 14.99]]

    # Just IDs
    ids = Product.ids  # Shortcut for Product.pluck(:id)
  end
end

# ==============================================================================
# SCOPES AND CLASS METHODS
# ==============================================================================

class Product < ApplicationRecord
  # Simple scopes
  scope :available, -> { where(available: true) }
  scope :featured, -> { where(featured: true) }

  # Scopes with arguments
  scope :cheaper_than, ->(price) { where("price < ?", price) }
  scope :in_price_range, ->(min, max) { where(price: min..max) }

  # Combining scopes
  scope :available_and_cheap, -> { available.cheaper_than(10) }

  # Scopes with joins
  scope :in_category, ->(category_name) {
    joins(:category).where(categories: { name: category_name })
  }

  # Default scope (use sparingly!)
  # default_scope { where(deleted_at: nil).order(created_at: :desc) }

  # Class methods (alternative to scopes)
  def self.search(query)
    where("name LIKE :q OR description LIKE :q", q: "%#{query}%")
  end

  def self.expensive
    where("price > ?", 100)
  end
end

# Usage:
# Product.available
# Product.cheaper_than(50)
# Product.in_price_range(10, 100)
# Product.available.featured.cheaper_than(20)
# Product.in_category("Electronics").available

# ==============================================================================
# CALLBACKS PATTERNS
# ==============================================================================

class Product < ApplicationRecord
  # Order of callbacks:
  # 1. before_validation
  # 2. after_validation
  # 3. before_save
  # 4. before_create / before_update
  # 5. [DATABASE OPERATION]
  # 6. after_create / after_update
  # 7. after_save
  # 8. after_commit / after_rollback

  before_validation :normalize_data
  after_validation :log_errors
  before_save :set_defaults
  before_create :generate_sku
  after_create :send_notifications
  after_save :clear_cache
  after_commit :index_for_search

  # Conditional callbacks
  before_save :notify_price_change, if: :price_changed?
  after_update :reindex, if: -> { saved_change_to_name? || saved_change_to_description? }

  # Halt execution by throwing :abort
  before_destroy :check_if_deletable

  private

  def normalize_data
    self.name = name.strip.titleize if name.present?
  end

  def log_errors
    Rails.logger.error("Validation failed: #{errors.full_messages}") if errors.any?
  end

  def set_defaults
    self.available = true if available.nil?
  end

  def generate_sku
    self.sku ||= "PRD-#{SecureRandom.hex(4).upcase}"
  end

  def send_notifications
    NewProductMailer.notification(self).deliver_later
  end

  def clear_cache
    Rails.cache.delete("product_#{id}")
  end

  def index_for_search
    SearchIndexJob.perform_later(id)
  end

  def notify_price_change
    PriceChangeMailer.notification(self).deliver_later
  end

  def check_if_deletable
    if orders.exists?
      errors.add(:base, "Cannot delete product with orders")
      throw :abort
    end
  end
end

# ==============================================================================
# VALIDATIONS PATTERNS
# ==============================================================================

class Product < ApplicationRecord
  # Presence
  validates :name, presence: true
  validates :sku, presence: true, on: :create  # Only on create

  # Uniqueness
  validates :sku, uniqueness: true
  validates :name, uniqueness: { scope: :category_id, message: "already exists in this category" }

  # Format
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :sku, format: { with: /\A[A-Z0-9\-]+\z/, message: "only allows uppercase letters, numbers, and hyphens" }

  # Length
  validates :name, length: { minimum: 3, maximum: 100 }
  validates :description, length: { in: 10..500 }

  # Numericality
  validates :price, numericality: { greater_than: 0 }
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Inclusion/Exclusion
  validates :size, inclusion: { in: %w[small medium large] }
  validates :status, exclusion: { in: %w[archived] }

  # Conditional validations
  validates :discount_price, presence: true, if: :on_sale?
  validates :coupon_code, presence: true, if: -> { coupon_applied? }

  # Custom validations
  validate :price_reasonable
  validate :release_date_in_future, on: :create

  private

  def on_sale?
    sale_starts_at.present? && sale_starts_at <= Time.current
  end

  def price_reasonable
    if price.present? && price > 10_000
      errors.add(:price, "is unreasonably high for this category")
    end
  end

  def release_date_in_future
    if release_date.present? && release_date < Date.today
      errors.add(:release_date, "must be in the future")
    end
  end
end

# ==============================================================================
# TRANSACTIONS
# ==============================================================================

class OrderService
  def place_order(order)
    ActiveRecord::Base.transaction do
      order.save!
      order.line_items.each do |item|
        item.product.decrement!(:quantity, item.quantity)
      end
      PaymentService.charge(order)
      OrderMailer.confirmation(order).deliver_later
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Order failed: #{e.message}")
    false
  end

  def transfer_products(from_category, to_category)
    ActiveRecord::Base.transaction do
      products = from_category.products
      products.update_all(category_id: to_category.id)

      # Require rollback on failure
      raise ActiveRecord::Rollback unless validate_transfer(products)
    end
  end
end

# ==============================================================================
# KEY TAKEAWAYS
# ==============================================================================

# 1. ASSOCIATIONS:
#    - Use belongs_to for foreign keys in this table
#    - Use has_many/has_one for foreign keys in other table
#    - Prefer has_many :through over HABTM for flexibility
#    - Add inverse_of for bi-directional associations
#
# 2. VALIDATIONS:
#    - Validate at model level for data integrity
#    - Use presence, uniqueness, format, numericality
#    - Custom validations for complex rules
#    - Conditional validations with if/unless
#
# 3. CALLBACKS:
#    - Keep callbacks simple and focused
#    - Use before_validation to normalize data
#    - Use after_commit for external services
#    - Avoid complex business logic in callbacks
#
# 4. QUERIES:
#    - Eager load with includes to prevent N+1
#    - Use select to limit columns
#    - Use pluck for simple extractions
#    - Use find_each for large datasets
#    - Add indexes on foreign keys and frequently queried columns
#
# 5. SCOPES:
#    - Use lambda syntax for scopes
#    - Make scopes chainable
#    - Combine scopes for complex queries
#    - Use class methods for complex logic
#
# 6. BEST PRACTICES:
#    - Fat models, skinny controllers
#    - Keep models focused (Single Responsibility)
#    - Use service objects for complex operations
#    - Test validations, associations, and scopes
#    - Profile and optimize queries

# Master these patterns and you master Active Record!
