require "json"
require "net/http"
require "uri"
require "securerandom"

# Setup
FAST            = ENV.fetch("SEED_FAST", "1") != "0"
API_BASE        = ENV.fetch("API_BASE", "http://localhost:3000")
TOTAL_POSTS     = Integer(ENV.fetch("TOTAL_POSTS", "200000"))
USERS_COUNT     = Integer(ENV.fetch("USERS_COUNT", "100"))
UNIQUE_IPS      = Integer(ENV.fetch("UNIQUE_IPS", "50"))
RATED_PERCENT   = Float(ENV.fetch("RATED_PERCENT", "0.75"))
BATCH           = Integer(ENV.fetch("BATCH", "1000"))
PROGRESS_EVERY  = Integer(ENV.fetch("PROGRESS_EVERY", "10000"))


# Just for compatibility (ignored with bulk_create)
ENV.fetch("RATING_THREADS", "0")

unless FAST
  require "faker"
  Faker::Config.locale = "en"
end

# Helpers
def http_client
  # One client per thread
  Thread.current[:__http__] ||= begin
    uri = URI(API_BASE)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = (uri.scheme == "https")
    http.read_timeout = 120
    http.open_timeout = 120
    http
  end
end

def post_json(path, payload)
  uri = URI.join(API_BASE, path)
  req = Net::HTTP::Post.new(uri)
  req["Content-Type"] = "application/json"
  req["Accept"]       = "application/json"
  req.body = JSON.generate(payload)

  res = http_client.request(req)

  body =
    if res.body.to_s.empty?
      {}
    else
      begin
        JSON.parse(res.body)
      rescue JSON::ParserError
        { "raw" => res.body }
      end
    end

  [ res.code.to_i, body ]
end

# 100 user logins
user_logins = (1..USERS_COUNT).map { |n| "user_#{n}" }

# 50 IPs (uniques and valids)
ip_pool = Array.new(UNIQUE_IPS) do |k|
  x = k % 256
  y = ((k * 7) % 254) + 1
  "10.0.#{x}.#{y}"
end

def make_title(i)
  if FAST
    "Post ##{i}"
  else
    Faker::Book.title
  end
end

def make_body
  if FAST
    "Seed body #{SecureRandom.hex(6)}"
  else
    Faker::Lorem.paragraph(sentence_count: 5)
  end
end

def pick_other_login(all_logins, exclude_login)
  # Login different from login (user)
  login = all_logins.sample
  return login if login != exclude_login

  # If the same, try another
  idx = all_logins.index(exclude_login) || 0
  all_logins[(idx + 1) % all_logins.size]
end


puts "Seeding via API -> #{API_BASE}"
puts "- users:  #{USERS_COUNT} (created on-demand during bulk)"
puts "- posts:  #{TOTAL_POSTS} (batch size: #{BATCH})"
puts "- ips:    #{UNIQUE_IPS} uniques"
puts "- rating: ~#{(RATED_PERCENT * 100).round}% of posts"
puts "- fast strings: #{FAST ? 'ON' : 'OFF'}"
puts "- ratings: bulk_create ON"
puts


t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
posts_created = 0
ratings_sent  = 0
fail_posts    = 0
fail_ratings  = 0

(0...TOTAL_POSTS).each_slice(BATCH) do |slice|
  # 1) Batch for /posts/bulk_create
  batch_items = slice.map do |i|
    {
      title:      make_title(i + 1),
      body:       make_body,
      user_login: user_logins[i % user_logins.size],
      ip:         ip_pool[i % ip_pool.size]
    }
  end

  code, data = post_json("/posts/bulk_create", { posts: batch_items })

  if code.between?(200, 299)
    post_ids = Array(data["post_ids"])
    # Mapping posts_ids with the authors (same index)
    pairs = post_ids.zip(batch_items.first(post_ids.size))

    posts_created += post_ids.size

    # Ratings (one per post aprox 75%)
    ratings_payload = []
    pairs.each do |post_id, item|
      next unless post_id # por seguridad
      next unless rand < RATED_PERCENT

      author_login = item[:user_login]
      rater_login  = pick_other_login(user_logins, author_login)
      value        = 1 + rand(5)

      ratings_payload << {
        post_id:    post_id,
        user_login: rater_login,
        value:      value
      }
    end

    # Send rating at once
    if ratings_payload.any?
      r_code, _ = post_json("/ratings/bulk_create", { ratings: ratings_payload, silent: true })
      if r_code.between?(200, 299)
        ratings_sent += ratings_payload.size
      else
        fail_ratings += ratings_payload.size
      end
    end
  else
    # If failed bulk, all batched failed
    fail_posts += batch_items.size
  end

  if posts_created % PROGRESS_EVERY == 0 || posts_created >= TOTAL_POSTS
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    puts "Progress: posts=#{posts_created}/#{TOTAL_POSTS}, ratings=#{ratings_sent}, " \
         "fails(posts=#{fail_posts}, ratings=#{fail_ratings}), elapsed=#{elapsed.round(1)}s"
  end
end

puts
puts "Ready"
puts "- Created posts:   #{posts_created}"
puts "- Sent ratings:    #{ratings_sent}"
puts "- Failed posts:    #{fail_posts}"
puts "- Failed ratings:  #{fail_ratings}"
