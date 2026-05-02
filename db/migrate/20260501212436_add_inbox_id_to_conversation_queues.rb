class AddInboxIdToConversationQueues < ActiveRecord::Migration[7.1]
  def up
    add_column :conversation_queues, :inbox_id, :bigint, null: true
    add_index :conversation_queues, :inbox_id
  end

  def down
    remove_index :conversation_queues, :inbox_id
    remove_column :conversation_queues, :inbox_id
  end
end
