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

require "rails_helper"

RSpec.describe User, type: :model do
  it { is_expected.to have_many(:posts) }
  it { is_expected.to have_many(:ratings) }
  it { is_expected.to validate_presence_of(:login) }

  describe "uniqueness" do
    subject { build(:user, login: "unique_login") }
    before  { create(:user, login: "unique_login") }

    it { is_expected.to validate_uniqueness_of(:login).case_insensitive.with_message(/already in use/i) }
  end

  it "enforces unique login at DB level" do
    create(:user, login: "harduniq")
    expect {
      User.insert_all!([ { login: "harduniq", created_at: Time.current, updated_at: Time.current } ])
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
