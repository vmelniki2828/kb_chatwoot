# frozen_string_literal: true

module ReportingEvents
  # Splits human `conversation_resolved` rows by whether the conversation ever had bot activity.
  module ResolutionSegmentFilter
    BOT_TOUCH_NAMES = %w[conversation_bot_handoff conversation_bot_resolved].freeze

    EXISTS_SQL = <<~SQL.squish
      EXISTS (
        SELECT 1 FROM reporting_events re_b
        WHERE re_b.conversation_id = reporting_events.conversation_id
          AND re_b.account_id = reporting_events.account_id
          AND re_b.name IN (?)
      )
    SQL

    module_function

    def with_bot(relation)
      relation.where(EXISTS_SQL, BOT_TOUCH_NAMES)
    end

    def operators_only(relation)
      relation.where("NOT (#{EXISTS_SQL})", BOT_TOUCH_NAMES)
    end
  end
end
