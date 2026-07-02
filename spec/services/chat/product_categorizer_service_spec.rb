# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::ProductCategorizerService do
  subject(:service) { described_class.new(products: [product]) }

  let!(:vegetables) { create(:category, name: 'Warzywa') }
  let(:client) { instance_double(OpenAI::Client) }
  let!(:meat) { create(:category, name: 'Mięso i Ryby') }
  # A name the local keyword/NBayes classifier won't match, so the product stays
  # uncategorized after creation and the assertions below start from a clean slate.
  let(:product) { create(:product, name: 'Zzznieznanyprodukt999') }

  before do
    allow(service).to receive_messages(openai_client: client, api_key?: true)
  end

  it 'creates an unconfirmed ProductCategory for each valid assignment' do
    assignments = { 'assignments' => [{ 'product_id' => product.id, 'category' => 'Warzywa' }] }
    allow(client).to receive(:chat).and_return(
      { 'choices' => [{ 'message' => { 'content' => assignments.to_json } }] }
    )

    expect { service.call }.to change { product.reload.category }.from(nil).to(vegetables)
    expect(product.product_category.state).to be(false)
  end

  it 'ignores assignments for unknown products or categories' do
    assignments = { 'assignments' => [{ 'product_id' => -1, 'category' => 'Warzywa' },
                                      { 'product_id' => product.id, 'category' => 'Nieznana' }] }
    allow(client).to receive(:chat).and_return(
      { 'choices' => [{ 'message' => { 'content' => assignments.to_json } }] }
    )

    expect { service.call }.not_to(change { product.reload.category })
  end

  it 'does not call the API when there are no products' do
    empty_service = described_class.new(products: [])
    expect(OpenAI::Client).not_to receive(:new)

    empty_service.call
  end

  it 'does not call the API when no OpenAI key is configured' do
    allow(service).to receive(:api_key?).and_return(false)
    expect(client).not_to receive(:chat)

    service.call
  end
end
