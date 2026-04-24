# frozen_string_literal: true

require 'securerandom'

module Labels
  # Ensures an account +Label+ exists for the given display +title+ (case-insensitive match on +title+).
  class FindOrCreateService
    def initialize(account:, title:)
      @account = account
      @title = title.to_s.strip
    end

    def perform
      return nil if @title.blank?

      normalized = @title.downcase
      existing = @account.labels.find_by(title: normalized)
      return existing if existing

      @account.labels.create!(
        title: @title,
        color: "##{SecureRandom.hex(3).upcase}"
      )
    rescue ActiveRecord::RecordInvalid
      nil
    end
  end
end
