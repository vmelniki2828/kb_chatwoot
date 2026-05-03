# == Schema Information
#
# Table name: account_users
#
#  id                       :bigint           not null, primary key
#  active_at                :datetime
#  auto_offline             :boolean          default(TRUE), not null
#  availability             :integer          default("online"), not null
#  max_open_conversations   :integer
#  role                     :integer          default("agent")
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint
#  agent_capacity_policy_id :bigint
#  custom_role_id           :bigint
#  inviter_id               :bigint
#  user_id                  :bigint
#
# Indexes
#
#  index_account_users_on_account_id                (account_id)
#  index_account_users_on_agent_capacity_policy_id  (agent_capacity_policy_id)
#  index_account_users_on_custom_role_id            (custom_role_id)
#  index_account_users_on_user_id                   (user_id)
#  uniq_user_id_per_account_id                      (account_id,user_id) UNIQUE
#

class AccountUser < ApplicationRecord
  include AvailabilityStatusable

  belongs_to :account
  belongs_to :user
  belongs_to :inviter, class_name: 'User', optional: true

  enum role: { agent: 0, administrator: 1 }
  enum availability: { online: 0, offline: 1, busy: 2 }

  accepts_nested_attributes_for :account

  after_create_commit :notify_creation, :create_notification_setting
  after_destroy :notify_deletion, :remove_user_from_account
  before_update :remember_availability_transition
  after_save :update_presence_in_redis, if: :saved_change_to_availability?
  after_commit :persist_availability_event, on: :update
  after_commit :process_queue_when_agent_available, if: :saved_change_to_availability?

  validates :user_id, uniqueness: { scope: :account_id }
  validates :max_open_conversations,
            numericality: { only_integer: true, greater_than: 0, allow_nil: true }

  def create_notification_setting
    setting = user.notification_settings.new(account_id: account.id)
    setting.selected_email_flags = [:email_conversation_assignment]
    setting.selected_push_flags = [:push_conversation_assignment]
    setting.save!
  end

  def remove_user_from_account
    ::Agents::DestroyJob.perform_later(account, user)
  end

  def permissions
    administrator? ? ['administrator'] : ['agent']
  end

  def push_event_data
    {
      id: id,
      availability: availability,
      role: role,
      user_id: user_id
    }
  end

  def active_chat_limit_enabled?
    max_open_conversations.present?
  end

  private

  def notify_creation
    Rails.configuration.dispatcher.dispatch(AGENT_ADDED, Time.zone.now, account: account)
  end

  def notify_deletion
    Rails.configuration.dispatcher.dispatch(AGENT_REMOVED, Time.zone.now, account: account)
  end

  def update_presence_in_redis
    OnlineStatusTracker.set_status(account.id, user.id, availability)
  end

  def remember_availability_transition
    pair = changes_to_save['availability']
    return if pair.blank?

    previous_val, current_val = pair.map { |v| coerce_availability_to_i(v) }
    return if previous_val.nil? || current_val.nil?
    return if previous_val == current_val

    @pending_availability_transition = [previous_val, current_val]
  end

  def persist_availability_event
    transition = @pending_availability_transition
    @pending_availability_transition = nil
    return if transition.blank?

    previous_val, current_val = transition
    return if previous_val == current_val

    AgentAvailabilityEvent.create!(
      account_id: account_id,
      user_id: user_id,
      previous_availability: previous_val,
      availability: current_val
    )
  end

  def coerce_availability_to_i(value)
    case value
    when Integer
      value
    when String, Symbol
      self.class.availabilities[value.to_s]
    else
      value&.to_i
    end
  end

  def process_queue_when_agent_available
    # When agent becomes online, process queue
    return unless account.queue_enabled?
    return unless online?

    account.inboxes.pluck(:id).each do |inbox_id|
      ChatQueue::ProcessQueueJob.perform_later(account.id)
    end
  end
end

AccountUser.prepend_mod_with('AccountUser')
AccountUser.include_mod_with('Audit::AccountUser')
AccountUser.include_mod_with('Concerns::AccountUser')
