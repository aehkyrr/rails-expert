# Parallel Testing in Rails

Rails supports running tests in parallel to dramatically reduce test suite execution time. This guide covers configuration, strategies, and troubleshooting.

## Why Parallel Testing?

Large test suites can take minutes or hours to run sequentially. Parallel testing distributes tests across multiple workers, utilizing available CPU cores.

**Benefits:**

- Faster feedback loops during development
- Reduced CI/CD pipeline times
- Better utilization of multi-core machines

## Basic Configuration

Enable parallel testing in `test/test_helper.rb`:

```ruby
class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)
end
```

The `:number_of_processors` option automatically detects available CPU cores.

## Parallelization Strategies

### Process-Based (Default)

Each worker runs in a separate process with its own database:

```ruby
parallelize(workers: :number_of_processors)
```

**Characteristics:**

- Complete isolation between workers
- Each process gets its own database (appended with worker number)
- Higher memory usage
- Best for tests with shared state concerns

**Database naming:** With 4 workers, Rails creates `myapp_test-0`, `myapp_test-1`, `myapp_test-2`, `myapp_test-3`.

### Thread-Based

Workers run as threads within a single process:

```ruby
parallelize(workers: :number_of_processors, with: :threads)
```

**Characteristics:**

- Lower memory footprint
- Shared database connection
- Requires thread-safe code
- Best for I/O-bound tests

**Warning:** Thread-based parallelization requires your application code and tests to be thread-safe.

## Worker Count Configuration

### Fixed Worker Count

```ruby
parallelize(workers: 4)
```

### Environment Variable Override

```bash
PARALLEL_WORKERS=8 rails test
```

The environment variable takes precedence over the configured value.

### Threshold Configuration

Only parallelize when test count exceeds a threshold:

```ruby
parallelize(workers: :number_of_processors, threshold: 50)
```

Tests run sequentially if fewer than 50 tests exist. This avoids parallelization overhead for small test suites.

### Work Stealing

Enable work stealing to improve load balance when test durations vary significantly:

```ruby
parallelize(workers: :number_of_processors, work_stealing: true)
```

**How it works:** When a worker finishes its assigned tests, it can "steal" pending tests from other workers that are still busy. This helps prevent scenarios where one worker finishes early while another is stuck running slow tests.

**Trade-offs:**

- **Pro:** Better utilization when test durations are uneven
- **Pro:** Faster overall completion time for heterogeneous test suites
- **Con:** Less reproducible test distribution between runs
- **Con:** Slightly harder to debug ordering-related failures

**When to use:**

- Test suite has a mix of fast and slow tests
- Some tests are significantly slower (integration, system tests)
- Workers frequently finish at different times

**When to avoid:**

- Need reproducible test distribution for debugging
- All tests have similar execution times
- Investigating intermittent failures related to test ordering

## Setup and Teardown Hooks

### Per-Worker Setup

Run code once when each worker starts:

```ruby
class ActiveSupport::TestCase
  parallelize_setup do |worker|
    # Called once per worker at startup
    # worker is the worker number (0, 1, 2, ...)
    puts "Starting worker #{worker}"

    # Example: Seed test data specific to this worker
    # Example: Initialize external services
  end
end
```

### Per-Worker Teardown

Clean up when each worker finishes:

```ruby
class ActiveSupport::TestCase
  parallelize_teardown do |worker|
    # Called once per worker at shutdown
    puts "Stopping worker #{worker}"

    # Example: Clean up temporary files
    # Example: Close external connections
  end
end
```

### Practical Example

```ruby
class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)

  parallelize_setup do |worker|
    # Create worker-specific upload directory
    FileUtils.mkdir_p(Rails.root.join("tmp/uploads/worker-#{worker}"))

    # Configure worker-specific Redis namespace
    Redis.current = Redis.new(namespace: "test-#{worker}")
  end

  parallelize_teardown do |worker|
    # Clean up worker-specific files
    FileUtils.rm_rf(Rails.root.join("tmp/uploads/worker-#{worker}"))
  end
end
```

## Database Setup for Parallel Tests

### Automatic Database Creation

Rails automatically creates and migrates parallel test databases. Ensure your `database.yml` supports it:

```yaml
test:
  <<: *default
  database: myapp_test<%= ENV['TEST_ENV_NUMBER'] %>
```

The `TEST_ENV_NUMBER` is set automatically by Rails for each worker.

