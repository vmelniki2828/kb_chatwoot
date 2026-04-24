require 'rails_helper'
require 'tempfile'

RSpec.describe 'Canned Responses API', type: :request do
  let(:account) { create(:account) }

  before do
    create(:canned_response, account: account, content: 'Hey {{ contact.name }}, Thanks for reaching out', short_code: 'name-short-code')
  end

  describe 'GET /api/v1/accounts/{account.id}/canned_responses' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/canned_responses"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'returns all the canned responses' do
        get "/api/v1/accounts/#{account.id}/canned_responses",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(account.canned_responses.as_json)
      end

      it 'returns all the canned responses the user searched for' do
        cr1 = account.canned_responses.first
        create(:canned_response, account: account, content: 'Great! Looking forward', short_code: 'short-code')
        cr2 = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'content-with-thanks')
        cr3 = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'Thanks')

        params = { search: 'thanks' }

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(
          [cr3, cr2, cr1].as_json
        )
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/canned_responses' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/canned_responses"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'creates a new canned response' do
        params = { short_code: 'short', content: 'content' }

        post "/api/v1/accounts/#{account.id}/canned_responses",
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(account.canned_responses.count).to eq(2)
      end

      it 'creates account labels from label_titles and stores label_ids' do
        params = {
          canned_response: {
            short_code: 'with_labels',
            content: 'Hello',
            label_titles: %w[fresh_canned_label]
          }
        }

        expect do
          post "/api/v1/accounts/#{account.id}/canned_responses",
               params: params,
               headers: agent.create_new_auth_token,
               as: :json
        end.to change { account.reload.labels.where(title: 'fresh_canned_label').count }.from(0).to(1)

        expect(response).to have_http_status(:success)
        row = account.canned_responses.find_by(short_code: 'with_labels')
        expect(row.label_ids).to eq([account.labels.find_by(title: 'fresh_canned_label').id])
      end
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/canned_responses/:id' do
    let(:canned_response) { CannedResponse.last }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'updates an existing canned response' do
        params = { short_code: 'B' }

        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(canned_response.reload.short_code).to eq('B')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/canned_responses/import' do
    let(:agent) { create(:user, account: account, role: :agent) }

    it 'imports TSV rows (header row + topic column)' do
      tsv = "Code\tContent\tTopic\nhello\tHi there\tSales\n"
      temp = Tempfile.new(['import', '.tsv'])
      temp.write(tsv)
      temp.rewind
      file = Rack::Test::UploadedFile.new(temp.path, 'text/tab-separated-values')

      expect do
        post "/api/v1/accounts/#{account.id}/canned_responses/import",
             params: { file: file },
             headers: agent.create_new_auth_token
      end.to change { account.reload.canned_responses.count }.by(1)

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['imported']).to eq(1)
      expect(body['errors']).to eq([])

      row = account.canned_responses.find_by(short_code: 'hello')
      expect(row.content).to eq('Hi there')
      expect(row.topic).to eq('Sales')
    ensure
      temp.close!
    end

    it 'imports TSV with three columns and no header (col3 = labels)' do
      tsv = "test1\ttesttest1\ttes1\ntest2\ttesttest2\ttes2\n"
      temp = Tempfile.new(['import', '.tsv'])
      temp.write(tsv)
      temp.rewind
      file = Rack::Test::UploadedFile.new(temp.path, 'text/tab-separated-values')

      expect do
        post "/api/v1/accounts/#{account.id}/canned_responses/import",
             params: { file: file },
             headers: agent.create_new_auth_token
      end.to change { account.reload.canned_responses.count }.by(2)
        .and change { account.labels.where(title: %w[tes1 tes2]).count }.by(2)

      expect(response).to have_http_status(:success)
      expect(account.canned_responses.find_by(short_code: 'test1').label_ids).to eq(
        [account.labels.find_by(title: 'tes1').id]
      )
    ensure
      temp.close!
    end

    it 'imports TSV with three columns when header marks column 3 as labels' do
      tsv = "Code\tContent\tLabels\nthreecol\tHello\tvip_only\n"
      temp = Tempfile.new(['import', '.tsv'])
      temp.write(tsv)
      temp.rewind
      file = Rack::Test::UploadedFile.new(temp.path, 'text/tab-separated-values')

      expect do
        post "/api/v1/accounts/#{account.id}/canned_responses/import",
             params: { file: file },
             headers: agent.create_new_auth_token
      end.to change { account.reload.canned_responses.count }.by(1)
        .and change { account.labels.where(title: 'vip_only').count }.from(0).to(1)

      expect(response).to have_http_status(:success)
      row = account.canned_responses.find_by(short_code: 'threecol')
      expect(row.label_ids).to eq([account.labels.find_by(title: 'vip_only').id])
    ensure
      temp.close!
    end

    it 'imports TSV with a fourth column of label titles (creates labels)' do
      tsv = "Code\tContent\tTopic\tLabels\nimp\tBody\t\tvip_support, follow_up\n"
      temp = Tempfile.new(['import', '.tsv'])
      temp.write(tsv)
      temp.rewind
      file = Rack::Test::UploadedFile.new(temp.path, 'text/tab-separated-values')

      expect do
        post "/api/v1/accounts/#{account.id}/canned_responses/import",
             params: { file: file },
             headers: agent.create_new_auth_token
      end.to change { account.reload.canned_responses.count }.by(1)
        .and change { account.labels.where(title: %w[vip_support follow_up]).count }.by(2)

      expect(response).to have_http_status(:success)
      row = account.canned_responses.find_by(short_code: 'imp')
      expect(row.label_ids.length).to eq(2)
    ensure
      temp.close!
    end

    it 'imports xlsx rows (first sheet, header + topic)' do
      allow(TableImports::XlsxFirstSheetReader).to receive(:call).and_return(
        [
          ['Шаблоны', 'Текст', 'Тематика'],
          ['xlsx_code', 'Hello x', 'Lead']
        ]
      )

      temp = Tempfile.new(['import', '.xlsx'])
      temp.write('PK')
      temp.rewind
      file = Rack::Test::UploadedFile.new(
        temp.path,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      )

      expect do
        post "/api/v1/accounts/#{account.id}/canned_responses/import",
             params: { file: file },
             headers: agent.create_new_auth_token
      end.to change { account.reload.canned_responses.count }.by(1)

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['imported']).to eq(1)
      expect(body['errors']).to eq([])

      row = account.canned_responses.find_by(short_code: 'xlsx_code')
      expect(row.content).to eq('Hello x')
      expect(row.topic).to eq('Lead')
    ensure
      temp.close!
    end

    it 'accepts text files with invalid UTF-8 bytes without raising' do
      bad = "short_code\tcontent\n\xC0\xC1x\tgood\n"
      temp = Tempfile.new(['bad', '.tsv'])
      temp.binmode
      temp.write(bad.b)
      temp.rewind
      file = Rack::Test::UploadedFile.new(temp.path, 'text/plain')

      expect do
        post "/api/v1/accounts/#{account.id}/canned_responses/import",
             params: { file: file },
             headers: agent.create_new_auth_token
      end.to change { account.reload.canned_responses.count }.by(1)

      expect(response).to have_http_status(:success)
      row = account.canned_responses.find_by(short_code: 'x')
      expect(row.content).to eq('good')
    ensure
      temp.close!
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/canned_responses/:id' do
    let(:canned_response) { CannedResponse.last }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'destroys the canned response' do
        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:success)
        expect(CannedResponse.count).to eq(0)
      end
    end
  end
end
