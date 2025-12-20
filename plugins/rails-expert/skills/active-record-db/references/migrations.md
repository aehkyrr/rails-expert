# Database Migrations: Complete Guide

## What Are Migrations?

Migrations are version-controlled Ruby scripts that modify database schema. They allow you to:
- Create and modify tables
- Add and remove columns
- Create indexes and foreign keys
- Transform data
- Work collaboratively without schema conflicts

Migrations are the **only** way to modify schema in Rails. Never edit the database directly.

## Creating Migrations

### Via Generators

```bash
# Create table migration
rails generate migration CreateProducts name:string price:decimal

# Add column migration
rails generate migration AddDescriptionToProducts description:text

# Remove column migration
rails generate migration RemoveQuantityFromProducts quantity:integer

# Add reference (foreign key)
rails generate migration AddCategoryToProducts category:references

# Add index
rails generate migration AddIndexToProductsName
```

Rails infers migration structure from the name:
- `CreateXXX` → `create_table`
- `AddXXXToYYY` → `add_column`
- `RemoveXXXFromYYY` → `remove_column`

### Migration File Structure

```ruby
class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    # Reversible operations go here
  end
end
```

Migration version (`[8.0]`) ensures compatibility with future Rails versions.

## Basic Migration Operations

### Creating Tables

```ruby
class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      # Column types
      t.string :name, null: false
      t.text :description
      t.integer :quantity, default: 0
      t.decimal :price, precision: 10, scale: 2
      t.boolean :available, default: true
      t.date :release_date
      t.datetime :published_at
      t.json :metadata
      t.binary :image_data

      # Special columns
      t.timestamps  # created_at, updated_at

      # Indexes
      t.index :name
      t.index [:category_id, :name], unique: true
    end
  end
end
```

### Column Types

| Type | Description | Example |
|------|-------------|---------|
| `:string` | VARCHAR (limit: 255) | Short text |
| `:text` | TEXT | Long text |
| `:integer` | INTEGER | Whole numbers |
| `:bigint` | BIGINT | Large integers |
| `:float` | FLOAT | Decimals (imprecise) |
| `:decimal` | DECIMAL | Exact decimals |
| `:boolean` | BOOLEAN | true/false |
| `:date` | DATE | Date only |
| `:datetime` | DATETIME | Date + time |
| `:time` | TIME | Time only |
| `:binary` | BLOB | Binary data |
| `:json` | JSON | JSON data (PG/MySQL 5.7+) |
| `:jsonb` | JSONB | Binary JSON (PG) |

### Column Options

```ruby
t.string :name,
  null: false,          # NOT NULL constraint
  default: "Unknown",   # Default value
  limit: 100,           # Max length
  comment: "Product name"  # Column comment

t.decimal :price,
  precision: 10,        # Total digits
  scale: 2              # Decimal places

t.string :tags,
  array: true,          # Array column (PostgreSQL)
  default: []
```

### Adding Columns

```ruby
def change
  add_column :products, :featured, :boolean, default: false
  add_column :products, :sale_price, :decimal, precision: 10, scale: 2
  add_column :products, :metadata, :jsonb, default: {}
end
```

### Removing Columns

```ruby
def change
  remove_column :products, :old_field, :string
  # Include type for reversibility
end
```

### Renaming Columns

```ruby
def change
  rename_column :products, :desc, :description
end
```

### Changing Columns

```ruby
def change
  change_column :products, :price, :decimal, precision: 12, scale: 2
  change_column_null :products, :name, false  # Add NOT NULL
  change_column_default :products, :available, from: nil, to: true
end
```

## References and Foreign Keys

### Adding References

```ruby
def change
  add_reference :products, :category, foreign_key: true
  # Creates: category_id column + index + foreign key constraint
end
```

### Polymorphic References

```ruby
def change
  add_reference :comments, :commentable, polymorphic: true
  # Creates: commentable_id + commentable_type columns + index
end
```

### Custom Foreign Keys

```ruby
def change
  add_foreign_key :products, :categories
  add_foreign_key :products, :users, column: :author_id
  add_foreign_key :products, :categories, on_delete: :cascade
end
```

## Indexes

### Creating Indexes

```ruby
def change
  # Single column
  add_index :products, :name

  # Multiple columns (composite)
  add_index :products, [:category_id, :created_at]

  # Unique index
  add_index :products, :sku, unique: true

  # Partial index (PostgreSQL)
  add_index :products, :name, where: "available = true"

  # Custom name
  add_index :products, :long_column_name, name: "idx_long_col"
end
```

