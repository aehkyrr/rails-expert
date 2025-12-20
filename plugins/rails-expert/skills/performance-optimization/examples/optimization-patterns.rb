# Performance Optimization Patterns
#
# Common optimization patterns and anti-patterns in Rails applications

# ==============================================================================
# PATTERN 1: Preventing N+1 Queries with Eager Loading
# ==============================================================================

# BAD: N+1 Problem
class ProductsController < ApplicationController
  def index
    @products = Product.all  # 1 query

    # In view: @products.each { |p| p.category.name }
    # Fires N additional queries!
  end
end

# GOOD: Eager Loading
class ProductsController < ApplicationController
  def index
    @products = Product.includes(:category).all  # 2 queries total
  end
end

# BETTER: Multi-level Eager Loading
class ProductsController < ApplicationController
  def index
    @products = Product.includes(:category, :reviews, line_items: :order)
    # Loads products, categories, reviews, line_items, and orders in optimal queries
  end
end

# ==============================================================================
# PATTERN 2: Using select to Limit Data Transfer
# ==============================================================================

# BAD: Loading all columns
def index
  @products = Product.all
  # Loads all columns even if only using name and price
end

# GOOD: Select only needed columns
def index
  @products = Product.select(:id, :name, :price)
  # Smaller result set, faster query, less memory
end

# GOOD: Pluck for simple extractions
def export_names
  names = Product.pluck(:name)  # Array of strings, no AR objects created
  # Much faster than Product.all.map(&:name)
end

# ==============================================================================
# PATTERN 3: Counter Caches
# ==============================================================================

# BAD: Counting on every request
class Category < ApplicationRecord
  has_many :products
end

# In view:
# category.products.count  # Fires COUNT query every time

# GOOD: Counter cache
class Category < ApplicationRecord
  has_many :products
end

class Product < ApplicationRecord
  belongs_to :category, counter_cache: true
end

# Migration:
# add_column :categories, :products_count, :integer, default: 0

# Now:
# category.products_count  # No query! Reads from column

# ==============================================================================
# PATTERN 4: Batch Processing Large Datasets
# ==============================================================================

# BAD: Loading everything into memory
Product.all.each do |product|
  process(product)
end
# With 1M products, this loads all 1M into memory!

# GOOD: Batch processing
Product.find_each(batch_size: 1000) do |product|
  process(product)
end
# Processes in batches of 1000, low memory usage

# GOOD: Batch updates
Product.where(available: false).in_batches(of: 1000) do |batch|
  batch.update_all(archived: true)
end

# ==============================================================================
# PATTERN 5: Fragment Caching in Views
# ==============================================================================

# BAD: No caching
# <% @products.each do |product| %>
#   <%= render product %>
# <% end %>
# Renders every product on every request

# GOOD: Fragment caching
# <% @products.each do |product| %>
#   <% cache product do %>
#     <%= render product %>
#   <% end %>
# <% end %>
# Cached until product.updated_at changes

# BETTER: Collection caching (batch cache reads)
# <%= render partial: 'products/product', collection: @products, cached: true %>
# Reads all caches in one multi-get operation

# ==============================================================================
# PATTERN 6: Russian Doll Caching
# ==============================================================================

class Product < ApplicationRecord
  belongs_to :category, touch: true  # Key to Russian doll caching
end

# app/views/categories/show.html.erb
# <% cache @category do %>
#   <h2><%= @category.name %></h2>
#
#   <% @category.products.each do |product| %>
#     <% cache product do %>
#       <%= render product %>
#     <% end %>
#   <% end %>
# <% end %>

# When product updates:
# - Product cache expires (updated_at changed)
# - Category cache expires (touched)
# - Other products' caches stay valid

# ==============================================================================
# PATTERN 7: Low-Level Caching for Expensive Operations
# ==============================================================================

class Product < ApplicationRecord
  def complex_statistics
    # BAD: Recalculates every time
    # calculate_stats

    # GOOD: Cache result
    Rails.cache.fetch("product_#{id}/stats", expires_in: 1.hour) do
      calculate_stats
    end
  end

  def related_products
    # Cache with multiple dependencies
    Rails.cache.fetch(["product", id, :related, category_id, updated_at]) do
      category.products.where.not(id: id).limit(5).to_a
    end
  end

  private

  def calculate_stats
    {
      total_sales: orders.sum(:quantity),
      revenue: orders.sum('quantity * price'),
      avg_rating: reviews.average(:rating)
    }
  end
end

# ==============================================================================
# PATTERN 8: Optimizing Database Queries
# ==============================================================================

class ProductsController < ApplicationController
  def index
    # BAD: Loads all data, counts in Ruby
    # @products = Product.where(available: true)
    # @total = @products.length  # Loads all records!

    # GOOD: Use SQL COUNT
    @products = Product.where(available: true).page(params[:page])
    @total = @products.count  # COUNT(*) query

    # BETTER: Use size (smart about loaded vs not)
    @total = @products.size  # Uses count if not loaded, length if loaded
  end

  def search
    # BAD: Multiple queries
    # @products = Product.where("name LIKE ?", "%#{params[:q]}%")
    # @categories = Category.where(id: @products.pluck(:category_id))

    # GOOD: Single query with join
    @products = Product.joins(:category)
                      .where("products.name LIKE ?", "%#{params[:q]}%")
                      .select("products.*, categories.name as category_name")
  end

  def export
    # BAD: Loading full objects
    # data = Product.all.map { |p| [p.id, p.name, p.price] }

    # GOOD: Direct extraction with pluck
    data = Product.pluck(:id, :name, :price)
    # Returns: [[1, "Widget", 9.99], [2, "Gadget", 14.99]]
  end
