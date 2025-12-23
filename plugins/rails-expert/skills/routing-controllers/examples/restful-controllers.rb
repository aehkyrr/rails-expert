# RESTful Controllers: Complete CRUD Example
#
# This file demonstrates a complete, idiomatic Rails controller
# following RESTful conventions and best practices.

# ==============================================================================
# Routes (config/routes.rb)
# ==============================================================================

Rails.application.routes.draw do
  resources :products do
    member do
      post :duplicate
      get :preview
    end

    collection do
      get :search
      get :export
    end
  end

  # Nested resources (shallow)
  resources :categories do
    resources :products, shallow: true, only: [:index, :new, :create]
  end
end

# ==============================================================================
# Controller (app/controllers/products_controller.rb)
# ==============================================================================

class ProductsController < ApplicationController
  # Callbacks - run before actions
  before_action :set_product, only: [:show, :edit, :update, :destroy, :duplicate, :preview]
  before_action :require_login, except: [:index, :show]
  before_action :authorize_edit, only: [:edit, :update, :destroy]

  # GET /products
  # List all products
  def index
    @products = Product.includes(:category).order(created_at: :desc).page(params[:page])

    respond_to do |format|
      format.html  # Renders index.html.erb
      format.json { render json: @products }
      format.csv  { send_data @products.to_csv, filename: "products-#{Date.today}.csv" }
    end
  end

  # GET /products/:id
  # Show single product
  def show
    # @product set by before_action

    respond_to do |format|
      format.html  # Renders show.html.erb
      format.json { render json: @product }
    end
  end

  # GET /products/new
  # Form for new product
  def new
    @product = Product.new
    @categories = Category.all.order(:name)
  end

  # POST /products
  # Create new product
  def create
    # Rails 8: Using params.expect
    @product = Product.new(params.expect(product: [
      :name, :description, :price, :category_id, :image, tag_ids: []
    ]))
    @product.user = current_user

    if @product.save
      redirect_to @product, notice: 'Product created successfully!'
    else
      @categories = Category.all.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  # GET /products/:id/edit
  # Form for editing product
  def edit
    # @product set by before_action
    @categories = Category.all.order(:name)
  end

  # PATCH/PUT /products/:id
  # Update existing product
  def update
    # @product set by before_action

    if @product.update(params.expect(product: [
      :name, :description, :price, :category_id, :image, tag_ids: []
    ]))
      redirect_to @product, notice: 'Product updated successfully!'
    else
      @categories = Category.all.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /products/:id
  # Delete product
  def destroy
    # @product set by before_action

    @product.destroy
    redirect_to products_path, notice: 'Product deleted successfully!'
  end

  # POST /products/:id/duplicate
  # Custom member action - duplicate a product
  def duplicate
    # @product set by before_action

    @new_product = @product.dup
    @new_product.name = "#{@product.name} (Copy)"

    if @new_product.save
      redirect_to @new_product, notice: 'Product duplicated successfully!'
    else
      redirect_to @product, alert: 'Failed to duplicate product'
    end
  end

  # GET /products/:id/preview
  # Custom member action - preview product
  def preview
    # @product set by before_action
    # Renders preview.html.erb
  end

  # GET /products/search
  # Custom collection action - search products
  def search
    @query = params[:q]
    @products = Product.search(@query).page(params[:page])

    render :index
  end

  # GET /products/export
  # Custom collection action - export all products
  def export
    @products = Product.all

    respond_to do |format|
      format.csv { send_data @products.to_csv, filename: "products-#{Date.today}.csv" }
      format.xlsx { send_data @products.to_xlsx, filename: "products-#{Date.today}.xlsx" }
    end
  end

  private

  # Callbacks

  def set_product
    @product = Product.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to products_path, alert: 'Product not found'
  end

  def require_login
    unless logged_in?
      flash[:alert] = 'Please log in to continue'
      redirect_to login_path
    end
  end

  def authorize_edit
    unless @product.editable_by?(current_user)
      redirect_to @product, alert: 'You are not authorized to edit this product'
    end
  end

  # Traditional strong parameters (still works)
  def product_params_traditional
    params.require(:product).permit(
      :name,
      :description,
      :price,
      :category_id,
      :image,
      tag_ids: []
    )
  end
end

# ==============================================================================
# Controller Concerns: Shared Behavior
# ==============================================================================

# app/controllers/concerns/authenticable.rb
module Authenticable
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :logged_in?
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in?
      flash[:alert] = 'Please log in to continue'
      redirect_to login_path
    end
  end
end

# app/controllers/concerns/paginatable.rb
module Paginatable
  extend ActiveSupport::Concern

  private

  def pagination_params
    {
      page: params.fetch(:page, 1).to_i,
      per_page: params.fetch(:per_page, 25).to_i.clamp(1, 100)
    }
  end
end

# Use in controller
class ProductsController < ApplicationController
  include Authenticable
  include Paginatable

  def index
    @products = Product.page(pagination_params[:page])
                      .per(pagination_params[:per_page])
  end
end

# ==============================================================================
# Nested Resource Controller
# ==============================================================================

class CategoriesProductsController < ApplicationController
  before_action :set_category

  # GET /categories/:category_id/products
  def index
    @products = @category.products.order(created_at: :desc)
  end

  # GET /categories/:category_id/products/new
  def new
    @product = @category.products.new
  end

  # POST /categories/:category_id/products
  def create
    @product = @category.products.new(params.expect(product: [:name, :price]))

    if @product.save
      redirect_to category_products_path(@category), notice: 'Product created!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_category
    @category = Category.find(params[:category_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to categories_path, alert: 'Category not found'
  end
end

# ==============================================================================
# API Controller Example
# ==============================================================================

module Api
  module V1
    class ProductsController < ApiController
      skip_before_action :verify_authenticity_token  # No CSRF for API

      # GET /api/v1/products
      def index
        @products = Product.all
        render json: @products, status: :ok
      end

      # POST /api/v1/products
      def create
        @product = Product.new(params.expect(product: [:name, :price]))

        if @product.save
          render json: @product, status: :created
        else
          render json: { errors: @product.errors }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/products/:id
      def update
        @product = Product.find(params[:id])

        if @product.update(params.expect(product: [:name, :price]))
          render json: @product, status: :ok
        else
          render json: { errors: @product.errors }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/products/:id
      def destroy
        @product = Product.find(params[:id])
        @product.destroy

        head :no_content
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Not found' }, status: :not_found
      end
    end
  end
end

# ==============================================================================
# Key Takeaways
# ==============================================================================

# 1. STANDARD CRUD PATTERN:
#    - before_action for common setup
#    - Descriptive action names (index, show, new, create, etc.)
#    - Redirect after successful mutations
#    - Render after failed mutations (with status)
#
# 2. STRONG PARAMETERS (Rails 8):
#    - Use params.expect for clearer syntax
#    - Whitelist only safe attributes
#    - Handle nested parameters explicitly
#
# 3. KEEP CONTROLLERS THIN:
#    - Business logic in models
#    - Complex operations in service objects
#    - Shared behavior in concerns
#
# 4. CONVENTIONAL RESPONSES:
#    - redirect_to for successful mutations
#    - render for failed mutations
#    - Appropriate flash messages
#    - HTTP status codes (especially for APIs)
#
# 5. ERROR HANDLING:
#    - Rescue ActiveRecord::RecordNotFound
#    - Provide user-friendly error messages
#    - Use appropriate HTTP status codes
#
# 6. RESPONDERS:
#    - Use respond_to for multiple formats
#    - HTML, JSON, CSV, etc.
#
# Master these patterns and you'll write clean, maintainable Rails controllers.
