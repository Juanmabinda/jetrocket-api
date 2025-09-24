# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Posts API", type: :request do
  describe "POST /posts" do
    it "creates a post and the user on-demand" do
      payload = { title: "A", body: "a", user_login: "new_user", ip: "10.0.0.1" }
      post "/posts", params: payload, as: :json
      expect(response).to have_http_status(:created)
      expect(json["id"]).to be_present
      expect(json.dig("user", "login")).to eq("new_user")
      expect(User.find_by(login: "new_user")).to be_present
      expect(Post.find(json["id"]).ip).to be_present
    end

    it "returns 422 on invalid IP (inet casting error)" do
      payload = { title: "t", body: "b", user_login: "x", ip: "not_an_ip" }
      post "/posts", params: payload, as: :json
      expect(response.status).to eq(422)
      expect(json["errors"].join(" ")).to match(/ip .*mandatory/i)
    end


    it "returns 400 when required params are missing" do
      post "/posts", params: { title: "X" }, as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "GET /posts/top" do
    it "returns top posts ordered by avg desc, count desc, id asc and limited" do
      p1 = create(:post, title: "P1")
      p2 = create(:post, title: "P2")
      p3 = create(:post, title: "P3")

      u1 = create(:user); u2 = create(:user)
      create(:rating, post: p1, user: u1, value: 5)
      create(:rating, post: p1, user: u2, value: 5)
      create(:rating, post: p2, user: u1, value: 4)
      # p3 remains unrated

      get "/posts/top", params: { limit: 2 }
      expect(response).to have_http_status(:ok)
      ids = json.map { _1["id"] }
      expect(ids).to eq([ p1.id, p2.id ])
      # response only has id/title/body (no avg/count in JSON)
      expect(json.first.keys).to contain_exactly("id", "title", "body")
    end
  end

  describe "GET /posts/shared_ips" do
    it "lists IPs with more than one distinct author and their logins (sorted)" do
      ip = "10.0.0.1"
      u1 = create(:user, login: "alice")
      u2 = create(:user, login: "bob")
      create(:post, user: u1, ip: ip)
      create(:post, user: u2, ip: ip)
      create(:post, ip: "10.0.0.2") # single-author ip ignored

      get "/posts/shared_ips"
      expect(response).to have_http_status(:ok)
      entry = json.find { _1["ip"] == ip }
      expect(entry).to be_present
      expect(entry["logins"]).to eq(%w[alice bob])
    end
  end

  describe "POST /posts/bulk_create" do
    it "creates posts in bulk and users as needed" do
      existing = create(:user, login: "existing")
      payload = {
        posts: [
          { title: "A", body: "a", user_login: "newbie",   ip: "10.0.0.10" },
          { title: "B", body: "b", user_login: "existing", ip: "10.0.0.11" }
        ]
      }
      post "/posts/bulk_create", params: payload, as: :json
      expect(response).to have_http_status(:created)
      expect(json["post_ids"]).to match array_including(kind_of(Integer), kind_of(Integer))
      expect(User.find_by(login: "newbie")).to be_present
      expect(Post.where(ip: "10.0.0.10")).to exist
      expect(Post.where(ip: "10.0.0.11", user_id: existing.id)).to exist
    end

    it "returns 400 if posts param is missing" do
      post "/posts/bulk_create", params: {}, as: :json
      expect(response).to have_http_status(:bad_request).or have_http_status(:unprocessable_content)
    end
  end
end