### Manual Database Preparation

If automatic setup fails:

```bash
rails db:test:prepare
PARALLEL_WORKERS=4 rails db:test:prepare
```

## Debugging Flaky Parallel Tests

### Symptoms of Race Conditions

- Tests pass individually but fail in parallel
- Random failures that can't be reproduced consistently
- Different results on different machines

### Isolating Flaky Tests

Run tests sequentially to confirm they pass:

```bash
PARALLEL_WORKERS=1 rails test
```

### Reproducing Failures

Use the seed from the failed run:

```bash
rails test --seed 12345
```

Run specific failing tests repeatedly:

```bash
for i in {1..100}; do rails test test/models/user_test.rb || break; done
```

### Common Causes and Fixes

#### Shared Global State

**Problem:**

```ruby
# BAD: Tests share class variable
class Counter
  @@count = 0

  def self.increment
    @@count += 1
  end
end
```

**Fix:** Use instance variables or thread-local storage.

#### Database Record Dependencies

**Problem:**

```ruby
# BAD: Assumes specific record ID
test "finds first user" do
  assert_equal "Admin", User.find(1).name
end
```

**Fix:** Use fixtures or create records within tests.

```ruby
test "finds user by fixture" do
  assert_equal "Admin", users(:admin).name
end
```

#### Time-Dependent Tests

**Problem:**

```ruby
# BAD: Depends on real time
test "token expires" do
  token = Token.create!
  sleep 2
  assert token.expired?
end
```

**Fix:** Use time helpers.

```ruby
test "token expires" do
  token = Token.create!
  travel 2.seconds
  assert token.expired?
end
```

#### File System Conflicts

**Problem:**

```ruby
# BAD: All workers write to same file
test "exports to CSV" do
  Exporter.export("/tmp/export.csv")
  assert File.exist?("/tmp/export.csv")
end
```

**Fix:** Use worker-specific paths.

```ruby
test "exports to CSV" do
  path = "/tmp/export-#{ENV['TEST_ENV_NUMBER']}.csv"
  Exporter.export(path)
  assert File.exist?(path)
ensure
  FileUtils.rm_f(path)
end
```

## Disabling Parallelization

### For Specific Test Classes

```ruby
class NonParallelTest < ActiveSupport::TestCase
  self.use_transactional_tests = true
  parallelize(workers: 1)

  # Tests run sequentially
end
```

### Globally via Environment

```bash
PARALLEL_WORKERS=1 rails test
```

## Transactional Tests and Parallelization

By default, Rails wraps each test in a database transaction and rolls back after the test completes. This works well with process-based parallelization.

### Disabling Transactional Tests

Some scenarios require disabling transactional tests:

```ruby
class ExternalServiceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    # Manual cleanup needed
    User.delete_all
  end

  test "external service creates user" do
    ExternalService.create_user("test@example.com")
    assert User.exists?(email: "test@example.com")
  end
end
```

**When to disable:**

- Testing code that commits transactions explicitly
- Testing database constraints that require committed data
- Integration with external services that read from the database

## Performance Tips

### Optimal Worker Count

- **CPU-bound tests:** Use number of CPU cores
- **I/O-bound tests:** Can exceed CPU count (try 2x cores)
- **Memory-constrained:** Reduce workers to avoid swapping

### CI/CD Configuration

```yaml
# GitHub Actions example
- name: Run tests
  run: PARALLEL_WORKERS=${{ steps.cpu-cores.outputs.count }} rails test
  env:
    RAILS_ENV: test
```

### Monitoring Parallel Performance

```bash
time PARALLEL_WORKERS=1 rails test  # Baseline
time PARALLEL_WORKERS=4 rails test  # Parallel
time PARALLEL_WORKERS=8 rails test  # More workers
```

Diminishing returns occur when workers exceed available cores or memory becomes constrained.

## Summary

Parallel testing accelerates test suites by utilizing multiple CPU cores:

- **Process-based** (default): Best isolation, higher memory
- **Thread-based**: Lower memory, requires thread-safe code
- **Hooks**: `parallelize_setup` and `parallelize_teardown` for worker lifecycle
- **Debugging**: Isolate flaky tests, check for shared state, use seeds
- **Configuration**: `PARALLEL_WORKERS` environment variable for flexibility

Start with the defaults and adjust based on your test suite characteristics and available resources.
