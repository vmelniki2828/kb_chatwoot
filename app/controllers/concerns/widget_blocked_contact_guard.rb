module WidgetBlockedContactGuard
  extend ActiveSupport::Concern

  private

  def ensure_contact_not_blocked!
    return if @contact.blank?

    @contact.clear_expired_messaging_block!
    return unless @contact.messaging_block_active?

    render json: {
      error: I18n.t('errors.widget.contact_blocked', default: 'You have been blocked from contacting support.')
    }, status: :forbidden
  end
end
