# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Posts routes", type: :routing do
  it { expect(get: "/posts/top").to route_to("posts#top") }
  it { expect(get: "/posts/shared_ips").to route_to("posts#shared_ips") }
  it { expect(post: "/posts/bulk_create").to route_to("posts#bulk_create") }
end
