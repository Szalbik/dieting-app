# Run this script from Rails console to categorize products
# Usage: load 'scripts/categorize_products.rb'

puts 'Starting product categorization...'

# Common product categorizations
categorizations = {
  'jogurt naturalny' => 'Nabiał',
  'mleko' => 'Nabiał',
  'ser' => 'Nabiał',
  'twaróg' => 'Nabiał',
  'kefir' => 'Nabiał',
  'śmietana' => 'Nabiał',
  'jajka' => 'Nabiał',
  'masło' => 'Nabiał',
  'chleb' => 'Pieczywo',
  'bułka' => 'Pieczywo',
  'bagietka' => 'Pieczywo',
  'tosty' => 'Pieczywo',
  'jabłko' => 'Owoce',
  'banan' => 'Owoce',
  'pomarańcza' => 'Owoce',
  'gruszka' => 'Owoce',
  'truskawki' => 'Owoce',
  'marchewka' => 'Warzywa',
  'pomidor' => 'Warzywa',
  'ogórek' => 'Warzywa',
  'cebula' => 'Warzywa',
  'ziemniaki' => 'Warzywa',
  'kurczak' => 'Mięso i Ryby',
  'indyk' => 'Mięso i Ryby',
  'wołowina' => 'Mięso i Ryby',
  'łosoś' => 'Mięso i Ryby',
  'tuńczyk' => 'Mięso i Ryby',
  'szynka' => 'Wędliny',
  'kiełbasa' => 'Wędliny',
  'salami' => 'Wędliny',
  'woda' => 'Napoje',
  'herbata' => 'Napoje',
  'kawa' => 'Napoje',
  'sok' => 'Napoje',
  'ryż' => 'Produkty zbożowe',
  'makaron' => 'Produkty zbożowe',
  'kasza' => 'Produkty zbożowe',
  'płatki owsiane' => 'Produkty zbożowe',
  'musli' => 'Produkty zbożowe',
  'orzechy włoskie' => 'Orzechy',
  'migdały' => 'Orzechy',
  'pistacje' => 'Orzechy',
  'sól' => 'Przyprawy',
  'pieprz' => 'Przyprawy',
  'bazylia' => 'Przyprawy',
  'oregano' => 'Przyprawy'
}

categorized_count = 0

categorizations.each do |product_name, category_name|
  # Find products with similar names
  products = Product.where('LOWER(name) LIKE ?', "%#{product_name.downcase}%")

  products.each do |product|
    # Skip if already categorized
    next if product.category.present?

    category = Category.find_by(name: category_name)
    next unless category

    # Create product category
    ProductCategory.create!(
      product: product,
      category: category,
      state: true
    )

    categorized_count += 1
    puts "Categorized: #{product.name} -> #{category_name}"
  end
end

puts "Categorized #{categorized_count} products"

# Now train the classifier
puts 'Training classifier...'
Classifier::Category.train!
puts 'Classifier trained successfully!'

# Now categorize remaining uncategorized products
puts 'Categorizing remaining uncategorized products...'
uncategorized_products = Product.includes(:product_category).where(product_categories: { id: nil })
total = uncategorized_products.count

puts "Found #{total} remaining uncategorized products"

uncategorized_products.find_each do |product|
  product.categorize_if_needed
  puts "Queued for categorization: #{product.name}"
rescue StandardError => e
  puts "Error categorizing #{product.name}: #{e.message}"
end

puts 'Done! Products should now have proper categories in the shopping cart.'
