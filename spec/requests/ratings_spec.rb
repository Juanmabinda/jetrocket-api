# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ratings API", type: :request do
  describe "POST /ratings" do
    it "creates a rating by user_login and returns the average" do
      post_rec = create(:post)
      payload = { post_id: post_rec.id, user_login: "rater_1", value: 4 }

      post "/ratings", params: payload, as: :json

      expect(response).to have_http_status(:created)
      expect(json["post_id"]).to eq(post_rec.id)
      expect(json.dig("user", "login")).to eq("rater_1")
      expect(json["average_rating"]).to eq(4.0)
    end

    it "rejects duplicate rating from same user (422) and returns current average" do
      post_rec = create(:post)
      user     = create(:user, login: "dup_user")
      create(:rating, post: post_rec, user: user, value: 5)

      post "/ratings", params: { post_id: post_rec.id, user_login: user.login, value: 3 }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"].join).to match(/already rated/i)
      expect(json["average_rating"]).to eq(5.0)
    end

    it "404 when post not found" do
      post "/ratings", params: { post_id: 999_999, user_login: "x", value: 2 }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /ratings/bulk_create" do
    it "inserts many ratings at once and reports created count" do
      users = create_list(:user, 3)
      posts = create_list(:post, 3)

      payload = {
        ratings: [
          { post_id: posts[0].id, user_login: users[0].login, value: 3 },
          { post_id: posts[1].id, user_login: users[1].login, value: 4 },
          { post_id: posts[2].id, user_login: users[2].login, value: 5 }
        ]
      }

      expect {
        post "/ratings/bulk_create", params: payload, as: :json
      }.to change(Rating, :count).by(3)

      expect(response).to have_http_status(:created)
      expect(json["created"]).to eq(3)
    end

    it "ignores duplicates (conflict) and counts only new rows" do
      user     = create(:user, login: "dup")
      post_rec = create(:post)
      create(:rating, post: post_rec, user: user, value: 4)

      payload = {
        ratings: [
          { post_id: post_rec.id, user_login: user.login, value: 5 },
          { post_id: post_rec.id, user_login: user.login, value: 2 }
        ]
      }

      expect {
        post "/ratings/bulk_create", params: payload, as: :json
      }.not_to change(Rating, :count)

      expect(response).to have_http_status(:created)
      expect(json["created"]).to eq(0)
    end

    it "handles duplicates inside the same batch" do
      user     = create(:user, login: "dupinbatch")
      post_rec = create(:post)

      payload = {
        ratings: [
          { post_id: post_rec.id, user_login: user.login, value: 3 },
          { post_id: post_rec.id, user_login: user.login, value: 5 }
        ]
      }

      expect {
        post "/ratings/bulk_create", params: payload, as: :json
      }.to change(Rating, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json["created"]).to eq(1)
    end

    it "returns 400 when ratings param is missing" do
      post "/ratings/bulk_create", params: {}, as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end
end
