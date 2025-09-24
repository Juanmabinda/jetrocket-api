class PostsController < ApplicationController
  def create
    login = params.require(:user_login).to_s.strip.downcase
    user  = User.find_by(login: login) || User.create!(login: login)

    post = user.posts.build(
      title: params.require(:title),
      body:  params.require(:body),
      ip:    params.require(:ip)
    )

    if post.save
      return head :created if params[:silent].present?
      render json: post.as_json(
        only:    %i[id title body ip created_at updated_at],
        include: { user: { only: %i[id login] } }
      ), status: :created
    else
      render json: { errors: post.errors.full_messages }, status: :unprocessable_content
    end
  rescue ActionController::ParameterMissing => e
    render json: { errors: [ e.message ] }, status: :bad_request
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages.presence || [ e.message ] }, status: :unprocessable_content
  rescue ActiveRecord::StatementInvalid => e
    # inet invalid → give 422 instead of 500 error
    if e.message =~ /invalid input syntax for type inet/i
      render json: { errors: [ "ip is invalid" ] }, status: :unprocessable_content
    else
      raise
    end
  end

  def top
    limit_param = params.fetch(:limit, 10).to_i.clamp(1, 100)

    posts_table   = Post.arel_table
    ratings_table = Rating.arel_table

    average_rating_expr = ratings_table[:value].average
    ratings_count_expr  = ratings_table[:id].count

    # Order by the computed average (unrated posts at the end), then rating Qtty and lasty ID
    top_posts = Post.left_outer_joins(:ratings)
                    .select(
                      posts_table[:id],
                      posts_table[:title],
                      posts_table[:body],
                      average_rating_expr.as("avg_rating"),
                      ratings_count_expr.as("ratings_count")
                    )
                    .group(posts_table[:id])
                    .order(
                      Arel.sql("avg_rating DESC NULLS LAST, ratings_count DESC, posts.id ASC")
                    )
                    .limit(limit_param)

    render json: top_posts.as_json(only: %i[id title body])
  end



  def shared_ips
    posts   = Post.arel_table
    users   = User.arel_table

    # Ip withouts mask
    host_ip = Arel::Nodes::NamedFunction.new("HOST", [ posts[:ip] ])

    # unique and ordered logins
    distinct_logins_ordered = Arel.sql("DISTINCT #{users[:login].name} ORDER BY #{users[:login].name}")
    logins_array            = Arel::Nodes::NamedFunction.new("ARRAY_AGG", [ distinct_logins_ordered ])

    rows = Post.joins(:user)
               .group(posts[:ip])
               .having(Arel.sql("COUNT(DISTINCT #{posts[:user_id].name}) > 1"))
               .order(host_ip.asc)
               .pluck(host_ip, logins_array)

    render json: rows.map { |ip_text, logins| { ip: ip_text, logins: logins } }
  end

  def bulk_create
    items = params.require(:posts)
    unless items.is_a?(Array) && items.any?
      return render json: { errors: [ "posts must be a non-empty array" ] }, status: :bad_request
    end

    # Normalize keys to symbols
    items = items.map { |h| h.respond_to?(:to_unsafe_h) ? h.to_unsafe_h.symbolize_keys : h.symbolize_keys }

    ActiveRecord::Base.transaction do
      # Speed up WAL/fsync for this transaction only (safe for seeding)
      ActiveRecord::Base.connection.execute("SET LOCAL synchronous_commit = off")

      # 1) Ensure all authors exist (bulk upsert by login)
      requested_logins     = items.map { |it| it[:user_login].to_s.strip.downcase }.uniq
      existing_by_login    = User.where(login: requested_logins).pluck(:login, :id).to_h
      missing_logins       = requested_logins - existing_by_login.keys

      if missing_logins.any?
        now = Time.current
        User.insert_all(
          missing_logins.map { |login| { login: login, created_at: now, updated_at: now } },
          unique_by: :index_users_on_login
        )
        # Load ids for newly inserted logins
        existing_by_login.merge!(User.where(login: missing_logins).pluck(:login, :id).to_h)
      end

      # 2) Build rows for a single bulk insert into posts
      now  = Time.current
      rows = items.map do |it|
        {
          user_id:    existing_by_login[it[:user_login].to_s.strip.downcase],
          title:      it[:title],
          body:       it[:body],
          ip:         it[:ip],
          created_at: now,
          updated_at: now
        }
      end

      # 3) Single INSERT...RETURNING id round-trip
      result   = Post.insert_all(rows, returning: %w[id])
      post_ids = result.rows.flatten

      render json: { post_ids: post_ids }, status: :created
    end
  end
end
