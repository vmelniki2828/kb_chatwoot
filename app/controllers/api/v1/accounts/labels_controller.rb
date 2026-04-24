class Api::V1::Accounts::LabelsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :fetch_label, except: [:index, :create, :import]
  before_action :check_authorization

  def import
    result = ::Labels::TableImportService.new(
      account: Current.account,
      uploaded_file: params[:file]
    ).perform

    render json: result
  rescue ArgumentError => e
    render json: { imported: 0, errors: [], error: e.message }, status: :unprocessable_entity
  end

  def index
    @labels = policy_scope(Current.account.labels)
  end

  def show; end

  def create
    @label = Current.account.labels.create!(permitted_params)
  end

  def update
    @label.update!(permitted_params)
  end

  def destroy
    @label.destroy!
    head :ok
  end

  private

  def fetch_label
    @label = Current.account.labels.find(params[:id])
  end

  def permitted_params
    params.require(:label).permit(:title, :description, :color, :show_on_sidebar)
  end
end
