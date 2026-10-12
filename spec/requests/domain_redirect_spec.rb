# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Old domain redirect', type: :request do
  it '301s diety.rubydive.com to asystentdiet.pl, keeping path and query' do
    host! 'diety.rubydive.com'
    get '/regulamin?x=1'
    expect(response).to have_http_status(:moved_permanently)
    expect(response).to redirect_to('https://asystentdiet.pl/regulamin?x=1')
  end

  it 'serves the new domain normally' do
    host! 'asystentdiet.pl'
    get '/regulamin'
    expect(response).to have_http_status(:ok)
  end
end
