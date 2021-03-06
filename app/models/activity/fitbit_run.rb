class Activity::FitbitRun < ActiveRecord::Base
  belongs_to :user
  has_one :user_activity, as: :activity

  validates :user, presence: true
  validates :user_activity, presence: true
end
