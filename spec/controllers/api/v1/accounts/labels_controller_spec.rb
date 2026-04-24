require 'rails_helper'
require 'tempfile'

RSpec.describe 'Label API', type: :request do
  let!(:account) { create(:account) }
  let!(:label) { create(:label, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/labels' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/labels"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :administrator) }

      it 'returns all the labels in account' do
        get "/api/v1/accounts/#{account.id}/labels",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include(label.title)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/labels/:id' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/labels/#{label.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'shows the contact' do
        get "/api/v1/accounts/#{account.id}/labels/#{label.id}",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include(label.title)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/labels' do
    let(:valid_params) { { label: { title: 'test' } } }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        expect { post "/api/v1/accounts/#{account.id}/labels", params: valid_params }.not_to change(Label, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'creates the contact' do
        expect do
          post "/api/v1/accounts/#{account.id}/labels", headers: admin.create_new_auth_token,
                                                        params: valid_params
        end.to change(Label, :count).by(1)

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/labels/import' do
    let(:admin) { create(:user, account: account, role: :administrator) }

    it 'imports TSV rows (header row + color column)' do
      tsv = "Name\tDescription\tColor\nsupport\tSupport team\t#00ff00\n"
      temp = Tempfile.new(['import', '.tsv'])
      temp.write(tsv)
      temp.rewind
      file = Rack::Test::UploadedFile.new(temp.path, 'text/tab-separated-values')

      expect do
        post "/api/v1/accounts/#{account.id}/labels/import",
             params: { file: file },
             headers: admin.create_new_auth_token
      end.to change { account.reload.labels.count }.by(1)

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['imported']).to eq(1)
      expect(body['errors']).to eq([])

      row = account.labels.find_by(title: 'support')
      expect(row.description).to eq('Support team')
      expect(row.color).to eq('#00ff00')
    ensure
      temp.close!
    end

    it 'imports xlsx rows (first sheet)' do
      allow(TableImports::XlsxFirstSheetReader).to receive(:call).and_return(
        [
          ['Name', 'Description', 'Color'],
          ['from_xlsx', 'Xlsx desc', '#ff0000']
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
        post "/api/v1/accounts/#{account.id}/labels/import",
             params: { file: file },
             headers: admin.create_new_auth_token
      end.to change { account.reload.labels.count }.by(1)

      expect(response).to have_http_status(:success)
      row = account.labels.find_by(title: 'from_xlsx')
      expect(row.description).to eq('Xlsx desc')
      expect(row.color).to eq('#ff0000')
    ensure
      temp.close!
    end

    it 'rejects agent (import follows create policy)' do
      agent = create(:user, account: account, role: :agent)
      tsv = "Name\tDescription\nx\ty\n"
      temp = Tempfile.new(['import', '.tsv'])
      temp.write(tsv)
      temp.rewind
      file = Rack::Test::UploadedFile.new(temp.path, 'text/tab-separated-values')

      post "/api/v1/accounts/#{account.id}/labels/import",
           params: { file: file },
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    ensure
      temp.close!
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/labels/:id' do
    let(:valid_params) { { title: 'Test_2' }  }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/labels/#{label.id}",
            params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'updates the label' do
        patch "/api/v1/accounts/#{account.id}/labels/#{label.id}",
              headers: admin.create_new_auth_token,
              params: valid_params,
              as: :json

        expect(response).to have_http_status(:success)
        expect(label.reload.title).to eq('test_2')
      end
    end
  end
end
