class Api::V1::Widget::DirectUploadsController < ActiveStorage::DirectUploadsController
  include WebsiteTokenHelper
  include WidgetBlockedContactGuard
  before_action :set_web_widget
  before_action :set_contact
  before_action :ensure_contact_not_blocked!, only: [:create]

  def create
    return if @contact.nil? || @current_account.nil?

    super
  end
end
