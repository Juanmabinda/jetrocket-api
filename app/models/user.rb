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

class User < ApplicationRecord
  has_many :posts,   dependent: :destroy
  has_many :ratings, dependent: :destroy

  # Normalizate before the validation
  before_validation { self.login = login&.strip&.downcase }

  validates :login,
    presence:   { message: "can't be blank" },
    uniqueness: { case_sensitive: false, message: "is already in use" }
end
