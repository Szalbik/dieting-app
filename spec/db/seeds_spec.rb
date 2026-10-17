# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'db/seeds.rb' do
  def load_seeds
    load Rails.root.join('db/seeds.rb')
  end

  it 'creates no demo accounts in production' do
    allow(Rails.env).to receive(:production?).and_return(true)

    expect { load_seeds }.not_to change(User, :count)
    expect(Category.where(name: 'Warzywa')).to exist
  end

  it 'creates the demo admin outside production and is idempotent for categories' do
    expect { load_seeds }.to change(User, :count).by(3)
    expect(User.find_by(email_address: 'admin@example.com')).to be_admin

    expect { load_seeds }.not_to change(Category, :count)
  end
end
