# Fat Models, Skinny Controllers
#
# This Rails principle states that business logic belongs in models (and service
# objects), not controllers. Controllers should only handle HTTP concerns:
# parsing requests, delegating to models, and rendering responses.
#
# This file demonstrates the principle through real-world examples.

# ==============================================================================
# Example 1: Order Processing - The Classic Case
# ==============================================================================

# Anti-Pattern: Fat Controller with Business Logic
# -------------------------------------------------
# DON'T DO THIS: Controller handles order creation, inventory, payment, email

class OrdersController < ApplicationController
  def create
    @order = Order.new(order_params)
    @order.user = current_user

    # Business logic in controller - BAD!
    @order.subtotal = 0
    @order.line_items.each do |item|
      @order.subtotal += item.product.price * item.quantity

      # Check inventory
      if item.product.stock < item.quantity
        flash[:error] = "#{item.product.name} is out of stock"
        render :new and return # rubocop:disable Lint/NonLocalExitFromIterator
      end
    end

    # Calculate tax and total
    @order.tax = @order.subtotal * 0.0875
    @order.total = @order.subtotal + @order.tax

    # Process payment
    payment_result = Stripe::Charge.create(
      amount: (@order.total * 100).to_i,
      currency: "usd",
      source: params[:stripe_token],
      description: "Order #{@order.id}"
    )

    if payment_result.paid?
      @order.payment_id = payment_result.id
      @order.status = "paid"

      if @order.save
        # Update inventory
        @order.line_items.each do |item|
          item.product.decrement!(:stock, item.quantity)
        end

        # Send confirmation email
        OrderMailer.confirmation(@order).deliver_later

        redirect_to @order, notice: "Order placed successfully!"
      else
        render :new
      end
    else
      flash[:error] = "Payment failed"
      render :new
    end
  rescue Stripe::CardError => e
    flash[:error] = e.message
    render :new
  end
end

# DRY Solution: Skinny Controller + Fat Model/Service
# ----------------------------------------------------

# The controller now only handles HTTP concerns
class OrdersController < ApplicationController
  def create
    @order = Order.new(order_params)
    @order.user = current_user

    result = OrderPlacementService.new(@order, params[:stripe_token]).call

    if result.success?
      redirect_to @order, notice: "Order placed successfully!"
    else
      flash[:error] = result.error
      render :new
    end
  end
end

# Business logic lives in a service object
class OrderPlacementService
  attr_reader :order, :stripe_token, :error

  def initialize(order, stripe_token)
    @order = order
    @stripe_token = stripe_token
  end

  def call
    return failure("Insufficient stock") unless check_inventory
    calculate_totals
    return failure("Payment failed: #{payment_error}") unless process_payment
    return failure("Could not save order") unless save_order
    update_inventory
    send_confirmation
    success
  end

  private

  def check_inventory
    order.line_items.all? do |item|
      item.product.stock >= item.quantity
    end
  end

  def calculate_totals
    order.calculate_totals  # Delegated to model
  end

  def process_payment # rubocop:disable Naming/PredicateMethod
    result = PaymentProcessor.charge(
      amount: order.total,
      token: stripe_token,
      description: "Order #{order.id}"
    )
    order.payment_id = result.id if result.success?
    @payment_error = result.error unless result.success?
    result.success?
  end

  def save_order
    order.status = "paid"
    order.save
  end

  def update_inventory
    order.line_items.each do |item|
      item.product.decrement!(:stock, item.quantity)
    end
  end

  def send_confirmation
    OrderMailer.confirmation(order).deliver_later
  end

  # rubocop:disable Style/OpenStructUse
  def success
    OpenStruct.new(success?: true)
  end

  def failure(message)
    OpenStruct.new(success?: false, error: message)
  end
  # rubocop:enable Style/OpenStructUse

  attr_reader :payment_error
end

# Model handles its own calculations
class Order < ApplicationRecord
  has_many :line_items
  belongs_to :user

  TAX_RATE = 0.0875

  def calculate_totals
    self.subtotal = line_items.sum { |item| item.product.price * item.quantity }
    self.tax = subtotal * TAX_RATE
    self.total = subtotal + tax
  end
end

# ==============================================================================
# Example 2: User Registration with Complex Validation
# ==============================================================================

# Anti-Pattern: Controller with Validation Logic
# -----------------------------------------------

