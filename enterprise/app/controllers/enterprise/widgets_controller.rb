module Enterprise::WidgetsController
  private

  def ensure_location_is_supported
    countries = @web_widget.inbox.account.custom_attributes['allowed_countries']
    return if countries.blank?

    geocoder_result = geocoder_result_for_widget_location
    return unless geocoder_result

    country_enabled = countries.include?(geocoder_result.country_code)
    render json: { error: 'Location is not supported' }, status: :unauthorized unless country_enabled
  end

  def geocoder_result_for_widget_location
    IpLookupService.new.perform(request.remote_ip)
  rescue StandardError => e
    Rails.logger.error("[Widget] IP lookup failed: #{e.class}: #{e.message}")
    nil
  end
end
