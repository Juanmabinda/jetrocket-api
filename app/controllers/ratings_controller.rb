class RatingsController < ApplicationController
  def create
    post = Post.find(params.require(:post_id))
    user = if params[:user_login]
             login = params[:user_login].to_s.strip.downcase
             User.find_by(login: login) || User.create!(login: login)
    else
             User.find(params.require(:user_id))
    end

    value = params.require(:value)
    rating = Rating.create!(post: post, user: user, value: value)

    avg = Rating.where(post_id: post.id).average(:value)&.to_f
    render json: {
      post_id: post.id,
      user: { id: user.id, login: user.login },
      value: rating.value,
      average_rating: avg
    }, status: :created

  rescue ActiveRecord::RecordNotUnique
    avg = Rating.where(post_id: params[:post_id]).average(:value)&.to_f
    render json: { errors: [ "you've already rated this post" ], average_rating: avg },
           status: :unprocessable_content
  rescue ActiveRecord::RecordInvalid => e
    # If uniqueness, sent average_rating
    if e.record.errors.details[:user_id].any? { |h| h[:error] == :taken }
      avg = Rating.where(post_id: params[:post_id]).average(:value)&.to_f
      render json: { errors: e.record.errors.full_messages, average_rating: avg },
             status: :unprocessable_content
    else
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [ "post or user not found" ] }, status: :not_found
  end

  def bulk_create
    items = params.require(:ratings)
    raise ActionController::ParameterMissing, "ratings must be an array" unless items.is_a?(Array)

    logins = items.map { _1[:user_login].to_s.strip.downcase }.uniq
    existing = User.where(login: logins).pluck(:login, :id).to_h

    new_logins = logins - existing.keys
    if new_logins.any?
      now = Time.current
      User.insert_all(
        new_logins.map { |l| { login: l, created_at: now, updated_at: now } },
        unique_by: :index_users_on_login
      )
      existing.merge!(User.where(login: new_logins).pluck(:login, :id).to_h)
    end

    now  = Time.current
    rows = items.map do |it|
      {
        post_id:    it[:post_id],
        user_id:    existing[it[:user_login].to_s.downcase],
        value:      it[:value],
        created_at: now,
        updated_at: now
      }
    end

    created = 0
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SET LOCAL synchronous_commit = off")
      result = Rating.insert_all(
        rows,
        unique_by: :index_ratings_on_post_id_and_user_id,
        returning: %w[id]
      )
      created = result.rows.size
    end

    render json: { created: created }, status: :created
  rescue ActionController::ParameterMissing => e
    render json: { errors: [ e.message ] }, status: :bad_request
  end
end
