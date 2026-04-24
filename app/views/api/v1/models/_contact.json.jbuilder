if resource.blank?
  json.id nil
  json.additional_attributes({})
  json.availability_status nil
  json.email nil
  json.name nil
  json.phone_number nil
  json.blocked false
  json.blocked_until nil
  json.messaging_block_active false
  json.identifier nil
  json.thumbnail nil
  json.custom_attributes({})
else
  json.additional_attributes resource.additional_attributes
  json.availability_status resource.availability_status
  json.email resource.email
  json.id resource.id
  json.name resource.name
  json.phone_number resource.phone_number
  json.blocked resource.blocked
  json.blocked_until resource.blocked_until&.utc&.iso8601
  json.messaging_block_active resource.messaging_block_active?
  json.identifier resource.identifier
  json.thumbnail resource.avatar_url
  json.custom_attributes resource.custom_attributes
  json.last_activity_at resource.last_activity_at.to_i if resource[:last_activity_at].present?
  json.created_at resource.created_at.to_i if resource[:created_at].present?
  # we only want to output contact inbox when its /contacts endpoints
  if defined?(with_contact_inboxes) && with_contact_inboxes.present?
    json.contact_inboxes do
      json.array! resource.contact_inboxes do |contact_inbox|
        json.partial! 'api/v1/models/contact_inbox', formats: [:json], resource: contact_inbox
      end
    end
  end
end
