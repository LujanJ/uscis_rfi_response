# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubmissionsController, type: :request do
  before(:each) do
    customer = Customer.create!(
      name: Faker::Name.name,
      email: Faker::Internet.email,
      street1: Faker::Address.street_address,
      street2: Faker::Address.secondary_address,
      city: Faker::Address.city,
      state: Faker::Address.state,
      zip: Faker::Address.zip,
      dob: Faker::Date.between(18.years.ago, 80.years.ago)
    )

    submission = Submission.new(
      timestamp: Faker::Time.between(Time.current - 1.day, Time.current),
      uri: Faker::Internet.url,
      status: :submitted,
      notes: Faker::Lorem.sentence
    )

    submission.customer = customer

    submission.save
  end

  context 'logged out' do
    describe 'get #index' do
      it '401s' do
        get submissions_path
        expect(response).to have_http_status(401)
      end
    end

    describe 'get #show' do
      it '401s' do
        get submission_path(Submission.first.id)
        expect(response).to have_http_status(401)
      end
    end

    describe 'post #create' do
      it '401s' do
        customer = Customer.first
        params = { email: customer.email }
        post submissions_path, params: params
        expect(response).to have_http_status(401)
      end
    end

    describe 'put #update' do
      it '401s' do
        put "/submissions/#{Submission.first.id}"
        expect(response).to have_http_status(401)
      end
    end

    describe 'post #presigned_url' do
      it '401s' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        # to generate the image, I found a tiny png world map, and did:
        # base64 < world_tiny.png
        post '/submissions/presigned_url', params: <<~POST, headers: headers
          {
            "user_id": "e3ca6d96454e4a508a677e9e6c3dc3e3",
            "image_name": "my cat.jpg",
            "image_type": "image/png"
          }
        POST
        expect(response).to have_http_status(:success)
        url = 'https://uscis-rfds.s3.us-stubbed-1.amazonaws.com/e3ca6d96454e4a508a677e9e6c3dc3e3-my%20cat.jpg'
        body = JSON.parse(response.body)
        expect(body['status']).to eq 'ok'
        expect(body['signedUrl']).to match url
      end
    end
  end

  context 'logged in' do
    let(:auth_headers) do
      admin = Admin.create!(email: 'admin@adhocteam.us', password: 'password')
      admin.create_new_auth_token
    end

    describe 'get #index' do
      it 'returns http success' do
        get submissions_path, headers: auth_headers
        expect(response).to have_http_status(:success)
        expect(response.content_type).to eq('application/json')
        body = JSON.parse(response.body)
        submission = Submission.first
        expect(body[0]).to match(
          hash_including('customer_id' => submission.customer_id,
                         'timestamp' => submission.timestamp,
                         'uri' => submission.uri,
                         'status' => submission.status,
                         'notes' => submission.notes)
        )
      end
    end

    describe 'get #show' do
      it 'returns http success' do
        get submission_path(Submission.first.id), headers: auth_headers
        expect(response).to have_http_status(:success)
        expect(response.content_type).to eq('application/json')
        body = JSON.parse(response.body)
        submission = Submission.first
        expect(body).to match(
          hash_including(
            'timestamp' => submission.timestamp,
            'uri' => submission.uri,
            'status' => submission.status,
            'notes' => submission.notes,
            'customer' => hash_including('id' => submission.customer_id)
          )
        )
      end
    end

    describe 'post #create' do
      it 'returns http success' do
        customer = Customer.first
        params = { email: customer.email }
        post submissions_path, params: params, headers: auth_headers
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['status']).to eq('requested')
      end
    end

    describe 'put #update' do
      let(:submission) { Submission.first }

      it 'returns http success when approving' do
        params = { status: 'approved' }
        put "/submissions/#{submission.id}", params: params, headers: auth_headers
        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body['status']).to eq('approved')
        expect(body['notes']).to eq(submission.notes)
      end

      it 'returns http success when denying' do
        params = { status: 'denied' }
        put "/submissions/#{submission.id}", params: params, headers: auth_headers
        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body['status']).to eq('denied')
        expect(body['notes']).to eq(submission.notes)
      end

      it 'returns http success when updating notes' do
        params = { notes: 'foo bar' }
        put "/submissions/#{submission.id}", params: params, headers: auth_headers
        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body['status']).to eq(submission.status)
        expect(body['notes']).to eq('foo bar')
      end

      it 'only updates strong params' do
        params = { status: 'approved', notes: 'foo bar', uri: 'baz quux' }
        put "/submissions/#{submission.id}", params: params, headers: auth_headers
        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body['status']).to eq('approved')
        expect(body['notes']).to eq('foo bar')
        expect(body['uri']).to eq(submission.uri)
      end
    end
  end
end
