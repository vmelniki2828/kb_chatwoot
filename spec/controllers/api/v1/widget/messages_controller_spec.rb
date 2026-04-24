require 'rails_helper'

RSpec.describe '/api/v1/widget/messages', type: :request do
  let(:account) { create(:account) }
  let(:web_widget) { create(:channel_widget, account: account) }
  let(:contact) { create(:contact, account: account, email: nil) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: web_widget.inbox) }
  let(:payload) { { source_id: contact_inbox.source_id, inbox_id: web_widget.inbox.id } }
  let(:token) { Widget::TokenService.new(payload: payload).generate_token }

  describe 'POST /api/v1/widget/messages' do
    context 'when contact is blocked' do
      before { contact.update!(blocked: true) }

      it 'returns forbidden and does not create conversation or message' do
        msg_before = Message.count
        conv_before = Conversation.count

        post '/api/v1/widget/messages',
             headers: { 'X-Auth-Token' => token },
             params: {
               website_token: web_widget.website_token,
               message: {
                 content: 'hello',
                 timestamp: Time.current.iso8601,
                 referer_url: 'https://example.com'
               }
             },
             as: :json

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']).to eq(I18n.t('errors.widget.contact_blocked'))
        expect(Message.count).to eq(msg_before)
        expect(Conversation.count).to eq(conv_before)
      end
    end
  end
end
