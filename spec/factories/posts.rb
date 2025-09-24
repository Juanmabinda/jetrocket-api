# == Schema Information
#
# Table name: posts
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  title      :string           not null
#  body       :text             not null
#  ip         :inet             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_posts_on_user_id  (user_id)
#

FactoryBot.define do
  factory :post do
    association :user
    sequence(:title) { |n| "Post ##{n}" }
    body { "body text" }
    sequence(:ip) { |n| "10.0.0.#{(n % 250) + 1}" }
  end
end
