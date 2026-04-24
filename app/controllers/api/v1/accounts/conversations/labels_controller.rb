class Api::V1::Accounts::Conversations::LabelsController < Api::V1::Accounts::Conversations::BaseController
  include LabelConcern

  def create
    ensure_account_labels_exist!(permitted_params[:labels])
    super
  end

  private

  def model
    @model ||= @conversation
  end

  def permitted_params
    params.permit(:conversation_id, labels: [])
  end

  def ensure_account_labels_exist!(titles)
    Array(titles).compact_blank.each do |raw|
      Labels::FindOrCreateService.new(account: Current.account, title: raw.to_s.strip).perform
    end
  end
end
