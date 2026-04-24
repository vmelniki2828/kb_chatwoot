class Enterprise::AutoAssignment::CapacityService
  def agent_has_capacity?(user, inbox)
    account_user = user.account_users.find_by(account: inbox.account)
    return true unless account_user

    # Per-operator limit across all inboxes in the account (not per source/inbox)
    if account_user.max_open_conversations.present? && account_user.max_open_conversations.positive?
      current_count = user.assigned_conversations
                        .where(account_id: inbox.account_id, status: :open)
                        .count
      return current_count < account_user.max_open_conversations
    end

    # Legacy: capacity policy with per-inbox limits
    return true unless account_user.agent_capacity_policy

    policy = account_user.agent_capacity_policy

    inbox_limit = policy.inbox_capacity_limits.find_by(inbox: inbox)
    return true unless inbox_limit

    current_count = user.assigned_conversations
                      .where(inbox: inbox, status: :open)
                      .count

    current_count < inbox_limit.conversation_limit
  end
end
