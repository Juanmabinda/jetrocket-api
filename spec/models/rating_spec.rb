# == Schema Information
#
# Table name: ratings
#
#  id         :integer          not null, primary key
#  post_id    :integer          not null
#  user_id    :integer          not null
#  value      :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_ratings_on_post_id              (post_id)
#  index_ratings_on_post_id_and_user_id  (post_id,user_id) UNIQUE
#  index_ratings_on_user_id              (user_id)
#

require "rails_helper"

RSpec.describe Rating, type: :model do
  it { is_expected.to belong_to(:post).required }
  it { is_expected.to belong_to(:user).required }

  it "valida unicidad (post_id, user_id) a nivel modelo" do
    r = create(:rating) # usa factories o crea registros “a mano”
    dup = Rating.new(post: r.post, user: r.user, value: 3)
    expect(dup).to be_invalid
    expect(dup.errors.full_messages.join).to match(/already rated/i)
  end

  it "tiene índice único (post_id, user_id) a nivel DB" do
    idx = ActiveRecord::Base.connection.indexes(:ratings)
           .find { |i| i.name == "index_ratings_on_post_id_and_user_id" }
    expect(idx).to be_present
    expect(idx.unique).to be true
    expect(idx.columns).to eq(%w[post_id user_id])
  end
end
