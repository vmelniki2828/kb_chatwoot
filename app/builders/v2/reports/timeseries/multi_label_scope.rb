# frozen_string_literal: true

# Union of conversations tagged with any of the given labels (same semantics as overview multi-select).
class V2::Reports::Timeseries::MultiLabelScope
  attr_reader :account

  def initialize(account, label_ids)
    @account = account
    @titles = account.labels.where(id: label_ids).reorder(nil).pluck(:title)
  end

  def conversations
    return account.conversations.none if @titles.blank?

    account.conversations.tagged_with(@titles, any: true)
  end

  # tagged_with adds JOINs; IN (SELECT id) from that relation can expand to multiple columns in SQL.
  # Pluck conversation ids once, then filter messages/events (same semantics).
  def messages
    ids = conversation_ids_for_associations
    return account.messages.none if ids.blank?

    account.messages.where(conversation_id: ids)
  end

  def reporting_events
    ids = conversation_ids_for_associations
    return account.reporting_events.none if ids.blank?

    account.reporting_events.where(conversation_id: ids)
  end

  private

  def conversation_ids_for_associations
    @conversation_ids_for_associations ||= conversations.pluck(:id)
  end
end
