class ChatQueue::Queue::FetchService
  pattr_initialize [:account!]

  def fetch_queue_entry
    entry = ConversationQueue.for_account(account.id)
                             .waiting
                             .order(:position, :queued_at)
                             .first

    unless entry
      Rails.logger.info("[QUEUE][fetch] No entries for account #{account.id}")
      return nil
    end

    entry
  end

  def fetch_specific_entry(conv_id)
    entry = ConversationQueue.find_by(conversation_id: conv_id, status: :waiting)

    unless entry
      Rails.logger.info("[QUEUE][fetch_specific][conv=#{conv_id}] No waiting entry found")
      return nil
    end

    entry
  end

  def next_in_queue
    Rails.logger.info("[QUEUE][next] Fetching next conversation for account #{account.id}")

    ConversationQueue.for_account(account.id)
                     .waiting
                     .order(:position, :queued_at)
                     .first
                     &.conversation
  end

  def queue_size
    size = ConversationQueue.for_account(account.id)
                            .waiting
                            .count

    Rails.logger.info("[QUEUE][size] Queue size=#{size} for account #{account.id}")

    size
  end
end
