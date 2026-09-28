# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CategoriesHelper do
  it 'gives every seeded category an icon, a card tint and a distinct aisle position' do
    seeded = ['Warzywa', 'Owoce', 'Mięso i Ryby', 'Wędliny', 'Nabiał', 'Pieczywo', 'Przyprawy', 'Orzechy', 'Inne',
              'Napoje', 'Przetwory', 'Produkty zbożowe', 'Produkty mrożone', 'Tłuszcze i oleje', 'Słodycze i przekąski']

    entries = seeded.map { |name| described_class.category_presentation(name) }

    expect(entries.map { |e| e[:icon] }).to all(be_present)
    expect(entries.map { |e| e[:tint] }).to all(be_in(Ui::CardComponent::TINT_CLASSES.keys))
    expect(seeded.map { |name| described_class.category_position(name) }.uniq.size).to eq(seeded.size)
  end

  it 'falls back to a default look and sorts unknown categories after Inne' do
    expect(described_class.category_presentation('Nieznana')).to include(:icon, :tint)
    expect(described_class.category_position('Nieznana')).to be > described_class.category_position('Inne')
  end
end