### Index Types

```ruby
# B-tree (default)
add_index :products, :name

# GIN (PostgreSQL, for arrays/JSON)
add_index :products, :tags, using: :gin

# GiST (PostgreSQL, for full-text)
add_index :products, :description, using: :gist
```

### Removing Indexes

```ruby
def change
  remove_index :products, :name
  remove_index :products, column: [:category_id, :created_at]
  remove_index :products, name: "idx_long_col"
end
```

## Reversible Migrations

### change Method (Preferred)

Most migrations are automatically reversible:

```ruby
def change
  create_table :products do |t|
    t.string :name
    t.timestamps
  end

  add_index :products, :name
end

# Rails knows how to reverse:
# - drop_table :products
# - remove_index :products, :name
```

### up/down Methods

For non-reversible operations:

```ruby
def up
  execute "UPDATE products SET name = UPPER(name)"
end

def down
  execute "UPDATE products SET name = LOWER(name)"
end
```

### reversible Block

Explicit reversibility:

```ruby
def change
  reversible do |dir|
    dir.up do
      execute "CREATE INDEX CONCURRENTLY idx_name ON products(name)"
    end

    dir.down do
      execute "DROP INDEX CONCURRENTLY idx_name"
    end
  end
end
```

## Running Migrations

### Commands

```bash
# Run all pending migrations
rails db:migrate

# Rollback last migration
rails db:rollback

# Rollback last N migrations
rails db:rollback STEP=3

# Migrate to specific version
rails db:migrate VERSION=20240115100000

# Redo last migration (rollback + migrate)
rails db:migrate:redo

# Show migration status
rails db:migrate:status

# Reset database (drop + create + migrate)
rails db:reset

# Drop, create, migrate, seed
rails db:setup
```

### Migration States

```
Status   Migration ID    Migration Name
--------------------------------------------------
  up     20240115100000  Create products
  up     20240115110000  Add description to products
  down   20240115120000  Create categories
```

## Data Migrations

Transform data during schema changes:

```ruby
class AddSlugToProducts < ActiveRecord::Migration[8.0]
  def up
    add_column :products, :slug, :string
    add_index :products, :slug, unique: true

    # Populate slug from name
    Product.find_each do |product|
      product.update_column(:slug, product.name.parameterize)
    end

    change_column_null :products, :slug, false
  end

  def down
    remove_column :products, :slug
  end
end
```

**Important:** Use `update_column` to skip validations and callbacks in migrations.

## Advanced Patterns

### Separating Schema and Data

```ruby
# db/migrate/20240115100000_add_slug_to_products.rb
class AddSlugToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :slug, :string
    add_index :products, :slug, unique: true
  end
end

# db/migrate/20240115110000_populate_product_slugs.rb
class PopulateProductSlugs < ActiveRecord::Migration[8.0]
  def up
    Product.find_each do |product|
      product.update_column(:slug, product.name.parameterize)
    end
  end

  def down
    # No-op: can't reverse data population
  end
end

# db/migrate/20240115120000_make_slug_required.rb
class MakeSlugRequired < ActiveRecord::Migration[8.0]
  def change
    change_column_null :products, :slug, false
  end
end
```

This pattern allows rolling back schema changes without data loss.

### Large Table Migrations

For tables with millions of rows:

```ruby
class AddIndexToLargeTable < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!  # Required for CONCURRENTLY

  def change
    add_index :products, :name, algorithm: :concurrently
  end
end
```

PostgreSQL's `CONCURRENTLY` option adds indexes without locking the table.

### Conditional Migrations

```ruby
def change
  unless column_exists?(:products, :slug)
    add_column :products, :slug, :string
  end

  if index_exists?(:products, :old_index)
    remove_index :products, name: :old_index
  end
end
```

Useful for migrations that might run multiple times.

## Database-Specific Features

### PostgreSQL Extensions

```ruby
def change
  enable_extension "pg_trgm"  # Trigram similarity
  enable_extension "uuid-ossp"  # UUID generation
  enable_extension "hstore"  # Key-value store
end
```

### Constraint Checks

```ruby
# PostgreSQL
def change
  execute <<-SQL
    ALTER TABLE products
    ADD CONSTRAINT positive_price CHECK (price > 0)
  SQL
end

# Or use add_check_constraint (Rails 6.1+)
def change
  add_check_constraint :products, "price > 0", name: "positive_price"
end
```

