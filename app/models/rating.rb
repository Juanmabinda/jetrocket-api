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

class Rating < ApplicationRecord
  belongs_to :post
  belongs_to :user

  validates :value,
    presence: { message: "is mandatory" },
    inclusion: { in: 1..5, message: "must be between 1 and 5" }
  validates :user_id, uniqueness: { scope: :post_id, message: "you've already rated this post" }
end