end

# ==============================================================================
# PATTERN 9: Using Indexes Effectively
# ==============================================================================

# Migration: Add indexes for common queries
class OptimizeProducts < ActiveRecord::Migration[8.0]
  def change
    # Single column indexes
    add_index :products, :sku, unique: true
    add_index :products, :available

    # Composite indexes (order matters!)
    add_index :products, [:category_id, :available]
    # Good for: WHERE category_id = X AND available = true
    # Also good for: WHERE category_id = X
    # Not good for: WHERE available = true (doesn't use index)

    # Partial indexes (PostgreSQL)
    add_index :products, :name, where: "available = true"
    # Only indexes available products

    # Expression indexes (PostgreSQL)
    add_index :products, "LOWER(name)"
    # For case-insensitive searches
  end
end

# Query that uses index:
Product.where(category_id: 5, available: true).order(:created_at)
# Uses composite index on [category_id, available]

# ==============================================================================
# PATTERN 10: Scopes with Caching
# ==============================================================================

class Product < ApplicationRecord
  # BAD: Not chainable, not lazy
  # def self.featured
  #   where(featured: true).to_a  # Executes immediately!
  # end

  # GOOD: Chainable scope
  scope :featured, -> { where(featured: true) }
  scope :available, -> { where(available: true) }
  scope :cheap, -> { where("price < ?", 10) }

  # With eager loading built-in
  scope :with_category, -> { includes(:category) }
  scope :with_reviews, -> { includes(:reviews) }

  # Cached scope result
  def self.featured_cached
    Rails.cache.fetch("products/featured", expires_in: 10.minutes) do
      featured.with_category.to_a
    end
  end
end

# Usage:
# Product.featured.available.cheap.with_category
# Builds query lazily, executes once

# ==============================================================================
# PATTERN 11: Background Jobs for Slow Operations
# ==============================================================================

# BAD: Slow operation in controller
class ReportsController < ApplicationController
  def create
    report = GenerateReport.new(params).execute  # Takes 30 seconds!
    send_data report, filename: "report.pdf"
  end
end

# GOOD: Background job
class ReportsController < ApplicationController
  def create
    ReportGenerationJob.perform_later(current_user, params[:filters])
    redirect_to reports_path, notice: "Report is being generated. You'll be notified when ready."
  end
end

class ReportGenerationJob < ApplicationJob
  def perform(user, filters)
    report = GenerateReport.new(filters).execute
    ReportMailer.ready(user, report).deliver_now
  end
end

# ==============================================================================
# PATTERN 12: Memoization for Repeated Calls
# ==============================================================================

class Product < ApplicationRecord
  # BAD: Recalculates every call
  # def discounted_price
  #   price * (1 - discount_percentage / 100.0)
  # end

  # GOOD: Memoization
  def discounted_price
    @discounted_price ||= price * (1 - discount_percentage / 100.0)
  end

  # With arguments (more complex)
  def reviews_by_rating(rating)
    @reviews_by_rating ||= {}
    @reviews_by_rating[rating] ||= reviews.where(rating: rating).to_a
  end
end

# CAUTION: Memoization persists for object lifetime
# Clear if needed: @discounted_price = nil

# ==============================================================================
# PATTERN 13: Database Connection Pooling
# ==============================================================================

# config/database.yml
production:
  adapter: postgresql
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  # One connection per thread

# With Solid Queue workers, increase pool:
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } + 10 %>
  # +10 for background workers

# ==============================================================================
# PATTERN 14: Asset Optimization
# ==============================================================================

# config/environments/production.rb
Rails.application.configure do
  # Enable asset digest (fingerprinting)
  config.assets.digest = true

  # Don't compile assets at runtime
  config.assets.compile = false

  # Compress CSS/JS (Thruster handles this in Rails 8)
  config.assets.css_compressor = :sass
  config.assets.js_compressor = :terser  # If using build

  # Use CDN
  config.asset_host = 'https://cdn.example.com'

  # Serve static files (needed for Thruster)
  config.public_file_server.enabled = true

  # Set long cache expiry for assets
  config.public_file_server.headers = {
    'Cache-Control' => 'public, max-age=31536000, immutable'
  }
end

# ==============================================================================
# PATTERN 15: Monitoring and Profiling
# ==============================================================================

# Use Rack Mini Profiler in development
# Gemfile:
# gem 'rack-mini-profiler', group: :development

# Profile specific code blocks
result = Benchmark.ms do
  expensive_operation
end
Rails.logger.debug "Operation took #{result}ms"

# Memory profiling
require 'memory_profiler'

report = MemoryProfiler.report do
  1000.times { Product.create!(name: "Test") }
end

report.pretty_print

# ==============================================================================
# KEY TAKEAWAYS
# ==============================================================================

# 1. DATABASE OPTIMIZATION:
#    - Prevent N+1 with includes/preload/eager_load
#    - Add indexes on foreign keys and WHERE columns
#    - Use select to limit columns
#    - Use pluck for value extraction
#    - Batch process with find_each
#
# 2. CACHING:
#    - Fragment caching for views
#    - Russian doll caching for nested content
#    - Low-level caching for expensive operations
#    - Collection caching for lists
#    - Solid Cache in Rails 8
#
# 3. QUERY OPTIMIZATION:
#    - Use exists? not any?
#    - Use size not length
#    - Use update_all not each.update
#    - Use counter_cache for counts
#
# 4. CODE OPTIMIZATION:
#    - Memoize repeated calculations
#    - Move slow work to background jobs
#    - Use YJIT (Rails 8 default)
#    - Profile before optimizing
#
# Master these patterns and your Rails app will scale beautifully!
