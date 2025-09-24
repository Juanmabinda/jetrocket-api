# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ratings routes", type: :routing do
  it { expect(post: "/ratings").to route_to("ratings#create") }
  it { expect(post: "/ratings/bulk_create").to route_to("ratings#bulk_create") }
end