class UsersController < ApplicationController
  def create
    @user = User.new(user_params)

    # Business logic in controller - BAD!
    if params[:password].length < 8
      flash.now[:error] = "Password must be at least 8 characters"
      render :new and return
    end

    if params[:password] != params[:password_confirmation]
      flash.now[:error] = "Passwords don't match"
      render :new and return
    end

    if User.exists?(email: params[:email].downcase)
      flash.now[:error] = "Email already taken"
      render :new and return
    end

    @user.email = params[:email].downcase
    @user.password_digest = BCrypt::Password.create(params[:password])

    if @user.save
      # Create default settings
      @user.create_settings(theme: "light", notifications: true)

      # Send welcome email
      UserMailer.welcome(@user).deliver_later

      # Track signup
      Analytics.track("user_signed_up", user_id: @user.id)

      redirect_to dashboard_path
    else
      render :new
    end
  end
end

# DRY Solution: Model Handles Validation and Callbacks
# -----------------------------------------------------

class UsersController < ApplicationController
  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to dashboard_path, notice: "Welcome!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :name)
  end
end

# Model handles all business logic
class User < ApplicationRecord
  has_secure_password
  has_one :settings, dependent: :destroy

  # Validations belong in the model
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: :password_required?
  validates :name, presence: true

  # Normalization belongs in the model
  before_validation :normalize_email

  # Side effects triggered by model lifecycle
  after_create :create_default_settings
  after_create :send_welcome_email
  after_create :track_signup

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end

  def password_required?
    new_record? || password.present?
  end

  def create_default_settings
    create_settings(theme: "light", notifications: true)
  end

  def send_welcome_email
    UserMailer.welcome(self).deliver_later
  end

  def track_signup
    Analytics.track("user_signed_up", user_id: id)
  end
end

# ==============================================================================
# Example 3: Query Objects for Complex Queries
# ==============================================================================

# Anti-Pattern: Complex Queries in Controller
# --------------------------------------------

class ReportsController < ApplicationController
  def sales
    # Complex query logic in controller - BAD!
    if params[:region].present?
      @orders = Order
        .joins(:line_items, :user)
        .where(status: "completed")
        .where("orders.created_at BETWEEN ? AND ?", params[:start_date], params[:end_date])
        .where(users: { region: params[:region] })
    end

    @orders = @orders.where("orders.total >= ?", params[:min_total]) if params[:min_total].present?

    @total_revenue = @orders.sum(:total)
    @average_order = @orders.average(:total)
    @order_count = @orders.count

    @top_products = LineItem
      .joins(:order, :product)
      .where(orders: { id: @orders.select(:id) })
      .group("products.id", "products.name")
      .select("products.name, SUM(line_items.quantity) as total_quantity")
      .order(total_quantity: :desc)
      .limit(10)
  end
end

# DRY Solution: Query Object
# ---------------------------

class ReportsController < ApplicationController
  def sales
    query = SalesReportQuery.new(
      start_date: params[:start_date],
      end_date: params[:end_date],
      region: params[:region],
      min_total: params[:min_total]
    )

    @orders = query.orders
    @total_revenue = query.total_revenue
    @average_order = query.average_order
    @order_count = query.order_count
    @top_products = query.top_products
  end
end

# Query object encapsulates complex query logic
class SalesReportQuery
  def initialize(start_date:, end_date:, region: nil, min_total: nil)
    @start_date = start_date
    @end_date = end_date
    @region = region
    @min_total = min_total
  end

  def orders
    @orders ||= build_orders_query
  end

  def total_revenue
    orders.sum(:total)
  end

  def average_order
    orders.average(:total)
  end

  def order_count
    orders.count
  end

  def top_products
    LineItem
      .joins(:order, :product)
      .where(orders: { id: orders.select(:id) })
      .group("products.id", "products.name")
      .select("products.name, SUM(line_items.quantity) as total_quantity")
      .order(total_quantity: :desc)
      .limit(10)
  end

  private

  def build_orders_query
    query = Order
      .joins(:line_items, :user)
      .where(status: "completed")
      .where(created_at: @start_date..@end_date)

    query = query.where(users: { region: @region }) if @region.present?
    query = query.where("orders.total >= ?", @min_total) if @min_total.present?
    query
  end
end

# ==============================================================================
# Example 4: Form Objects for Complex Forms
# ==============================================================================

# Anti-Pattern: Controller Handling Multi-Model Form
# ---------------------------------------------------

class RegistrationsController < ApplicationController
  def create
    # Controller managing multiple models - BAD!
    @user = User.new(user_params)
    @company = Company.new(company_params)
    @subscription = Subscription.new(subscription_params)

    ActiveRecord::Base.transaction do
      @user.save!
      @company.owner = @user
      @company.save!
      @subscription.company = @company
      @subscription.save!
    end

    redirect_to dashboard_path
  rescue ActiveRecord::RecordInvalid => e
    # Which model failed? Hard to tell!
    render :new
  end
