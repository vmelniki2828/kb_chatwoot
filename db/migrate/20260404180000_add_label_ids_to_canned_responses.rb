class AddLabelIdsToCannedResponses < ActiveRecord::Migration[7.1]
  def up
    return if column_exists?(:canned_responses, :label_ids)

    add_column :canned_responses, :label_ids, :jsonb, default: [], null: false
  end

  def down
    return unless column_exists?(:canned_responses, :label_ids)

    remove_column :canned_responses, :label_ids
  end
end
