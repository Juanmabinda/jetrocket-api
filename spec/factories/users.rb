# == Schema Information
#
# Table name: users
#
#  id         :integer          not null, primary key
#  login      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_users_on_login  (login) UNIQUE
#

FactoryBot.define do
  factory :user do
    sequence(:login) { |n| "user_#{n}" }
  end
end
