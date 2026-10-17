# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendToTodoistJob, type: :job do
  let(:user) { create(:user) }

  it 'keeps its arguments out of the job logs' do
    expect(described_class.log_arguments).to be(false)
  end

  it 'unseals the token it was given and uses the raw value against the Todoist API' do
    allow(Todoist::Api).to receive_messages(fetch_sections: [], create_task: nil)

    described_class.perform_now('42', [], nil, described_class.seal('raw-oauth-secret'), user.id)

    expect(Todoist::Api).to have_received(:fetch_sections).with({ 'token' => 'raw-oauth-secret' }, '42')
  end

  it 'seals the token so the queued argument is not the raw value' do
    expect(described_class.seal('raw-oauth-secret')).not_to include('raw-oauth-secret')
  end
end
