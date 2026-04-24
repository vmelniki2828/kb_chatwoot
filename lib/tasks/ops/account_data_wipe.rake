# frozen_string_literal: true

# Удаление диалогов и/или инбоксов (источников) аккаунта.
#
# Все диалоги (чаты):
#   FORCE=true ACCOUNT_ID=4 bundle exec rake chatwoot:ops:wipe_account_conversations
#
# Все инбоксы каналов (источники в UI) — вместе с их диалогами, contact_inboxes, channel:
#   FORCE=true ACCOUNT_ID=4 bundle exec rake chatwoot:ops:wipe_account_inboxes
#
# Сброс «как новый аккаунт по переписке»: сначала диалоги, потом все инбоксы:
#   FORCE=true ACCOUNT_ID=4 bundle exec rake chatwoot:ops:wipe_account_conversations_and_inboxes
#
# Все контакты аккаунта (и связанные диалоги через callbacks):
#   FORCE=true ACCOUNT_ID=4 bundle exec rake chatwoot:ops:wipe_account_contacts
#
# Для destroy_async (сообщения и т.д.) должен работать Sidekiq или inline-адаптер.

namespace :chatwoot do
  namespace :ops do
    def require_force_and_account!
      raise 'Set FORCE=true to run destructive wipe.' unless ENV['FORCE'].to_s == 'true'

      account_id = ENV['ACCOUNT_ID'].presence
      raise 'Set ACCOUNT_ID=<id>' if account_id.blank?

      Account.find(account_id)
    end

    desc 'Destroy all conversations for an account (messages via dependent callbacks). Requires FORCE=true ACCOUNT_ID='
    task wipe_account_conversations: :environment do
      account = require_force_and_account!
      scope = account.conversations
      n = scope.count
      puts "Destroying #{n} conversations for account #{account.id}..."
      scope.find_each { |c| c.destroy }
      puts 'Done (conversations).'
    end

    desc 'Destroy all inboxes (sources/channels) for an account. Requires FORCE=true ACCOUNT_ID='
    task wipe_account_inboxes: :environment do
      account = require_force_and_account!
      scope = account.inboxes
      n = scope.count
      puts "Destroying #{n} inboxes (and their conversations/channels) for account #{account.id}..."
      failed = []
      scope.find_each do |inbox|
        next if inbox.destroy

        failed << [inbox.id, inbox.name, inbox.errors.full_messages.join('; ')]
      end
      if failed.any?
        warn "Some inboxes were NOT destroyed (#{failed.size}):"
        failed.each { |id, name, err| warn "  id=#{id} name=#{name.inspect} errors=#{err}" }
      end
      puts 'Done (inboxes).'
    end

    desc 'Wipe conversations then all inboxes. Requires FORCE=true ACCOUNT_ID='
    task wipe_account_conversations_and_inboxes: :environment do
      require_force_and_account!
      Rake::Task['chatwoot:ops:wipe_account_conversations'].invoke
      Rake::Task['chatwoot:ops:wipe_account_inboxes'].invoke
      puts 'Done (conversations + inboxes).'
    end

    desc 'Destroy all contacts for an account. Requires FORCE=true ACCOUNT_ID='
    task wipe_account_contacts: :environment do
      account = require_force_and_account!
      scope = account.contacts
      n = scope.count
      puts "Destroying #{n} contacts for account #{account.id}..."
      scope.find_each { |c| c.destroy }
      puts 'Done (contacts).'
    end
  end
end
