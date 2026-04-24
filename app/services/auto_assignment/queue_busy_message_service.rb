class AutoAssignment::QueueBusyMessageService
  pattr_initialize [:conversation!]

  QUEUE_BUSY_NOTICE_KEY = 'queue_busy_notice'

  def perform
    return unless conversation.inbox.web_widget?
    return unless conversation.status == 'open'
    return if conversation.assignee_id.present?
    return if already_sent?

    content = I18n.with_locale(account_locale) do
      I18n.t('conversations.queue_busy.widget_message')
    end

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :template,
      content: content,
      additional_attributes: { QUEUE_BUSY_NOTICE_KEY => true }
    )
  end

  private

  def already_sent?
    conversation.messages.where(
      'messages.additional_attributes @> ?',
      { QUEUE_BUSY_NOTICE_KEY => true }.to_json
    ).exists?
  end

  def account_locale
    conversation.account.locale.presence || I18n.default_locale
  end
end
