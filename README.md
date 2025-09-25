# README

This README documents the minimum steps a developer usually needs to get the application running locally and contributing with confidence.

# JetRockets API

  A compact, high-performance REST API in Ruby on Rails backed by PostgreSQL.
  It supports creating posts (with on-demand user creation), rating posts (one vote per user/post with concurrency safety), querying Top N posts by average rating, and listing shared IPs across different authors.
  A fast seeds script generates ~200k posts via the API (not via models) to simulate realistic load.

  # Versions

  Ruby version is 3.4.6

  Rails version is 8.0.3

  # System dependencies:

    - PostgreSQL (9.6+ recommended)

    - Bundler (gem install bundler)

    - cURL (for quick manual API checks)

    - Optional: jq (pretty-print JSON)

  # Configuration

    - Environment variables you may want to set locally:

        RAILS_MAX_THREADS – Puma/ActiveRecord threads (e.g. 16)

        DB_POOL – DB connection pool (match or exceed RAILS_MAX_THREADS)

        RAILS_LOG_LEVEL – e.g. info, warn, debug

        Seeding knobs (only used by db:seed):

          API_BASE (default: http://localhost:3000)

          TOTAL_POSTS (default: 200000)

          USERS_COUNT (default: 100)

          UNIQUE_IPS (default: 50)

          RATED_PERCENT (default: 0.75)

          BATCH (default: 1000)

          PROGRESS_EVERY (default: 10000)

          SEED_FAST (default: 1)

          RATING_THREADS (default: 0 → use 8 for faster seeding)

        Database config is in config/database.yml and respects DB_POOL.


  # Database creation
    - from project root:
        bundle install
        bin/rails db:prepare
    - if you need to reset:
        bin/rails db:drop db:create db:migrate

  # Database initialization

    - Start the app before seeding (in another terminal):
        RAILS_MAX_THREADS=16 DB_POOL=24 RAILS_LOG_LEVEL=warn bin/rails s

    - Run seeds that generate data through the API (fast bulk endpoints):
        RAILS_ENV=development \
        API_BASE=http://localhost:3000 \
        TOTAL_POSTS=200000 USERS_COUNT=100 UNIQUE_IPS=50 \
        RATED_PERCENT=0.75 BATCH=1000 PROGRESS_EVERY=1000 \
        SEED_FAST=1 RATING_THREADS=8 \
        bin/rails db:seed

  # How to run the test suite
    - request + model + routing specs:
        bundle exec rspec
    - linting (passes with the included .rubocop.yml)
        rubocop

  # Notes

    - Data model:
        users(login)
        posts(user_id, title, body, ip:inet)
        ratings(post_id, user_id, value 1..5)

    - Constraints:
        a user can rate a post only once (DB unique index on [post_id, user_id])

    - API:

        POST /posts – create post (auto-creates user by login)

        POST /ratings – rate a post (returns current average)

        GET /posts/top?limit=N – list top posts by average rating

        GET /posts/shared_ips – list IPs used by multiple distinct authors

    - Bulk (used by seeds for efficiency, also available for manual use):

        POST /posts/bulk_create

        POST /ratings/bulk_create

    - Gems used:
        Runtime
          rails (~> 8.0.3) – Web framework.

          pg (~> 1.1) – PostgreSQL adapter for Active Record.

          puma (>= 5.0) – Application web server.

          rack-cors – CORS middleware to allow cross-origin API calls.

          oj – High-performance JSON encoder/decoder.

          bootsnap – Speeds up boot by caching expensive operations.

          solid_cache / solid_queue / solid_cable – Rails 8 “Solid” backends: DB-backed cache, job queue, and Action Cable.

          kamal (optional) – Container/deploy tool (zero-downtime deploys).

          thruster (optional) – HTTP asset caching/compression helpers for Puma.

          tzinfo-data (Windows/JRuby only) – Time zone data.

        Development & test
          rspec-rails (~> 6.1) – Test framework.

          factory_bot_rails – Factories for clean test data.

          shoulda-matchers (~> 6.1) – Concise Rails model/controller matchers.

          faker – Sample/dummy data for tests & seeds.

          debug – Ruby debugger (breakpoints, stepping).

          brakeman – Static security analysis for Rails apps.

          rubocop / rubocop-rails / rubocop-rspec / rubocop-rails-omakase – Linting & style guides.

          annotate – Adds schema/associations as comments atop models.