## Migration Best Practices

### 1. Always Be Reversible

```ruby
# GOOD - Reversible
def change
  add_column :products, :featured, :boolean, default: false
end

# BAD - Not reversible without down method
def change
  execute "UPDATE products SET price = price * 1.1"
end

# GOOD - Explicitly reversible
def up
  execute "UPDATE products SET price = price * 1.1"
end

def down
  execute "UPDATE products SET price = price / 1.1"
end
```

### 2. Include Column Type in remove_column

```ruby
# GOOD
remove_column :products, :old_field, :string

# BAD (not reversible)
remove_column :products, :old_field
```

### 3. Add Indexes for Foreign Keys

```ruby
# GOOD
add_reference :products, :category, foreign_key: true  # Includes index

# BAD (no index, slow joins)
add_column :products, :category_id, :integer
add_foreign_key :products, :categories
```

### 4. Use change_column_default Safely

```ruby
# GOOD (reversible)
change_column_default :products, :available, from: nil, to: true

# BAD (not reversible)
change_column_default :products, :available, true
```

### 5. Avoid Changing Migrations After Commit

Once committed to version control and run in production:
- **Never edit existing migrations**
- **Create new migrations** to make further changes

### 6. Test Migrations

```ruby
# test/db/migrate/...
require "test_helper"

class AddSlugToProductsTest < ActiveSupport::TestCase
  test "adds slug column" do
    migrate!
    assert_column :products, :slug, :string
  end

  test "slug is unique" do
    migrate!
    assert_index :products, :slug, unique: true
  end
end
```

### 7. Use transactions

Rails wraps migrations in transactions by default (except MySQL). For large data changes:

```ruby
def change
  Product.transaction do
    Product.find_each do |product|
      product.update!(slug: product.name.parameterize)
    end
  end
end
```

### 8. Document Complex Migrations

```ruby
class ComplexDataTransformation < ActiveRecord::Migration[8.0]
  # This migration:
  # 1. Adds normalized price column
  # 2. Converts prices from cents to dollars
  # 3. Removes old price_cents column
  #
  # Duration: ~5 minutes on production (1M records)
  # Safe to rollback: Yes

  def change
    # Implementation...
  end
end
```

## Troubleshooting

### Migration Failed Mid-Run

```bash
# Fix the issue, then:
rails db:migrate
# Rails tracks which migrations completed
```

### Reset Migration Status

```bash
# Mark migration as run (without executing)
rails db:migrate:up VERSION=20240115100000

# Mark migration as not run
rails db:migrate:down VERSION=20240115100000
```

### Fixing Schema Drift

```ruby
# Generate migration from current schema
rails db:schema:load  # Load db/schema.rb
rails db:migrate  # Run any new migrations
```

### Squashing Migrations

For old applications with hundreds of migrations:

```bash
# 1. Reset to clean schema
rails db:reset

# 2. Dump current schema
rails db:schema:dump

# 3. Delete old migrations
rm db/migrate/2015*.rb

# 4. Create single migration from schema
rails generate migration ConsolidateSchema

# 5. Edit migration to create all tables
# (copy from schema.rb)
```

## Schema vs SQL

Rails generates `db/schema.rb` (default) or `db/structure.sql`:

### schema.rb (Default)

```ruby
# db/schema.rb
ActiveRecord::Schema[8.0].define(version: 2024_01_15_120000) do
  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2
    t.timestamps
  end
end
```

**Pros:** Database-agnostic, readable, easy to diff
**Cons:** Can't represent all database features

### structure.sql

```sql
-- db/structure.sql
CREATE TABLE products (
  id bigserial primary key,
  name varchar(255) NOT NULL,
  price decimal(10,2),
  created_at timestamp NOT NULL,
  updated_at timestamp NOT NULL
);
```

**Pros:** Exact representation, includes views/triggers/functions
**Cons:** Database-specific, harder to diff

Configure in `config/application.rb`:

```ruby
config.active_record.schema_format = :sql
```

## Conclusion

Migrations are the foundation of schema evolution in Rails:
- Always be reversible
- Add indexes for foreign keys
- Never edit committed migrations
- Use data migrations carefully
- Test complex migrations
- Document unusual operations

Master migrations and you control your database with confidence.