end

# DRY Solution: Form Object
# --------------------------

class RegistrationsController < ApplicationController
  def create
    @registration = RegistrationForm.new(registration_params)

    if @registration.save
      redirect_to dashboard_path, notice: "Welcome!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:registration).permit(
      :user_name, :user_email, :user_password,
      :company_name, :company_industry,
      :plan
    )
  end
end

# Form object handles multi-model form logic
class RegistrationForm
  include ActiveModel::Model
  include ActiveModel::Validations

  attr_accessor :user_name, :user_email, :user_password,
                :company_name, :company_industry,
                :plan

  validates :user_name, :user_email, :user_password, presence: true
  validates :company_name, presence: true
  validates :plan, inclusion: { in: %w[starter professional enterprise] }

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      create_user
      create_company
      create_subscription
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  attr_reader :user, :company

  private

  def create_user
    @user = User.create!(
      name: user_name,
      email: user_email,
      password: user_password
    )
  end

  def create_company
    @company = Company.create!(
      name: company_name,
      industry: company_industry,
      owner: @user
    )
  end

  def create_subscription
    @subscription = Subscription.create!(
      company: @company,
      plan: plan
    )
  end
end

# ==============================================================================
# Example 5: Presenter/Decorator for View Logic
# ==============================================================================

# Anti-Pattern: Complex View Logic in Controller
# -----------------------------------------------

class DashboardController < ApplicationController
  def show
    @user = current_user

    # View logic in controller - BAD!
    @display_name = @user.name.presence || @user.email.split("@").first
    @member_since = @user.created_at.strftime("%B %Y")
    @avatar_url = @user.avatar.attached? ? url_for(@user.avatar) : "/default-avatar.png"
    @subscription_status = @user.subscription&.active? ? "Active" : "Inactive"
    @subscription_badge_class = @user.subscription&.active? ? "bg-success" : "bg-danger"
  end
end

# DRY Solution: Presenter/Decorator
# -----------------------------------

class DashboardController < ApplicationController
  def show
    @user = UserPresenter.new(current_user, view_context)
  end
end

# Presenter handles all view/display logic
class UserPresenter < SimpleDelegator
  def initialize(user, view_context)
    super(user)
    @view = view_context
  end

  def display_name
    name.presence || email.split("@").first.titleize
  end

  def member_since
    created_at.strftime("%B %Y")
  end

  def avatar_url
    if avatar.attached?
      @view.url_for(avatar)
    else
      "/images/default-avatar.png"
    end
  end

  def subscription_status
    subscription&.active? ? "Active" : "Inactive"
  end

  def subscription_badge_class
    subscription&.active? ? "bg-success" : "bg-danger"
  end

  def greeting
    hour = Time.current.hour
    period = case hour
             when 5..11 then "morning"
             when 12..16 then "afternoon"
             else "evening"
             end
    "Good #{period}, #{display_name}!"
  end
end

# ==============================================================================
# Summary: What Goes Where?
# ==============================================================================

# CONTROLLER (Skinny):
# - Parse request params
# - Authenticate/authorize
# - Call model/service
# - Render response
# - Flash messages
# - Redirects

# MODEL (Fat):
# - Validations
# - Associations
# - Scopes
# - Callbacks
# - Business logic methods
# - State machines

# SERVICE OBJECTS:
# - Complex operations spanning multiple models
# - External API integrations
# - Operations with side effects
# - Anything requiring transaction management

# QUERY OBJECTS:
# - Complex database queries
# - Queries with many optional filters
# - Queries used in multiple places

# FORM OBJECTS:
# - Forms that create/update multiple models
# - Virtual forms (no direct model)
# - Complex validation scenarios

# PRESENTERS/DECORATORS:
# - Formatting for display
# - Computed display values
# - View-specific logic

# ==============================================================================
# Benefits of Fat Models, Skinny Controllers
# ==============================================================================

# 1. TESTABILITY
#    - Models and services are easy to unit test
#    - No HTTP setup required
#    - Faster test suite

# 2. REUSABILITY
#    - Business logic can be called from anywhere
#    - API controllers, background jobs, console
#    - Not tied to HTTP request/response

# 3. MAINTAINABILITY
#    - Clear separation of concerns
#    - Easy to find where logic lives
#    - Changes are localized

# 4. READABILITY
#    - Controllers tell a story at high level
#    - Details are hidden in appropriate places
#    - New developers can understand flow quickly
