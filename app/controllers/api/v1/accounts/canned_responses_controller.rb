class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_canned_response, only: [:update, :destroy]

  def index
    render json: canned_responses
  end

  def create
    @canned_response = Current.account.canned_responses.new(canned_response_params)
    @canned_response.save!
    render json: @canned_response
  end

  def update
    @canned_response.update!(canned_response_params)
    render json: @canned_response
  end

  def destroy
    @canned_response.destroy!
    head :ok
  end

  def import
    result = ::CannedResponses::TableImportService.new(
      account: Current.account,
      uploaded_file: params[:file]
    ).perform
    render json: result
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_canned_response
    @canned_response = Current.account.canned_responses.find(params[:id])
  end

  def canned_response_params
    p = params.require(:canned_response).permit(:short_code, :content, label_ids: [], label_titles: [])
    merge_label_titles_into_label_ids!(p)
    p.delete(:label_titles) if p.key?(:label_titles)
    p
  end

  def merge_label_titles_into_label_ids!(permitted)
    titles = Array(permitted[:label_titles]).compact_blank.map { |t| t.to_s.strip }
    return if titles.blank?

    ids = Array(permitted[:label_ids]).map(&:to_i).reject(&:zero?)
    titles.each do |title|
      label = Labels::FindOrCreateService.new(account: Current.account, title: title).perform
      ids << label.id if label
    end
    permitted[:label_ids] = ids.uniq
  end

  def canned_responses
    if params[:search]
      Current.account.canned_responses
             .where('short_code ILIKE :search OR content ILIKE :search', search: "%#{params[:search]}%")
             .order_by_search(params[:search])
    else
      Current.account.canned_responses
    end
  end
end
