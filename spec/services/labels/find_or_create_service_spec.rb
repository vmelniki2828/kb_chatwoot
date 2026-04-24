# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Labels::FindOrCreateService do
  let(:account) { create(:account) }

  it 'returns existing label case-insensitively' do
    existing = create(:label, account: account, title: 'support')

    result = described_class.new(account: account, title: 'Support').perform

    expect(result).to eq(existing)
  end

  it 'creates a new label when missing' do
    expect do
      described_class.new(account: account, title: 'new_label_tag').perform
    end.to change { account.reload.labels.count }.by(1)

    expect(account.labels.find_by(title: 'new_label_tag')).to be_present
  end

  it 'returns nil for blank title' do
    expect(described_class.new(account: account, title: '   ').perform).to be_nil
  end
end
