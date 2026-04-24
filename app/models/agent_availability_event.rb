# == Schema Information
#
# Table name: agent_availability_events
#
#  id                    :bigint           not null, primary key
#  availability          :integer          not null
#  previous_availability :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  user_id               :bigint           not null
#
# Indexes
#
#  idx_agent_availability_events_account_user_created            (account_id,user_id,created_at)
#  index_agent_availability_events_on_account_id                 (account_id)
#  index_agent_availability_events_on_account_id_and_created_at  (account_id,created_at)
#  index_agent_availability_events_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class AgentAvailabilityEvent < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :availability, presence: true

  scope :for_period, lambda { |range_start, range_end|
    where(created_at: range_start..range_end)
  }

  def self.availability_label(value)
    return if value.nil?

    AccountUser.availabilities.key(value)
  end
end
