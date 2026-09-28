# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DietEval::Scorer do
  def golden(days)
    { 'days' => days }
  end

  def output_meal(type, ingredients, kcal)
    {
      'type' => type, 'name' => type,
      'ingredients' => ingredients.map { |name| { 'product' => name, 'quantity' => '1 szt' } },
      'nutrition' => { 'kcal' => kcal, 'protein' => nil, 'fat' => nil, 'carbs' => nil }
    }
  end

  let(:gold) do
    golden([
             { 'day' => 1, 'meals' => [
               { 'type' => 'breakfast', 'ingredients' => ['Płatki owsiane', 'Mleko 2%'], 'kcal' => 400 },
               { 'type' => 'dinner', 'ingredients' => ['Pierś z kurczaka', 'Ryż basmati'], 'kcal' => 600 }
             ] },
             { 'day' => 2, 'meals' => [
               { 'type' => 'breakfast', 'ingredients' => ['Jajka'], 'kcal' => nil }
             ] }
           ])
  end

  let(:perfect_output) do
    [
      { 'day' => 1, 'meals' => [
        output_meal('breakfast', ['płatki owsiane górskie', 'mleko 2% tłuszczu'], 400),
        output_meal('dinner', ['Pierś z kurczaka', 'Ryż basmati'], 600)
      ] },
      { 'day' => 2, 'meals' => [output_meal('breakfast', ['jajka kurze'], 250)] }
    ]
  end

  it 'scores a faithful parse at 100' do
    result = described_class.new(gold).score(perfect_output)

    expect(result).to include(day_count_exact: true, meal_count_exact: 1.0, ingredient_recall: 1.0,
                              kcal_within_10pct: 1.0, composite: 100.0, missing_ingredients: [])
  end

  it 'reports missing ingredients and lowers recall' do
    output = perfect_output.deep_dup
    output[0]['meals'][1]['ingredients'].pop

    result = described_class.new(gold).score(output)

    expect(result[:ingredient_recall]).to eq(0.8)
    expect(result[:missing_ingredients]).to eq(['day 1: Ryż basmati'])
  end

  it 'matches ingredients regardless of Polish diacritics and case' do
    output = perfect_output.deep_dup
    output[0]['meals'][1]['ingredients'] = [{ 'product' => 'PIERS Z KURCZAKA', 'quantity' => '120 g' },
                                            { 'product' => 'ryz basmati', 'quantity' => '60 g' }]

    expect(described_class.new(gold).score(output)[:ingredient_recall]).to eq(1.0)
  end

  it 'counts kcal exactly 10% off as within tolerance and just over as outside' do
    within = perfect_output.deep_dup
    within[0]['meals'][0]['nutrition']['kcal'] = 440
    outside = perfect_output.deep_dup
    outside[0]['meals'][0]['nutrition']['kcal'] = 441

    expect(described_class.new(gold).score(within)[:kcal_within_10pct]).to eq(1.0)
    expect(described_class.new(gold).score(outside)[:kcal_within_10pct]).to eq(0.5)
  end

  it 'penalises a collapsed multi-day parse' do
    collapsed = [{ 'day' => 1, 'meals' => perfect_output.flat_map { |d| d['meals'] } }]

    result = described_class.new(gold).score(collapsed)

    expect(result[:day_count_exact]).to be(false)
    expect(result[:meal_count_exact]).to eq(0.0)
    expect(result[:composite]).to be < 60
  end
end
