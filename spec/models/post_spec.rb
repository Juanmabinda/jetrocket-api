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

require 'rails_helper'

require "rails_helper"

RSpec.describe Post, type: :model do
  it { is_expected.to belong_to(:user).required }
  it { is_expected.to have_many(:ratings) }
  it { is_expected.to have_many(:ratings).dependent(:destroy) }

  it "stores IPv4 strings into inet column" do
    p = create(:post, ip: "10.1.2.3")
    # postgres inet casts '10.1.2.3' to '10.1.2.3/32' internally; equality works
    expect(Post.where(id: p.id, ip: "10.1.2.3")).to exist
  end
end
