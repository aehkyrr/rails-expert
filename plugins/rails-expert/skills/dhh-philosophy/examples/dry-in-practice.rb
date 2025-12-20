# DRY (Don't Repeat Yourself) in Practice
#
# This file demonstrates the DRY principle through real-world Rails examples.
# Each section shows an anti-pattern (repetitive code) followed by the DRY solution.

# ==============================================================================
# Example 1: Model Concerns - Shared Behavior Across Models
# ==============================================================================

# Anti-Pattern: Duplicated soft-delete logic in multiple models
# -------------------------------------------------------------

class Post < ApplicationRecord
  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  def soft_delete
    update(deleted_at: Time.current)
  end

  def restore
    update(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end
end

class Comment < ApplicationRecord
  # Same code repeated!
  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  def soft_delete
    update(deleted_at: Time.current)
  end

  def restore
    update(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end
end

# DRY Solution: Extract to a Concern
# -----------------------------------

# app/models/concerns/soft_deletable.rb
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(deleted_at: nil) }
    scope :deleted, -> { where.not(deleted_at: nil) }
    default_scope { active }  # Optional: hide deleted by default
  end

  def soft_delete
    update(deleted_at: Time.current)
  end

  def restore
    update(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  def active?
    !deleted?
  end
end

# Now models simply include the concern
class Post < ApplicationRecord
  include SoftDeletable
  # All soft-delete behavior available automatically
end

class Comment < ApplicationRecord
  include SoftDeletable
  # Same behavior, no duplication
end

class User < ApplicationRecord
  include SoftDeletable
  # Easy to add to new models
end

# ==============================================================================
# Example 2: Controller Before Actions - Shared Setup Logic
# ==============================================================================

# Anti-Pattern: Repeated find logic in every action
# --------------------------------------------------

class ArticlesController < ApplicationController
  def show
    @article = Article.find(params[:id])
    # show logic
  end

  def edit
    @article = Article.find(params[:id])  # Duplicated!
    authorize @article
  end

  def update
    @article = Article.find(params[:id])  # Duplicated again!
    authorize @article                     # Duplicated again!
    if @article.update(article_params)
      redirect_to @article
    else
      render :edit
    end
  end

  def destroy
    @article = Article.find(params[:id])  # Duplicated yet again!
    authorize @article                     # Duplicated yet again!
    @article.destroy
    redirect_to articles_path
  end
end

# DRY Solution: Use before_action
# --------------------------------

class ArticlesController < ApplicationController
  before_action :set_article, only: [:show, :edit, :update, :destroy]
  before_action :authorize_article, only: [:edit, :update, :destroy]

  def show
    # @article already set
  end

  def edit
    # @article already set and authorized
  end

  def update
    # @article already set and authorized
    if @article.update(article_params)
      redirect_to @article
    else
      render :edit
    end
  end

  def destroy
    # @article already set and authorized
    @article.destroy
    redirect_to articles_path
  end

  private

  def set_article
    @article = Article.find(params[:id])  # Single source of truth
  end

  def authorize_article
    authorize @article  # Single authorization point
  end

  def article_params
    params.require(:article).permit(:title, :body, :published_at)
  end
end

# ==============================================================================
# Example 3: View Partials - Reusable UI Components
# ==============================================================================

# Anti-Pattern: Duplicated card markup across views
# --------------------------------------------------

# app/views/articles/index.html.erb
# <% @articles.each do |article| %>
#   <div class="card mb-3">
#     <div class="card-body">
#       <h5 class="card-title"><%= article.title %></h5>
#       <p class="card-text"><%= truncate(article.body, length: 200) %></p>
#       <p class="card-text">
#         <small class="text-muted">
#           By <%= article.author.name %> on <%= article.created_at.strftime("%B %d, %Y") %>
#         </small>
#       </p>
#       <%= link_to "Read more", article, class: "btn btn-primary" %>
#     </div>
#   </div>
# <% end %>

# app/views/users/show.html.erb (showing user's articles)
# <% @user.articles.each do |article| %>
#   <div class="card mb-3">  <!-- Same markup repeated! -->
#     <div class="card-body">
#       <h5 class="card-title"><%= article.title %></h5>
#       <p class="card-text"><%= truncate(article.body, length: 200) %></p>
#       <p class="card-text">
#         <small class="text-muted">
#           By <%= article.author.name %> on <%= article.created_at.strftime("%B %d, %Y") %>
#         </small>
#       </p>
#       <%= link_to "Read more", article, class: "btn btn-primary" %>
#     </div>
#   </div>
# <% end %>

# DRY Solution: Extract to a Partial
# ------------------------------------

# app/views/articles/_article.html.erb
# <div class="card mb-3">
#   <div class="card-body">
#     <h5 class="card-title"><%= article.title %></h5>
#     <p class="card-text"><%= truncate(article.body, length: 200) %></p>
#     <p class="card-text">
#       <small class="text-muted">
#         By <%= article.author.name %> on <%= article.created_at.strftime("%B %d, %Y") %>
#       </small>
#     </p>
#     <%= link_to "Read more", article, class: "btn btn-primary" %>
#   </div>
# </div>

# app/views/articles/index.html.erb
# <%= render @articles %>
# Rails automatically uses _article.html.erb for each article

# app/views/users/show.html.erb
# <%= render @user.articles %>
# Same partial, no duplication

# ==============================================================================
# Example 4: View Helpers - Reusable Formatting Logic
# ==============================================================================

# Anti-Pattern: Repeated formatting in views
# ------------------------------------------

# In multiple views:
# <%= number_to_currency(@product.price, precision: 2, unit: "$", delimiter: ",") %>
# <%= number_to_currency(@order.total, precision: 2, unit: "$", delimiter: ",") %>
# <%= number_to_currency(@cart.subtotal, precision: 2, unit: "$", delimiter: ",") %>

# Status badge repeated everywhere:
# <% if order.pending? %>
#   <span class="badge bg-warning">Pending</span>
# <% elsif order.processing? %>
#   <span class="badge bg-info">Processing</span>
# <% elsif order.completed? %>
#   <span class="badge bg-success">Completed</span>
# <% elsif order.cancelled? %>
#   <span class="badge bg-danger">Cancelled</span>
# <% end %>

# DRY Solution: Extract to Helpers
# ---------------------------------

# app/helpers/application_helper.rb
module ApplicationHelper
  # Consistent currency formatting across the app
  def format_price(amount)
    number_to_currency(amount, precision: 2, unit: "$", delimiter: ",")
  end

  # Reusable status badge with consistent styling
  def status_badge(status)
    colors = {
      pending: "warning",
      processing: "info",
      completed: "success",
      cancelled: "danger",
      active: "success",
      inactive: "secondary"
    }

    color = colors[status.to_sym] || "secondary"
    content_tag(:span, status.to_s.humanize, class: "badge bg-#{color}")
  end

  # Consistent timestamp formatting
  def format_datetime(datetime, format: :long)
    return "N/A" if datetime.nil?

    case format
    when :short
      datetime.strftime("%b %d")
    when :long
      datetime.strftime("%B %d, %Y at %I:%M %p")
    when :relative
      "#{time_ago_in_words(datetime)} ago"
    else
      datetime.to_s
    end
  end
end

# Now in views, simply:
# <%= format_price(@product.price) %>
# <%= status_badge(@order.status) %>
# <%= format_datetime(@article.published_at, format: :relative) %>

# ==============================================================================
# Example 5: Service Objects - Shared Business Logic
# ==============================================================================

# Anti-Pattern: Duplicated order calculation in multiple places
# --------------------------------------------------------------

class OrdersController < ApplicationController
  def create
    @order = Order.new(order_params)
    @order.subtotal = calculate_subtotal(@order.line_items)
    @order.tax = @order.subtotal * 0.0875  # Duplicated tax rate!
    @order.shipping = calculate_shipping(@order)
    @order.total = @order.subtotal + @order.tax + @order.shipping
    # ... rest of creation logic
  end

  private

  def calculate_subtotal(line_items)
    line_items.sum { |item| item.price * item.quantity }
  end
end

class Order < ApplicationRecord
  def recalculate_totals
    self.subtotal = line_items.sum { |item| item.price * item.quantity }  # Duplicated!
    self.tax = subtotal * 0.0875  # Duplicated tax rate!
    self.total = subtotal + tax + shipping
    save
  end
end

# DRY Solution: Extract to a Calculator Service
# -----------------------------------------------

# app/services/order_calculator.rb
class OrderCalculator
  TAX_RATE = 0.0875  # Single source of truth for tax rate

  SHIPPING_RATES = {
    standard: 5.99,
    express: 12.99,
    overnight: 24.99
  }.freeze

  def initialize(order)
    @order = order
  end

  def calculate
    @order.subtotal = calculate_subtotal
    @order.tax = calculate_tax
    @order.shipping = calculate_shipping
    @order.total = calculate_total
    @order
  end

  def calculate_subtotal
    @order.line_items.sum { |item| item.price * item.quantity }
  end

  def calculate_tax
    @order.subtotal * TAX_RATE
  end

  def calculate_shipping
    SHIPPING_RATES[@order.shipping_method&.to_sym] || SHIPPING_RATES[:standard]
  end

  def calculate_total
    @order.subtotal + @order.tax + @order.shipping
  end
end

# Usage in controller
class OrdersController < ApplicationController
  def create
    @order = Order.new(order_params)
    OrderCalculator.new(@order).calculate
    # ... rest of creation logic
  end
end

# Usage in model
class Order < ApplicationRecord
  def recalculate_totals
    OrderCalculator.new(self).calculate
    save
  end
end

# ==============================================================================
# Example 6: Query Scopes - Reusable Database Queries
# ==============================================================================

# Anti-Pattern: Repeated query conditions
# ----------------------------------------

class ReportsController < ApplicationController
  def sales
    @orders = Order.where(status: "completed")
                   .where("created_at >= ?", 30.days.ago)
                   .where("total >= ?", 100)
  end

  def high_value
    @orders = Order.where(status: "completed")  # Duplicated!
                   .where("total >= ?", 100)    # Duplicated!
  end
end

class DashboardController < ApplicationController
  def index
    @recent_orders = Order.where(status: "completed")       # Duplicated!
                          .where("created_at >= ?", 7.days.ago)
  end
end

# DRY Solution: Define Scopes in Model
# -------------------------------------

class Order < ApplicationRecord
  # Reusable scopes
  scope :completed, -> { where(status: "completed") }
  scope :pending, -> { where(status: "pending") }
  scope :recent, ->(days = 30) { where("created_at >= ?", days.days.ago) }
  scope :high_value, ->(threshold = 100) { where("total >= ?", threshold) }

  # Compound scopes for common combinations
  scope :recent_completed, ->(days = 30) { completed.recent(days) }
  scope :high_value_completed, ->(threshold = 100) { completed.high_value(threshold) }
end

# Now controllers are clean and DRY
class ReportsController < ApplicationController
  def sales
    @orders = Order.recent_completed(30).high_value(100)
  end

  def high_value
    @orders = Order.high_value_completed(100)
  end
end

class DashboardController < ApplicationController
  def index
    @recent_orders = Order.recent_completed(7)
  end
end

# ==============================================================================
# Key Takeaways
# ==============================================================================

# DRY is about having a SINGLE SOURCE OF TRUTH for each piece of knowledge:
#
# 1. Behavior → Concerns
#    Extract shared model behavior into concerns that can be included anywhere.
#
# 2. Controller Setup → Before Actions
#    Common setup logic should run automatically before actions that need it.
#
# 3. View Markup → Partials
#    Reusable UI components should be partials, rendered with Rails conventions.
#
# 4. View Logic → Helpers
#    Formatting and display logic should live in helpers, not be scattered in views.
#
# 5. Business Logic → Service Objects
#    Complex calculations and workflows should be encapsulated in dedicated classes.
#
# 6. Query Conditions → Scopes
#    Frequently-used query patterns should be named scopes on the model.
#
# Benefits of DRY:
# - Change in one place → updates everywhere
# - Reduced bugs from inconsistent implementations
# - Easier testing of isolated components
# - Cleaner, more readable code
# - Faster development through reuse
