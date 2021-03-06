require 'rails_helper'

RSpec.describe Strava::FindActivityWorker, type: :model do
  let(:user) { create(:user) }
  let!(:identity) { create(:identity, :strava, user: user) }

  it { is_expected.to be_kind_of(Sidekiq::Worker) }

  def make_request(response)
    stub_request(:get, /https:\/\/www.strava.com\/api\/v3\/athlete\/activities\?after=\d+/).
      to_return(status: 200, body: response.to_json)
  end

  describe '#perform' do
    context 'when user is nil' do
      it 'returns false' do
        expect(subject.perform('')).to be_falsey
      end
    end

    context 'when service request returns an unsuccessful response' do
      let(:response) do
        {
          'errors' => [
            { 'resource' => 'Athlete', 'field' => 'access_token', 'code' => 'invalid' }
          ]
        }
      end
      it 'returns false' do
        make_request(response)
        expect(subject.perform(user.id)).to be_falsey
      end
    end

    context 'when service request returns a successful response but no activities' do
      let(:response) { [] }
      it 'returns true' do
        make_request(response)
        expect(subject.perform(user.id)).to be_truthy
      end
    end

    context 'when service request returns a successful response with activities' do
      let(:response) do
        [
          { 'id' => 101, 'type' => 'Run', 'distance' => 100.0 },
          { 'id' => 102, 'type' => 'Bike', 'distance' => 200.0 },
          { 'id' => 103, 'type' => 'Run', 'distance' => 300.0 }
        ]
      end

      it 'enqueues Strava::ImportRunWorker for every run activity' do
        make_request(response)
        expect {
          subject.perform(user.id)
        }.to change(Strava::ImportRunWorker.jobs, :count).by(2)
      end

      it 'returns true' do
        make_request(response)
        expect(subject.perform(user.id)).to be_truthy
      end
    end
  end
end
