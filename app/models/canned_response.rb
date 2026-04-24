# == Schema Information
#
# Table name: canned_responses
#
#  id         :integer          not null, primary key
#  content    :text
#  label_ids  :jsonb            not null
#  short_code :string
#  topic      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :integer          not null
#

class CannedResponse < ApplicationRecord
  validates :content, presence: true
  validates :short_code, presence: true
  validates :account, presence: true
  validates :short_code, uniqueness: { scope: :account_id }

  belongs_to :account

  before_validation :normalize_label_ids
  validate :label_ids_belong_to_account

  def normalize_label_ids
    raw = label_ids
    # Rails/JSON иногда отдаёт «массив» как Hash с ключами "0","1" — иначе Array(hash) ломает to_i.
    raw = raw.values if raw.is_a?(Hash) && raw.keys.map(&:to_s).all? { |k| k.match?(/^\d+$/) }
    self.label_ids = Array(raw).flatten.map(&:to_i).uniq.reject(&:zero?)
  end

  def label_ids_belong_to_account
    return if label_ids.blank?

    return if account.labels.where(id: label_ids).count == label_ids.size

    errors.add(:label_ids, :invalid)
  end

  def label_titles
    return [] if label_ids.blank?

    by_id = account.labels.where(id: label_ids).index_by(&:id)
    label_ids.filter_map { |id| by_id[id]&.title }
  end

  def as_json(options = {})
    super(options).merge('label_titles' => label_titles)
  end

  scope :order_by_search, lambda { |search|
    short_code_starts_with = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 1', "#{search}%"])
    short_code_like = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 0.5', "%#{search}%"])
    content_like = sanitize_sql_array(['WHEN content ILIKE ? THEN 0.2', "%#{search}%"])

    order_clause = "CASE #{short_code_starts_with} #{short_code_like} #{content_like} ELSE 0 END"

    order(Arel.sql(order_clause) => :desc)
  }
end
